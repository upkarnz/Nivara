import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    test('setEngine persists and updates state', () async {
      final c = makeContainer();
      await c.read(voiceSettingsProvider.future);
      await c.read(voiceSettingsProvider.notifier).setEngine(WakeWordEngine.porcupine);
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.engine, WakeWordEngine.porcupine);
    });

    test('setPorcupineAccessKey persists and updates state', () async {
      final c = makeContainer();
      await c.read(voiceSettingsProvider.future);
      await c.read(voiceSettingsProvider.notifier).setPorcupineAccessKey('abc123');
      final settings = await c.read(voiceSettingsProvider.future);
      expect(settings.porcupineAccessKey, 'abc123');
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
  });
}
