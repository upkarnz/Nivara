/// Which TTS engine to use for voice output.
enum TtsProvider {
  /// Built-in on-device TTS via flutter_tts. No API key required.
  flutterTts,

  /// Cloud TTS via ElevenLabs. Requires an ElevenLabs API key.
  elevenLabs,
}
