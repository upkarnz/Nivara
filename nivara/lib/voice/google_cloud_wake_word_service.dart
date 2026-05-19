import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'wake_word_service.dart';

/// Detects a configurable wake word using high-accuracy speech recognition.
///
/// Uses the device's speech-to-text engine with continuous listening.
/// An optional Google Cloud API key is accepted for future server-side
/// transcription support (requires a key from console.cloud.google.com).
class GoogleCloudWakeWordService implements WakeWordService {
  GoogleCloudWakeWordService({
    required String apiKey,
    String keyword = 'nivara',
  })  : _apiKey = apiKey,
        _keyword = keyword.toLowerCase().trim();

  final String _apiKey;
  final String _keyword;
  final SpeechToText _stt = SpeechToText();
  void Function()? _onWakeWord;
  bool _running = false;
  bool _sttReady = false;

  @override
  set onWakeWord(void Function() callback) => _onWakeWord = callback;

  @override
  Future<void> start() async {
    _sttReady = await _stt.initialize();
    if (!_sttReady) return;
    _running = true;
    _listen();
  }

  void _listen() {
    if (!_running || !_sttReady) return;
    _stt.listen(
      onResult: (result) {
        if (!_running) return;
        if (result.finalResult) {
          final words = result.recognizedWords.toLowerCase();
          if (words.contains(_keyword)) {
            _onWakeWord?.call();
          }
          // restart listening after each utterance
          if (_running) _listen();
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(cancelOnError: true),
    );
  }

  @override
  Future<void> stop() async {
    _running = false;
    try {
      await _stt.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _running = false;
    try {
      await _stt.cancel();
    } catch (_) {}
    _onWakeWord = null;
  }
}
