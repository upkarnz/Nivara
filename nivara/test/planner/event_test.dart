import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/planner/domain/event.dart';

void main() {
  group('Event.fromJson', () {
    test('parses required fields', () {
      final json = {
        'userId': 'uid1',
        'title': 'Lunch with Sarah',
        'startTime': '2026-05-04T13:00:00.000',
        'endTime': '2026-05-04T14:00:00.000',
        'source': 'local',
      };
      final event = Event.fromJson(json);
      expect(event.title, equals('Lunch with Sarah'));
      expect(event.userId, equals('uid1'));
      expect(event.source, equals(EventSource.local));
      expect(event.endTime.hour, equals(14));
    });

    test('defaults endTime to startTime + 1h when endTime missing', () {
      final json = {
        'userId': 'uid1',
        'title': 'Quick call',
        'startTime': '2026-05-04T10:00:00.000',
        'source': 'local',
      };
      final event = Event.fromJson(json);
      expect(
        event.endTime,
        equals(event.startTime.add(const Duration(hours: 1))),
      );
    });

    test('parses optional fields as null', () {
      final json = {
        'userId': 'uid1',
        'title': 'Meeting',
        'startTime': '2026-05-04T09:00:00.000',
        'source': 'googleCalendar',
      };
      final event = Event.fromJson(json);
      expect(event.description, isNull);
      expect(event.location, isNull);
      expect(event.googleEventId, isNull);
    });
  });

  group('Event.toJson', () {
    test('round-trips via fromJson', () {
      final original = Event(
        id: 'id1',
        userId: 'uid1',
        title: 'Gym',
        startTime: DateTime(2026, 5, 4, 18, 0),
        endTime: DateTime(2026, 5, 4, 19, 0),
        source: EventSource.synced,
        googleEventId: 'gcal123',
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final json = original.toJson();
      final restored = Event.fromJson({...json, 'userId': original.userId});
      expect(restored.title, equals(original.title));
      expect(restored.source, equals(EventSource.synced));
      expect(restored.googleEventId, equals('gcal123'));
    });
  });

  group('Event.copyWith', () {
    test('produces new instance with updated fields', () {
      final event = Event(
        id: 'id1',
        userId: 'uid1',
        title: 'Old title',
        startTime: DateTime(2026, 5, 4, 9, 0),
        endTime: DateTime(2026, 5, 4, 10, 0),
        source: EventSource.local,
        createdAt: DateTime(2026, 5, 1),
        updatedAt: DateTime(2026, 5, 1),
      );
      final updated = event.copyWith(
        title: 'New title',
        source: EventSource.synced,
      );
      expect(updated.title, equals('New title'));
      expect(updated.source, equals(EventSource.synced));
      expect(updated.id, equals(event.id));
      expect(updated.userId, equals(event.userId));
    });
  });
}
