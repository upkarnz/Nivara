import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/providers/auth_provider.dart';

part 'hermes_client.g.dart';

const _defaultBaseUrl = String.fromEnvironment(
  'HERMES_BASE_URL',
  defaultValue: 'https://your-app.railway.app',
);

@riverpod
HermesClient hermesClient(HermesClientRef ref) {
  return HermesClient(
    baseUrl: _defaultBaseUrl,
    tokenProvider: () => ref.read(firebaseIdTokenProvider.future),
  );
}

class HermesClient {
  HermesClient({
    required String baseUrl,
    Future<String> Function()? tokenProvider,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  final String _baseUrl;
  final Future<String> Function()? _tokenProvider;

  /// Streams text chunks from the Hermes SSE chat endpoint.
  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    required String assistantName,
    String aiModel = 'claude',
  }) async* {
    final token = _tokenProvider != null ? await _tokenProvider!() : '';

    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/api/v1/chat/stream'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'messages': messages,
      'assistant_name': assistantName,
      'ai_model': aiModel,
    });

    final client = http.Client();
    try {
      final response = await client.send(request);
      final stream = response.stream.transform(utf8.decoder);
      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(chunk);
        final raw = buffer.toString();
        buffer.clear();

        for (final line in raw.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data: ')) {
            final data = trimmed.substring(6);
            if (data == '[DONE]') return;
            yield data;
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
