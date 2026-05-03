import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/voice/wake_word_service.dart';
import 'package:nivara/voice/stt_wake_word_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SttWakeWordService', () {
    test('implements WakeWordService', () {
      expect(SttWakeWordService(), isA<WakeWordService>());
    });

    test('onWakeWord setter is assignable', () {
      final svc = SttWakeWordService();
      var called = false;
      // ignore: prefer_function_declarations_over_variables
      final cb = () => called = true;
      svc.onWakeWord = cb;
      // Just verifying it does not throw; the callback isn't triggered here.
      expect(called, isFalse);
    });

    test('stop completes without error before start', () async {
      final svc = SttWakeWordService();
      await expectLater(svc.stop(), completes);
    });

    test('dispose completes without error', () async {
      final svc = SttWakeWordService();
      await expectLater(svc.dispose(), completes);
    });
  });
}
