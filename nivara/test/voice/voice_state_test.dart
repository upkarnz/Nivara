import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/voice/voice_state.dart';

void main() {
  group('VoiceState', () {
    test('has four values', () {
      expect(VoiceState.values.length, 4);
    });

    test('contains idle, listening, processing, speaking', () {
      expect(VoiceState.values, containsAll([
        VoiceState.idle,
        VoiceState.listening,
        VoiceState.processing,
        VoiceState.speaking,
      ]));
    });

    test('idle is the first value', () {
      expect(VoiceState.values.first, VoiceState.idle);
    });
  });
}
