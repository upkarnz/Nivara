import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/voice/wake_word_engine.dart';

void main() {
  group('WakeWordEngine', () {
    test('has two values', () {
      expect(WakeWordEngine.values.length, 2);
    });

    test('contains stt and porcupine', () {
      expect(WakeWordEngine.values, containsAll([
        WakeWordEngine.stt,
        WakeWordEngine.porcupine,
      ]));
    });

    test('stt is the default (first) value', () {
      expect(WakeWordEngine.values.first, WakeWordEngine.stt);
    });
  });
}
