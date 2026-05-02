import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/voice/flutter_tts_service.dart';
import 'package:nivara/voice/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the flutter_tts platform channel so no real platform calls are made.
  const _ttsChannel = MethodChannel('flutter_tts');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, (call) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, null);
  });

  group('TtsService (abstract)', () {
    test('FlutterTtsService implements TtsService', () {
      final sut = FlutterTtsService();
      expect(sut, isA<TtsService>());
    });
  });

  group('FlutterTtsService', () {
    late FlutterTtsService sut;

    setUp(() => sut = FlutterTtsService());

    test('can be instantiated', () {
      expect(sut, isNotNull);
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
