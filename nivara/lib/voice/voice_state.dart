/// The current state of the voice assistant.
enum VoiceState {
  /// Waiting for the wake word.
  idle,

  /// Wake word detected; actively listening for a command.
  listening,

  /// STT transcript received; sending to the AI backend.
  processing,

  /// TTS is reading out the AI response.
  speaking,
}
