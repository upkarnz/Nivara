import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/planner/domain/event.dart';
import 'package:nivara/features/planner/presentation/providers/planner_provider.dart';

Event _makeEvent({
  required String id,
  required EventSource source,
  String? googleEventId,
  required DateTime startTime,
}) =>
    Event(
      id: id,
      userId: 'uid1',
      title: 'Event $id',
      startTime: startTime,
      endTime: startTime.add(const Duration(hours: 1)),
      source: source,
      googleEventId: googleEventId,
      createdAt: DateTime(2026, 5, 1),
      updatedAt: DateTime(2026, 5, 1),
    );

void main() {
  final base = DateTime(2026, 5, 4, 9, 0);

  test('mergeEvents includes all Firestore events', () {
    final firestore = [
      _makeEvent(id: 'f1', source: EventSource.local, startTime: base),
      _makeEvent(id: 'f2', source: EventSource.synced, googleEventId: 'g1', startTime: base.add(const Duration(hours: 2))),
    ];
    final result = mergeEvents(firestore, []);
    expect(result.length, 2);
    expect(result.map((e) => e.id), containsAll(['f1', 'f2']));
  });

  test('mergeEvents adds GCal events not already in Firestore', () {
    final firestore = [
      _makeEvent(id: 'f1', source: EventSource.local, startTime: base),
    ];
    final gcal = [
      _makeEvent(id: '', source: EventSource.googleCalendar, googleEventId: 'g99', startTime: base.add(const Duration(hours: 1))),
    ];
    final result = mergeEvents(firestore, gcal);
    expect(result.length, 2);
    expect(result.any((e) => e.googleEventId == 'g99'), isTrue);
  });

  test('mergeEvents does not duplicate events already tracked by googleEventId', () {
    final firestore = [
      _makeEvent(id: 'f1', source: EventSource.synced, googleEventId: 'g1', startTime: base),
    ];
    final gcal = [
      _makeEvent(id: '', source: EventSource.googleCalendar, googleEventId: 'g1', startTime: base),
    ];
    final result = mergeEvents(firestore, gcal);
    expect(result.length, 1);
  });

  test('mergeEvents sorts by startTime ascending', () {
    final firestore = [
      _makeEvent(id: 'f2', source: EventSource.local, startTime: base.add(const Duration(hours: 2))),
      _makeEvent(id: 'f1', source: EventSource.local, startTime: base),
    ];
    final gcal = [
      _makeEvent(id: '', source: EventSource.googleCalendar, googleEventId: 'g1', startTime: base.add(const Duration(hours: 1))),
    ];
    final result = mergeEvents(firestore, gcal);
    expect(result[0].id, 'f1');
    expect(result[1].googleEventId, 'g1');
    expect(result[2].id, 'f2');
  });
}
