import 'dart:async';

import 'package:flutter/foundation.dart';
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
import 'google_cloud_wake_word_service.dart';
import '../features/chat/domain/message.dart';
import '../features/chat/presentation/providers/chat_provider.dart';
import '../features/music/domain/mood_category.dart';
import '../features/music/presentation/providers/mood_playlist_provider.dart';
import '../features/music/presentation/providers/music_player_notifier.dart';
import '../features/subscription/data/wake_word_quota_repository.dart';
import '../features/subscription/presentation/providers/subscription_providers.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import 'music_command.dart';

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
    // Let speech_to_text handle its own permission dialog on iOS.
    // permission_handler can sometimes fail silently on simulators.
    _sttReady = await _stt.initialize(
      onError: (e) => debugPrint('[Voice] STT init error: $e'),
      onStatus: (s) => debugPrint('[Voice] STT status: $s'),
    );
    debugPrint('[Voice] STT initialised: $_sttReady');
    if (!_sttReady) {
      // Fallback: try permission_handler then retry
      final status = await Permission.microphone.request();
      debugPrint('[Voice] Mic permission: $status');
      if (status.isGranted) {
        _sttReady = await _stt.initialize(
          onError: (e) => debugPrint('[Voice] STT retry error: $e'),
          onStatus: (s) => debugPrint('[Voice] STT retry status: $s'),
        );
        debugPrint('[Voice] STT retry: $_sttReady');
      }
      if (!_sttReady) return;
    }

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
    if (settings.engine == WakeWordEngine.googleCloud &&
        settings.googleCloudApiKey.isNotEmpty) {
      return GoogleCloudWakeWordService(apiKey: settings.googleCloudApiKey);
    }
    // Use the configured assistant name as the wake word (default: 'Rocky').
    final assistantCfg = ref.read(assistantConfigProvider).valueOrNull;
    final keyword = (assistantCfg?.name ?? 'Rocky').toLowerCase();
    return SttWakeWordService(keyword: keyword);
  }

  Future<void> _onWakeWordDetected() async {
    if (state != VoiceState.idle) return;

    // ── Wake word quota check ──────────────────────────────────────────────
    // Free: lifetime limit of 5. Pro: monthly limit of 30. Premium: unlimited.
    final tierConfig = ref.read(tierConfigProvider);
    final wakeWordLimit = tierConfig.wakeWordLimit;
    if (wakeWordLimit != null) {
      try {
        final repo = ref.read(wakeWordQuotaRepositoryProvider);
        if (tierConfig.wakeWordLimitIsMonthly) {
          await repo.resetIfNewMonthlyPeriod();
        }
        final usage = await repo.getUsage();
        if (usage.activationsUsed >= wakeWordLimit) {
          // Quota exhausted — silently ignore the wake word.
          return;
        }
        // Increment before listening so concurrent calls don't over-count.
        await repo.incrementActivation();
      } catch (_) {
        // Non-critical: if quota check fails, allow the activation through.
      }
    }

    state = VoiceState.listening;
    _startListening();
  }

  void _startListening() {
    if (!_sttReady) {
      debugPrint('[Voice] _startListening: STT not ready, aborting');
      state = VoiceState.idle;
      return;
    }
    debugPrint('[Voice] _startListening: STT listen started');
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

    // Attempt music command first — no LLM round-trip needed.
    final musicCmd = matchMusicCommand(transcript);
    if (musicCmd != null) {
      await _executeMusicCommand(musicCmd);
      return;
    }

    // Send to AI chat and wait for the full response.
    try {
      final chatNotifier = ref.read(chatNotifierProvider.notifier);
      await chatNotifier.sendMessage(transcript);

      // Retrieve the last completed assistant message.
      final messages = ref.read(chatNotifierProvider);
      final lastAssistant = messages.lastWhere(
        (m) => m.role == MessageRole.assistant && !m.isStreaming,
        orElse: () =>
            const ChatMessage(role: MessageRole.assistant, content: ''),
      );

      if (lastAssistant.content.isNotEmpty) {
        await _speak(lastAssistant.content);
      } else {
        state = VoiceState.idle;
      }
    } catch (_) {
      state = VoiceState.idle;
    }
  }

  Future<void> _executeMusicCommand(MusicCommand cmd) async {
    final notifier = ref.read(musicPlayerNotifierProvider.notifier);
    try {
      switch (cmd) {
        case MusicCommand.play:
          // Fetch current mood playlist then trigger auto-play.
          final playlist = await ref.read(moodPlaylistProvider.future);
          if (playlist != null) await notifier.autoPlayForMood(playlist);
        case MusicCommand.pause:
          await notifier.pause();
        case MusicCommand.resume:
          await notifier.resume();
        case MusicCommand.skip:
          await notifier.skip();
        case MusicCommand.stop:
          await notifier.stop();
        case MusicCommand.playCalmCategory:
          await notifier.playForCategory(MoodCategory.calm);
        case MusicCommand.playEnergizedCategory:
          await notifier.playForCategory(MoodCategory.energized);
      }
    } catch (_) {
      // Non-critical: voice command failure must not crash the assistant.
    }
    await _speak('On it.');
  }

  Future<void> _speak(String text) async {
    state = VoiceState.speaking;
    await _tts.speak(text);
    state = VoiceState.idle;
  }

  // ---------------------------------------------------------------------------
  // Public API for manual trigger (e.g. VoiceFab tap)
  // ---------------------------------------------------------------------------

  /// Whether the speech-to-text engine initialised successfully.
  bool get isSttReady => _sttReady;

  /// Manually triggers a listening session (bypasses wake-word quota).
  void startListening() {
    if (state != VoiceState.idle) return;
    if (!_sttReady) {
      // STT not ready yet — try re-initialising in the background.
      debugPrint('[Voice] STT not ready, re-initialising…');
      unawaited(_initStt());
      return;
    }
    debugPrint('[Voice] Manual mic tap — starting listen');
    state = VoiceState.listening;
    _startListening();
  }

  /// Initialises only the STT engine (called on retry).
  Future<void> _initStt() async {
    // Let STT handle permission itself first
    _sttReady = await _stt.initialize(
      onError: (e) => debugPrint('[Voice] STT error: $e'),
      onStatus: (s) => debugPrint('[Voice] STT status: $s'),
    );
    if (!_sttReady) {
      final status = await Permission.microphone.request();
      debugPrint('[Voice] Mic permission on retry: $status');
      if (!status.isGranted) return;
      _sttReady = await _stt.initialize(
        onError: (e) => debugPrint('[Voice] STT error: $e'),
        onStatus: (s) => debugPrint('[Voice] STT status: $s'),
      );
    }
    debugPrint('[Voice] STT ready: $_sttReady');
    if (_sttReady) {
      state = VoiceState.listening;
      _startListening();
    }
  }

  /// Submits [text] directly, bypassing speech recognition.
  void sendTextMessage(String text) => unawaited(_handleTranscript(text));

  /// Stops everything and returns to idle.
  Future<void> stopAll() async {
    await _stt.stop();
    await _tts.stop();
    state = VoiceState.idle;
  }
}
