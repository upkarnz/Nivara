import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/voice/voice_state.dart';
import 'package:nivara/voice/voice_provider.dart';

// Mock all platform channels used by the voice stack.
void _mockChannels() {
  // Generic null-returning channels.
  for (final ch in [
    'flutter_tts',
    'plugin.dra.speech_to_text',
    'flutter_speech_to_text',
    'com.porcupine.manager',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
  }

  // permission_handler expects a Map<permission_index, status_index> result.
  // 1 = microphone permission index; 1 = granted status.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async {
      if (call.method == 'requestPermissions' ||
          call.method == 'checkPermissionStatus') {
        return <int, int>{1: 1}; // microphone: granted
      }
      return null;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockChannels();
  });

  tearDown(() {
    for (final ch in [
      'flutter_tts',
      'plugin.dra.speech_to_text',
      'flutter_speech_to_text',
      'com.porcupine.manager',
      'flutter.baseflow.com/permissions/methods',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), null);
    }
  });

  ProviderContainer makeContainer() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  group('VoiceNotifier', () {
    test('initial state is idle', () {
      final c = makeContainer();
      expect(c.read(voiceProvider), VoiceState.idle);
    });

    test('stopAll returns to idle', () async {
      final c = makeContainer();
      await c.read(voiceProvider.notifier).stopAll();
      expect(c.read(voiceProvider), VoiceState.idle);
    });
  });
}
