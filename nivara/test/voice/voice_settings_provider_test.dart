import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/voice/tts_provider.dart';
import 'package:nivara/voice/voice_settings_provider.dart';
import 'package:nivara/voice/wake_word_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('VoiceSettingsNotifier', () {
    test('default engine is stt', () async {
      final c = makeContainer();
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.engine, WakeWordEngine.stt);
    });

    test('default porcupineAccessKey is empty', () async {
      final c = makeContainer();
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.porcupineAccessKey, isEmpty);
    });

    test('default ttsProvider is flutterTts', () async {
      final c = makeContainer();
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.ttsProvider, TtsProvider.flutterTts);
    });

    test('default elevenLabsApiKey is empty', () async {
      final c = makeContainer();
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.elevenLabsApiKey, isEmpty);
    });

    test('setEngine persists and updates state', () async {
      final c = makeContainer();
      await c.read(voiceSettingsProvider.future);
      await c
          .read(voiceSettingsProvider.notifier)
          .setEngine(WakeWordEngine.porcupine);
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.engine, WakeWordEngine.porcupine);
    });

    test('setPorcupineAccessKey persists and updates state', () async {
      final c = makeContainer();
      await c.read(voiceSettingsProvider.future);
      await c
          .read(voiceSettingsProvider.notifier)
          .setPorcupineAccessKey('abc123');
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.porcupineAccessKey, 'abc123');
    });

    test('setTtsProvider persists and updates state', () async {
      final c = makeContainer();
      await c.read(voiceSettingsProvider.future);
      await c
          .read(voiceSettingsProvider.notifier)
          .setTtsProvider(TtsProvider.elevenLabs);
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.ttsProvider, TtsProvider.elevenLabs);
    });

    test('setElevenLabsApiKey persists and updates state', () async {
      final c = makeContainer();
      await c.read(voiceSettingsProvider.future);
      await c
          .read(voiceSettingsProvider.notifier)
          .setElevenLabsApiKey('sk-test-key');
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.elevenLabsApiKey, 'sk-test-key');
    });
  });

  group('VoiceSettings.copyWith', () {
    test('creates a new instance with updated engine', () {
      const original = VoiceSettings();
      final updated = original.copyWith(engine: WakeWordEngine.porcupine);
      expect(updated.engine, WakeWordEngine.porcupine);
      expect(updated.porcupineAccessKey, original.porcupineAccessKey);
    });

    test('creates a new instance with updated key', () {
      const original = VoiceSettings();
      final updated = original.copyWith(porcupineAccessKey: 'key-xyz');
      expect(updated.porcupineAccessKey, 'key-xyz');
      expect(updated.engine, original.engine);
    });

    test('creates a new instance with updated ttsProvider', () {
      const original = VoiceSettings();
      final updated = original.copyWith(ttsProvider: TtsProvider.elevenLabs);
      expect(updated.ttsProvider, TtsProvider.elevenLabs);
      expect(updated.elevenLabsApiKey, original.elevenLabsApiKey);
    });

    test('creates a new instance with updated elevenLabsApiKey', () {
      const original = VoiceSettings();
      final updated = original.copyWith(elevenLabsApiKey: 'my-key');
      expect(updated.elevenLabsApiKey, 'my-key');
      expect(updated.ttsProvider, original.ttsProvider);
    });
  });
}
