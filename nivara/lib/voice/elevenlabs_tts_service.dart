import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'tts_service.dart';

/// Cloud TTS via ElevenLabs. Requires an ElevenLabs API key.
///
/// Sends the text to the ElevenLabs REST API and plays the returned
/// audio/mpeg stream via [just_audio].
class ElevenLabsTtsService implements TtsService {
  ElevenLabsTtsService({
    required String apiKey,
    String voiceId = 'pNInz6obpgDQGcFmaJgB', // Adam — widely available
    String modelId = 'eleven_turbo_v2',
  })  : _apiKey = apiKey,
        _voiceId = voiceId,
        _modelId = modelId,
        _player = AudioPlayer();

  final String _apiKey;
  final String _voiceId;
  final String _modelId;
  final AudioPlayer _player;

  static const _baseUrl = 'https://api.elevenlabs.io/v1';

  @override
  Future<void> speak(String text) async {
    await stop();

    final uri = Uri.parse('$_baseUrl/text-to-speech/$_voiceId');
    final response = await http.post(
      uri,
      headers: {
        'xi-api-key': _apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: jsonEncode({
        'text': text,
        'model_id': _modelId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'ElevenLabs TTS error ${response.statusCode}: ${response.body}',
      );
    }

    // Write bytes to a temp file then play via just_audio.
    final tmp = File('${Directory.systemTemp.path}/nivara_tts.mp3');
    await tmp.writeAsBytes(response.bodyBytes);
    await _player.setFilePath(tmp.path);
    await _player.play();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _player.stop();
    await _player.dispose();
  }
}
