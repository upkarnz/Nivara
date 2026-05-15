import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:nivara/services/mood_notification_service.dart';

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('MoodNotificationService', () {
    group('nextInstanceOf9AM', () {
      test('returns a TZDateTime with hour == 9, minute == 0, second == 0',
          () {
        final result = MoodNotificationService.nextInstanceOf9AM();

        expect(result.hour, equals(9));
        expect(result.minute, equals(0));
        expect(result.second, equals(0));
      });

      test('returned time is at 9am today or tomorrow', () {
        tz.initializeTimeZones();
        final result = MoodNotificationService.nextInstanceOf9AM();
        expect(result.hour, 9);
        expect(result.minute, 0);
        expect(result.second, 0);
        // Must be either today at 9am (in future) or tomorrow at 9am
        final now = tz.TZDateTime.now(tz.local);
        expect(
          result.isAfter(now.subtract(const Duration(minutes: 1))),
          isTrue,
        );
      });
    });
  });
}
