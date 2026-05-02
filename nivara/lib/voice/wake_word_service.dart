/// Abstract interface for wake-word detection back-ends.
///
/// Implementations fire [onWakeWord] each time the trigger phrase is detected,
/// allowing the caller to start a listening session.
abstract interface class WakeWordService {
  /// Callback invoked when the wake word is detected.
  set onWakeWord(void Function() callback);

  /// Starts listening for the wake word.
  Future<void> start();

  /// Stops listening for the wake word.
  Future<void> stop();

  /// Releases any resources held by this service.
  Future<void> dispose();
}
