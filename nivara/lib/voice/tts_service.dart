/// Abstract TTS service. Implementations provide on-device or cloud speech.
abstract interface class TtsService {
  /// Speaks [text] aloud. Stops any in-progress speech first.
  Future<void> speak(String text);

  /// Stops any in-progress speech immediately.
  Future<void> stop();

  /// Releases TTS resources.
  Future<void> dispose();
}
