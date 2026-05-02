import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wake_word_engine.dart';

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const _kEngine = 'voice_settings_engine';
const _kPorcupineKey = 'voice_settings_porcupine_access_key';

// ---------------------------------------------------------------------------
// VoiceSettings value object
// ---------------------------------------------------------------------------

/// Persisted voice-assistant settings.
class VoiceSettings {
  const VoiceSettings({
    this.engine = WakeWordEngine.stt,
    this.porcupineAccessKey = '',
  });

  final WakeWordEngine engine;
  final String porcupineAccessKey;

  VoiceSettings copyWith({
    WakeWordEngine? engine,
    String? porcupineAccessKey,
  }) =>
      VoiceSettings(
        engine: engine ?? this.engine,
        porcupineAccessKey: porcupineAccessKey ?? this.porcupineAccessKey,
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
    final key = prefs.getString(_kPorcupineKey) ?? '';
    return VoiceSettings(
      engine: WakeWordEngine.values[engineIndex],
      porcupineAccessKey: key,
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
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final voiceSettingsProvider =
    AsyncNotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
  VoiceSettingsNotifier.new,
);
