import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/voice/tts_provider.dart';
import 'package:nivara/voice/voice_settings_provider.dart';
import 'package:nivara/voice/voice_settings_page.dart';
import 'package:nivara/voice/wake_word_engine.dart';

Widget _buildPage(VoiceSettings initial) => ProviderScope(
      overrides: [
        voiceSettingsProvider.overrideWith(
          () => _FakeSettingsNotifier(initial),
        ),
      ],
      child: const MaterialApp(home: VoiceSettingsPage()),
    );

class _FakeSettingsNotifier extends VoiceSettingsNotifier {
  _FakeSettingsNotifier(this._initial);
  final VoiceSettings _initial;

  @override
  Future<VoiceSettings> build() async => _initial;

  @override
  Future<void> setEngine(WakeWordEngine engine) async {
    state = AsyncData(state.value!.copyWith(engine: engine));
  }

  @override
  Future<void> setPorcupineAccessKey(String key) async {
    state = AsyncData(state.value!.copyWith(porcupineAccessKey: key));
  }

  @override
  Future<void> setTtsProvider(TtsProvider provider) async {
    state = AsyncData(state.value!.copyWith(ttsProvider: provider));
  }

  @override
  Future<void> setElevenLabsApiKey(String key) async {
    state = AsyncData(state.value!.copyWith(elevenLabsApiKey: key));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences_android'),
      (call) async => <String, Object>{},
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => <String, Object>{},
    );
  });

  tearDown(() {
    for (final ch in [
      'plugins.flutter.io/shared_preferences_android',
      'plugins.flutter.io/shared_preferences',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), null);
    }
  });

  group('VoiceSettingsPage — Wake Word section', () {
    testWidgets('shows both engine options', (tester) async {
      await tester.pumpWidget(
          _buildPage(const VoiceSettings(engine: WakeWordEngine.stt)));
      await tester.pump();

      expect(find.text('Built-in (speech recognition)'), findsOneWidget);
      expect(find.text('Porcupine (custom wake word)'), findsOneWidget);
    });

    testWidgets('STT option is selected by default', (tester) async {
      await tester.pumpWidget(
          _buildPage(const VoiceSettings(engine: WakeWordEngine.stt)));
      await tester.pump();

      final radios = tester.widgetList<Radio<WakeWordEngine>>(
          find.byType(Radio<WakeWordEngine>));
      final selected =
          radios.where((r) => r.groupValue == WakeWordEngine.stt).first;
      expect(selected.value, WakeWordEngine.stt);
    });

    testWidgets('Porcupine key field hidden when STT selected', (tester) async {
      await tester.pumpWidget(
          _buildPage(const VoiceSettings(engine: WakeWordEngine.stt)));
      await tester.pump();

      expect(find.byKey(const Key('porcupine_key_field')), findsNothing);
    });

    testWidgets('Porcupine key field shown when Porcupine selected',
        (tester) async {
      await tester.pumpWidget(_buildPage(
          const VoiceSettings(engine: WakeWordEngine.porcupine)));
      await tester.pump();

      expect(find.byKey(const Key('porcupine_key_field')), findsOneWidget);
    });

    testWidgets('tapping Porcupine radio shows key field', (tester) async {
      await tester.pumpWidget(
          _buildPage(const VoiceSettings(engine: WakeWordEngine.stt)));
      await tester.pump();

      await tester.tap(find.text('Porcupine (custom wake word)'));
      await tester.pump();

      expect(find.byKey(const Key('porcupine_key_field')), findsOneWidget);
    });
  });

  group('VoiceSettingsPage — TTS Provider section', () {
    testWidgets('shows both TTS options', (tester) async {
      await tester.pumpWidget(_buildPage(const VoiceSettings()));
      await tester.pump();

      expect(find.text('Built-in TTS'), findsOneWidget);
      expect(find.text('ElevenLabs (cloud)'), findsOneWidget);
    });

    testWidgets('flutter_tts option is selected by default', (tester) async {
      await tester.pumpWidget(_buildPage(const VoiceSettings()));
      await tester.pump();

      final radios = tester.widgetList<Radio<TtsProvider>>(
          find.byType(Radio<TtsProvider>));
      final selected =
          radios.where((r) => r.groupValue == TtsProvider.flutterTts).first;
      expect(selected.value, TtsProvider.flutterTts);
    });

    testWidgets('ElevenLabs key field hidden when flutter_tts selected',
        (tester) async {
      await tester.pumpWidget(_buildPage(
          const VoiceSettings(ttsProvider: TtsProvider.flutterTts)));
      await tester.pump();

      expect(find.byKey(const Key('elevenlabs_key_field')), findsNothing);
    });

    testWidgets('ElevenLabs key field shown when ElevenLabs selected',
        (tester) async {
      await tester.pumpWidget(_buildPage(
          const VoiceSettings(ttsProvider: TtsProvider.elevenLabs)));
      await tester.pump();

      expect(find.byKey(const Key('elevenlabs_key_field')), findsOneWidget);
    });

    testWidgets('tapping ElevenLabs radio shows key field', (tester) async {
      await tester.pumpWidget(_buildPage(const VoiceSettings()));
      await tester.pump();

      await tester.tap(find.text('ElevenLabs (cloud)'));
      await tester.pump();

      expect(find.byKey(const Key('elevenlabs_key_field')), findsOneWidget);
    });
  });
}
