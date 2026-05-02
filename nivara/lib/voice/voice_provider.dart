import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'elevenlabs_tts_service.dart';
import 'flutter_tts_service.dart';
import 'tts_provider.dart';
import 'tts_service.dart';
import 'voice_settings_provider.dart';
import 'voice_state.dart';
import 'wake_word_engine.dart';
import 'wake_word_service.dart';
import 'stt_wake_word_service.dart';
import 'porcupine_wake_word_service.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final voiceProvider =
    NotifierProvider<VoiceNotifier, VoiceState>(VoiceNotifier.new);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Drives the voice assistant state machine:
///
///   idle → listening → processing → speaking → idle
class VoiceNotifier extends Notifier<VoiceState> {
  WakeWordService? _wakeWord;
  late TtsService _tts;
  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;

  @override
  VoiceState build() {
    // Default to flutter_tts until settings load asynchronously.
    _tts = FlutterTtsService();
    _init();
    // Clean up when the provider is disposed.
    ref.onDispose(() async {
      await _wakeWord?.dispose();
      await _tts.dispose();
    });
    return VoiceState.idle;
  }

  Future<void> _init() async {
    // Request microphone permission once.
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    _sttReady = await _stt.initialize();

    final settings = await ref.read(voiceSettingsProvider.future);

    // Replace default TTS with the user's preferred implementation.
    await _tts.dispose();
    _tts = _buildTtsService(settings);

    _wakeWord = _buildWakeWordService(settings);
    _wakeWord!.onWakeWord = _onWakeWordDetected;
    await _wakeWord!.start();
  }

  TtsService _buildTtsService(VoiceSettings settings) {
    if (settings.ttsProvider == TtsProvider.elevenLabs &&
        settings.elevenLabsApiKey.isNotEmpty) {
      return ElevenLabsTtsService(apiKey: settings.elevenLabsApiKey);
    }
    return FlutterTtsService();
  }

  WakeWordService _buildWakeWordService(VoiceSettings settings) {
    if (settings.engine == WakeWordEngine.porcupine &&
        settings.porcupineAccessKey.isNotEmpty) {
      return PorcupineWakeWordService(
          accessKey: settings.porcupineAccessKey);
    }
    return SttWakeWordService();
  }

  void _onWakeWordDetected() {
    if (state != VoiceState.idle) return;
    state = VoiceState.listening;
    _startListening();
  }

  void _startListening() {
    if (!_sttReady) {
      state = VoiceState.idle;
      return;
    }
    _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          _handleTranscript(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 15),
      listenOptions: SpeechListenOptions(cancelOnError: true),
    );
  }

  Future<void> _handleTranscript(String transcript) async {
    if (transcript.isEmpty) {
      state = VoiceState.idle;
      return;
    }
    state = VoiceState.processing;
    // Speak a simple acknowledgement — the actual AI response integration
    // will be wired in a subsequent task.
    await _speak('Processing: $transcript');
  }

  Future<void> _speak(String text) async {
    state = VoiceState.speaking;
    await _tts.speak(text);
    state = VoiceState.idle;
  }

  // ---------------------------------------------------------------------------
  // Public API for manual trigger (e.g. VoiceFab tap)
  // ---------------------------------------------------------------------------

  /// Manually triggers a listening session (mirrors wake-word detection).
  void startListening() => _onWakeWordDetected();

  /// Stops everything and returns to idle.
  Future<void> stopAll() async {
    await _stt.stop();
    await _tts.stop();
    state = VoiceState.idle;
  }
}
