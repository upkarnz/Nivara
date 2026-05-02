/// Selects the wake-word detection back-end.
enum WakeWordEngine {
  /// Keyword-in-transcript detection via `speech_to_text` (default, no API key).
  stt,

  /// Porcupine on-device wake word (requires a free Picovoice AccessKey).
  porcupine,
}
