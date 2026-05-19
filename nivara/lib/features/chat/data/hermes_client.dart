import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/providers/auth_provider.dart';

part 'hermes_client.g.dart';

/// Production URL injected at build time via --dart-define=HERMES_BASE_URL=...
/// Falls back to the Railway production URL in debug builds when no define is set.
const _dartDefineUrl = String.fromEnvironment('HERMES_BASE_URL');

String get _defaultBaseUrl {
  if (_dartDefineUrl.isNotEmpty) return _dartDefineUrl;
  return 'https://nivara-production.up.railway.app';
}

sealed class ChatChunk {
  const ChatChunk();
}

class TextChunk extends ChatChunk {
  const TextChunk(this.text);
  final String text;
}

class MoodChunk extends ChatChunk {
  const MoodChunk({required this.score, required this.label});
  final int score;
  final String label;
}

class DoneChunk extends ChatChunk {
  const DoneChunk();
}

class ErrorChunk extends ChatChunk {
  const ErrorChunk(this.message);
  final String message;
}

ChatChunk parseSseData(String data) {
  if (data == '[DONE]') return const DoneChunk();
  if (data == '[ERROR]') return const ErrorChunk('The AI service is unavailable. Please try again later.');
  if (data.startsWith('__MOOD__')) {
    final raw = data.substring('__MOOD__'.length);
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final score = map['score'] as int;
      final label = map['label'] as String;
      if (score >= 1 && score <= 5) return MoodChunk(score: score, label: label);
    } catch (_) {}
  }
  return TextChunk(data);
}

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

  String get baseUrl => _baseUrl;

  Stream<ChatChunk> chatStream({
    required List<Map<String, String>> messages,
    required String assistantName,
    String aiModel = 'groq',
  }) async* {
    final token = _tokenProvider != null ? await _tokenProvider() : '';

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

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Chat error ${response.statusCode}: $body');
      }

      final stream = response.stream.transform(utf8.decoder);
      final buffer = StringBuffer();

      await for (final chunk in stream) {
        buffer.write(chunk);
        final raw = buffer.toString();
        buffer.clear();

        final lines = raw.split('\n');
        for (int i = 0; i < lines.length - 1; i++) {
          final trimmed = lines[i].trim();
          if (trimmed.startsWith('data: ')) {
            final data = trimmed.substring(6);
            final parsed = parseSseData(data);
            yield parsed;
            if (parsed is DoneChunk || parsed is ErrorChunk) return;
          }
        }
        buffer.write(lines.last);
      }
    } finally {
      client.close();
    }
  }
}
