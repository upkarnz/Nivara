import 'wake_word_service.dart';

/// Stub — Porcupine wake word detection has been removed.
///
/// Any persisted [WakeWordEngine.porcupine] setting falls back to
/// [SttWakeWordService] in [VoiceNotifier._buildWakeWordService].
class PorcupineWakeWordService implements WakeWordService {
  PorcupineWakeWordService({required String accessKey});

  @override
  set onWakeWord(void Function() callback) {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
