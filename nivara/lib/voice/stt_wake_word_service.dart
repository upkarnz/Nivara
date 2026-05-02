import 'package:speech_to_text/speech_to_text.dart';
import 'wake_word_service.dart';

/// Detects the wake word "nivara" using continuous 8-second STT bursts.
///
/// No API key required — uses the on-device speech recogniser.
class SttWakeWordService implements WakeWordService {
  SttWakeWordService() : _stt = SpeechToText();

  final SpeechToText _stt;
  void Function()? _onWakeWord;
  bool _running = false;

  static const _keyword = 'nivara';
  static const _listenDuration = Duration(seconds: 8);

  @override
  set onWakeWord(void Function() callback) => _onWakeWord = callback;

  @override
  Future<void> start() async {
    final available = await _stt.initialize();
    if (!available) return;
    _running = true;
    _listen();
  }

  void _listen() {
    if (!_running) return;
    _stt.listen(
      onResult: (result) {
        if (result.recognizedWords.toLowerCase().contains(_keyword)) {
          _onWakeWord?.call();
        }
      },
      listenFor: _listenDuration,
      onDevice: true,
      cancelOnError: false,
    );
    // Restart burst after the listen window closes.
    Future.delayed(_listenDuration + const Duration(milliseconds: 300), () {
      if (_running && !_stt.isListening) _listen();
    });
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _stt.stop();
  }

  @override
  Future<void> dispose() async {
    _running = false;
    await _stt.stop();
    _onWakeWord = null;
  }
}
