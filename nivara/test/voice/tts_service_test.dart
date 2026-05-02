import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/voice/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the flutter_tts platform channel so no real platform calls are made.
  const _ttsChannel = MethodChannel('flutter_tts');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, (call) async {
      // Return null for all method calls – sufficient for unit tests.
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, null);
  });

  group('TtsService', () {
    late TtsService sut;

    setUp(() => sut = TtsService());

    test('can be instantiated', () {
      expect(sut, isA<TtsService>());
    });

    test('speak returns a Future', () async {
      await expectLater(sut.speak('hello'), completes);
    });

    test('stop returns a Future', () async {
      await expectLater(sut.stop(), completes);
    });

    test('dispose returns a Future', () async {
      await expectLater(sut.dispose(), completes);
    });
  });
}
