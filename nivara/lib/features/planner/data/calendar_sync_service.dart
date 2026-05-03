import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/event.dart';
import 'firestore_calendar_repository.dart';
import 'google_calendar_repository.dart';

part 'calendar_sync_service.g.dart';

@riverpod
CalendarSyncService calendarSyncService(
    // ignore: deprecated_member_use_from_same_package
    CalendarSyncServiceRef ref) {
  return CalendarSyncService(
    firestoreRepo: ref.read(firestoreCalendarRepositoryProvider),
    gcalRepo: ref.read(googleCalendarRepositoryProvider),
  );
}

class CalendarSyncService {
  CalendarSyncService({
    required FirestoreCalendarRepository firestoreRepo,
    required GoogleCalendarRepository gcalRepo,
  })  : _firestore = firestoreRepo,
        _gcal = gcalRepo;

  final FirestoreCalendarRepository _firestore;
  final GoogleCalendarRepository _gcal;

  Future<void> pushToGoogleCalendar() async {
    final connected = await _gcal.isConnected();
    if (!connected) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final from = DateTime.now().subtract(const Duration(days: 1));
    final to = DateTime.now().add(const Duration(days: 60));

    final events = await _firestore.watchEvents(from: from, to: to).first;
    final localOnly = events.where(
        (e) => e.source == EventSource.local && e.googleEventId == null);

    for (final event in localOnly) {
      final gcalId = await _gcal.createEvent(event);
      if (gcalId != null) {
        await _firestore.updateEvent(
          event.copyWith(source: EventSource.synced, googleEventId: gcalId),
        );
      }
    }
  }

  Future<void> pullFromGoogleCalendar({
    required DateTime from,
    required DateTime to,
  }) async {
    final connected = await _gcal.isConnected();
    if (!connected) return;

    final gcalEvents = await _gcal.fetchEvents(from: from, to: to);
    final firestoreEvents =
        await _firestore.watchEvents(from: from, to: to).first;
    final knownGcalIds = firestoreEvents
        .where((e) => e.googleEventId != null)
        .map((e) => e.googleEventId!)
        .toSet();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    for (final gcalEvent in gcalEvents) {
      if (gcalEvent.googleEventId != null &&
          !knownGcalIds.contains(gcalEvent.googleEventId)) {
        await _firestore.createEvent(gcalEvent.copyWith(userId: uid));
      }
    }
  }

  Future<void> sync({required DateTime from, required DateTime to}) async {
    await pushToGoogleCalendar();
    await pullFromGoogleCalendar(from: from, to: to);
  }
}
