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

      test('returned time is in the future relative to now', () {
        final before = tz.TZDateTime.now(tz.local);
        final result = MoodNotificationService.nextInstanceOf9AM();

        expect(result.isAfter(before), isTrue,
            reason: 'Scheduled time must be strictly after now');
      });
    });
  });
}
