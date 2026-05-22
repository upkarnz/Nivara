import 'dart:convert';

import 'package:http/http.dart' as http;

/// Proxies mem0 calls through the Railway backend.
///
/// The backend holds the MEM0_API_KEY server-side — the Flutter app only needs
/// a valid Firebase ID token, which it provides as a Bearer token.
///
/// Endpoints (on Railway):
///   POST /api/v1/mem0/insert   — {"messages": [...]}
///   GET  /api/v1/mem0/context  — ?query=<text>
class MemobaseRepository {
  MemobaseRepository({
    required this.tokenProvider,
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? 'https://nivara-production.up.railway.app',
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  final Future<String> Function() tokenProvider;
  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// No-op — Railway/mem0 auto-creates users on first insert.
  Future<void> ensureUser(String userId) async {}

  /// Sends a conversation turn to mem0 via Railway proxy.
  Future<void> insertChatBlob({
    required String userId,
    required List<Map<String, String>> messages,
  }) async {
    final headers = await _headers();
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/mem0/insert'),
      headers: headers,
      body: jsonEncode({'messages': messages}),
    );
    if (response.statusCode != 200) {
      throw Exception('mem0 insert failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Returns mem0 context string for the current user, or null if none.
  Future<String?> getContext({
    required String userId,
    String? query,
    int maxTokens = 500,
  }) async {
    final headers = await _headers();
    final uri = Uri.parse('$_baseUrl/api/v1/mem0/context').replace(
      queryParameters: query != null && query.isNotEmpty ? {'query': query} : {},
    );
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final ctx = decoded['context'] as String?;
    return (ctx != null && ctx.isNotEmpty) ? ctx : null;
  }
}
