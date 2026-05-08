import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/memory.dart';

class MemoryRepository {
  MemoryRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<List<Memory>> fetchMemories(String idToken) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/memory'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('fetchMemories failed: ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Memory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteMemory(String idToken, String memoryId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/api/v1/memory/$memoryId'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode != 204) {
      throw Exception('deleteMemory failed: ${response.statusCode}');
    }
  }
}
