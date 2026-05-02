import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around [FlutterTts] for text-to-speech output.
class TtsService {
  TtsService() : _tts = FlutterTts();

  final FlutterTts _tts;

  /// Speaks [text] aloud. Stops any in-progress speech first.
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Stops any in-progress speech immediately.
  Future<void> stop() => _tts.stop();

  /// Releases TTS resources.
  Future<void> dispose() => _tts.stop();
}
