import 'event.dart';

abstract class CalendarRepository {
  Stream<List<Event>> watchEvents({
    required DateTime from,
    required DateTime to,
  });

  Future<Event> createEvent(Event event);

  Future<void> updateEvent(Event event);

  Future<void> deleteEvent(String eventId);
}
