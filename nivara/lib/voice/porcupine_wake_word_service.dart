import 'package:porcupine_flutter/porcupine.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'wake_word_service.dart';

/// Detects the "Porcupine" built-in wake word using Picovoice Porcupine.
///
/// Requires a free AccessKey from https://console.picovoice.ai/.
/// This service is opt-in — users configure the key in Settings.
class PorcupineWakeWordService implements WakeWordService {
  PorcupineWakeWordService({required String accessKey})
      : _accessKey = accessKey;

  final String _accessKey;
  PorcupineManager? _manager;
  void Function()? _onWakeWord;

  @override
  set onWakeWord(void Function() callback) => _onWakeWord = callback;

  @override
  Future<void> start() async {
    try {
      _manager = await PorcupineManager.fromBuiltInKeywords(
        _accessKey,
        [BuiltInKeyword.PORCUPINE],
        (keywordIndex) => _onWakeWord?.call(),
        errorCallback: (error) {
          // Silently ignore errors to keep the UI stable; the engine will
          // remain inactive until stop/start is called again.
        },
      );
      await _manager?.start();
    } on PorcupineActivationException {
      // Invalid or expired AccessKey — service stays silent.
    } on PorcupineActivationLimitException {
      // Usage limit reached.
    } on PorcupineException {
      // General Porcupine error.
    }
  }

  @override
  Future<void> stop() async {
    await _manager?.stop();
  }

  @override
  Future<void> dispose() async {
    await _manager?.delete();
    _manager = null;
    _onWakeWord = null;
  }
}
