import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

/// On-device TTS via flutter_tts. No API key required.
class FlutterTtsService implements TtsService {
  FlutterTtsService() : _tts = FlutterTts();

  final FlutterTts _tts;

  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> dispose() => _tts.stop();
}
