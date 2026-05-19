import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/event.dart';
import '../../data/firestore_calendar_repository.dart';
import '../../data/google_calendar_repository.dart';
import '../../data/calendar_sync_service.dart';

part 'planner_provider.g.dart';

List<Event> mergeEvents(List<Event> firestoreEvents, List<Event> gcalEvents) {
  final merged = List<Event>.from(firestoreEvents);
  final knownGcalIds = firestoreEvents
      .where((e) => e.googleEventId != null)
      .map((e) => e.googleEventId!)
      .toSet();
  for (final gcalEvent in gcalEvents) {
    if (gcalEvent.googleEventId != null &&
        !knownGcalIds.contains(gcalEvent.googleEventId)) {
      merged.add(gcalEvent);
    }
  }
  merged.sort((a, b) => a.startTime.compareTo(b.startTime));
  return merged;
}

@riverpod
class PlannerNotifier extends _$PlannerNotifier {
  @override
  Future<List<Event>> build() => _load();

  Future<List<Event>> _load() async {
    final from = DateTime.now().subtract(const Duration(days: 1));
    final to = DateTime.now().add(const Duration(days: 30));
    final firestoreRepo = ref.read(firestoreCalendarRepositoryProvider);
    final firestoreEvents =
        await firestoreRepo.watchEvents(from: from, to: to).first;
    List<Event> gcalEvents = [];
    try {
      final gcalRepo = ref.read(googleCalendarRepositoryProvider);
      final connected = await gcalRepo.isConnected();
      if (connected) {
        gcalEvents = await gcalRepo.fetchEvents(from: from, to: to);
      }
    } catch (_) {
      // Google Calendar API unavailable or not enabled — show Firestore events only.
    }
    return mergeEvents(firestoreEvents, gcalEvents);
  }

  Future<void> refresh() async {
    final from = DateTime.now().subtract(const Duration(days: 1));
    final to = DateTime.now().add(const Duration(days: 30));
    try {
      await ref.read(calendarSyncServiceProvider).sync(from: from, to: to);
    } catch (_) {
      // Google Calendar sync failed — refresh from Firestore only.
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}
