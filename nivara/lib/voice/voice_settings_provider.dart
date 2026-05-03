import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tts_provider.dart';
import 'wake_word_engine.dart';

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const _kEngine = 'voice_settings_engine';
const _kPorcupineKey = 'voice_settings_porcupine_access_key';
const _kTtsProvider = 'voice_settings_tts_provider';
const _kElevenLabsApiKey = 'voice_settings_elevenlabs_api_key';

// ---------------------------------------------------------------------------
// VoiceSettings value object
// ---------------------------------------------------------------------------

/// Persisted voice-assistant settings.
class VoiceSettings {
  const VoiceSettings({
    this.engine = WakeWordEngine.stt,
    this.porcupineAccessKey = '',
    this.ttsProvider = TtsProvider.flutterTts,
    this.elevenLabsApiKey = '',
  });

  final WakeWordEngine engine;
  final String porcupineAccessKey;
  final TtsProvider ttsProvider;
  final String elevenLabsApiKey;

  VoiceSettings copyWith({
    WakeWordEngine? engine,
    String? porcupineAccessKey,
    TtsProvider? ttsProvider,
    String? elevenLabsApiKey,
  }) =>
      VoiceSettings(
        engine: engine ?? this.engine,
        porcupineAccessKey: porcupineAccessKey ?? this.porcupineAccessKey,
        ttsProvider: ttsProvider ?? this.ttsProvider,
        elevenLabsApiKey: elevenLabsApiKey ?? this.elevenLabsApiKey,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Loads and persists [VoiceSettings] via [SharedPreferences].
class VoiceSettingsNotifier extends AsyncNotifier<VoiceSettings> {
  @override
  Future<VoiceSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final engineIndex = prefs.getInt(_kEngine) ?? 0;
    final porcKey = prefs.getString(_kPorcupineKey) ?? '';
    final ttsIndex = prefs.getInt(_kTtsProvider) ?? 0;
    final elevenKey = prefs.getString(_kElevenLabsApiKey) ?? '';
    return VoiceSettings(
      engine: WakeWordEngine.values[engineIndex],
      porcupineAccessKey: porcKey,
      ttsProvider: TtsProvider.values[ttsIndex],
      elevenLabsApiKey: elevenKey,
    );
  }

  Future<void> setEngine(WakeWordEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kEngine, engine.index);
    state = AsyncData(state.value!.copyWith(engine: engine));
  }

  Future<void> setPorcupineAccessKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPorcupineKey, key);
    state = AsyncData(state.value!.copyWith(porcupineAccessKey: key));
  }

  Future<void> setTtsProvider(TtsProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTtsProvider, provider.index);
    state = AsyncData(state.value!.copyWith(ttsProvider: provider));
  }

  Future<void> setElevenLabsApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kElevenLabsApiKey, key);
    state = AsyncData(state.value!.copyWith(elevenLabsApiKey: key));
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final voiceSettingsProvider =
    AsyncNotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
  VoiceSettingsNotifier.new,
);
