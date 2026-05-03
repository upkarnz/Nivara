import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/domain/event_parser.dart';

void main() {
  group('parseScheduledEvent', () {
    test('returns null when content has no JSON block', () {
      const content = 'Sure, I can help you with that!';
      expect(parseScheduledEvent(content), isNull);
    });

    test('returns null when JSON block has no schedule_event key', () {
      const content = '```json\n{"other": "value"}\n```';
      expect(parseScheduledEvent(content), isNull);
    });

    test('parses valid schedule_event JSON block', () {
      const content = 'I\'ve scheduled that for you!\n'
          '```json\n'
          '{"schedule_event": {"title": "Team standup", '
          '"start": "2026-05-10T09:00:00", '
          '"end": "2026-05-10T09:30:00"}}\n'
          '```';

      final result = parseScheduledEvent(content);
      expect(result, isNotNull);
      expect(result!['title'], 'Team standup');
      expect(result['start'], '2026-05-10T09:00:00');
      expect(result['end'], '2026-05-10T09:30:00');
    });

    test('parses inline JSON without code fence', () {
      const content = 'Done! {"schedule_event": {"title": "Lunch", '
          '"start": "2026-05-11T12:00:00", '
          '"end": "2026-05-11T13:00:00"}}';

      final result = parseScheduledEvent(content);
      expect(result, isNotNull);
      expect(result!['title'], 'Lunch');
    });

    test('returns null when JSON is malformed', () {
      const content = '```json\n{"schedule_event": {bad json}}\n```';
      expect(parseScheduledEvent(content), isNull);
    });
  });
}
