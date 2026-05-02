import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/event.dart';

part 'google_calendar_repository.g.dart';

const _calendarScope = 'https://www.googleapis.com/auth/calendar';

@riverpod
GoogleCalendarRepository googleCalendarRepository(
    // ignore: deprecated_member_use_from_same_package
    GoogleCalendarRepositoryRef ref) {
  return GoogleCalendarRepository(
    googleSignIn: GoogleSignIn(scopes: [_calendarScope]),
  );
}

class GoogleCalendarRepository {
  GoogleCalendarRepository({required GoogleSignIn googleSignIn})
      : _googleSignIn = googleSignIn;

  final GoogleSignIn _googleSignIn;

  Future<gcal.CalendarApi?> _getApi() async {
    await _googleSignIn.signInSilently();
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return gcal.CalendarApi(client);
  }

  Future<bool> isConnected() async {
    await _googleSignIn.signInSilently();
    final client = await _googleSignIn.authenticatedClient();
    return client != null;
  }

  Future<bool> requestAccess() async {
    try {
      await _googleSignIn.signInSilently();
      return await _googleSignIn.requestScopes([_calendarScope]);
    } catch (_) {
      return false;
    }
  }

  Future<List<Event>> fetchEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    final api = await _getApi();
    if (api == null) return [];
    final result = await api.events.list(
      'primary',
      timeMin: from.toUtc(),
      timeMax: to.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );
    return (result.items ?? []).map(_fromGCalEvent).toList();
  }

  Future<String?> createEvent(Event event) async {
    final api = await _getApi();
    if (api == null) return null;
    final gcalEvent = gcal.Event(
      summary: event.title,
      description: event.description,
      location: event.location,
      start: gcal.EventDateTime(dateTime: event.startTime.toUtc()),
      end: gcal.EventDateTime(dateTime: event.endTime.toUtc()),
    );
    final created = await api.events.insert(gcalEvent, 'primary');
    return created.id;
  }

  Future<void> updateEvent(String googleEventId, Event event) async {
    final api = await _getApi();
    if (api == null) return;
    final gcalEvent = gcal.Event(
      summary: event.title,
      description: event.description,
      location: event.location,
      start: gcal.EventDateTime(dateTime: event.startTime.toUtc()),
      end: gcal.EventDateTime(dateTime: event.endTime.toUtc()),
    );
    await api.events.update(gcalEvent, 'primary', googleEventId);
  }

  Future<void> deleteEvent(String googleEventId) async {
    final api = await _getApi();
    if (api == null) return;
    await api.events.delete('primary', googleEventId);
  }

  Event _fromGCalEvent(gcal.Event e) => Event(
        id: '',
        userId: '',
        title: e.summary ?? '(no title)',
        startTime: e.start?.dateTime?.toLocal() ?? e.start!.date!.toLocal(),
        endTime: e.end?.dateTime?.toLocal() ?? e.end!.date!.toLocal(),
        description: e.description,
        location: e.location,
        source: EventSource.googleCalendar,
        googleEventId: e.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}
