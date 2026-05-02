# AI Planner — Design Spec

**Date:** 2026-05-03  
**Feature:** Natural language scheduling, calendar views, Google Calendar sync  
**App:** Nivara Flutter app

---

## Overview

Add a Planner feature to Nivara: users schedule events by chatting naturally, view an agenda of upcoming events, and optionally sync bidirectionally with Google Calendar.

Entry point: 📅 icon added to ChatPage AppBar. No bottom navigation change.

---

## Architecture

```
User input (chat/voice)
    ↓
Hermes/Claude (detects scheduling intent)
    → returns <event>JSON</event> tag + confirmation text
    ↓
ChatNotifier (scans stream for <event> tags)
    → parses JSON → creates Event → saves to Firestore
    ↓
Firestore: users/{uid}/events  ← source of truth
    ↕
CalendarSyncService (bi-directional)
    ↕
Google Calendar API (optional, via googleapis package)
```

### Event sources

```dart
enum EventSource { local, googleCalendar, synced }
```

- `local` — created in Nivara, not synced to GCal
- `googleCalendar` — imported from GCal, not mirrored to Firestore
- `synced` — exists in both (Firestore + GCal, has googleEventId)

---

## Data Model

### Event (domain/event.dart)

```dart
class Event {
  final String id;            // Firestore doc ID
  final String userId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? description;
  final String? location;
  final EventSource source;
  final String? googleEventId; // null unless synced/googleCalendar
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Firestore path: `users/{uid}/events/{eventId}`

Firestore document fields mirror above. `startTime`/`endTime` stored as Timestamps.

### Serialization

No freezed/json_serializable for now. Manual `fromJson`/`toJson` methods. Keep deps minimal.

---

## Repository Layer

### CalendarRepository (domain/calendar_repository.dart)

Abstract interface:

```dart
abstract class CalendarRepository {
  Stream<List<Event>> watchEvents({required DateTime from, required DateTime to});
  Future<Event> createEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent(String eventId);
}
```

### FirestoreCalendarRepository (data/firestore_calendar_repository.dart)

Implements `CalendarRepository`. Reads/writes `users/{uid}/events`.

- `watchEvents`: Firestore `snapshots()` stream filtered by startTime range
- `createEvent`: `collection.add(event.toJson())`, returns Event with Firestore ID
- `updateEvent`: `doc.update(event.toJson())`
- `deleteEvent`: `doc.delete()`

Riverpod provider: `@riverpod FirestoreCalendarRepository firestoreCalendarRepository(ref)`

### GoogleCalendarRepository (data/google_calendar_repository.dart)

Wraps `googleapis` `CalendarApi`. Returns null/no-ops when user hasn't granted calendar scope.

```dart
class GoogleCalendarRepository {
  Future<List<Event>> fetchEvents({required DateTime from, required DateTime to});
  Future<String?> createEvent(Event event); // returns GCal event ID
  Future<void> updateEvent(String googleEventId, Event event);
  Future<void> deleteEvent(String googleEventId);
  Future<bool> isConnected(); // checks if calendar scope granted
}
```

Auth bridging: `extension_google_sign_in_as_googleapis_auth` converts existing `GoogleSignIn` session to `AuthClient` for `CalendarApi`. No separate OAuth flow.

Riverpod provider: `@riverpod GoogleCalendarRepository googleCalendarRepository(ref)`

---

## Google Calendar OAuth

### Scopes

Add `https://www.googleapis.com/auth/calendar` to `GoogleSignIn` scopes during the consent flow.

Existing sign-in (Firebase/Google) uses `google_sign_in` without calendar scope. CalendarConsent page requests incremental authorization:

```dart
await _googleSignIn.requestScopes(['https://www.googleapis.com/auth/calendar']);
```

### Two entry points

1. **Onboarding** — `CalendarConsentPage` inserted between `assistant-setup` and `chat` in the setup flow. Skippable; user can always connect later.

2. **Settings** — "Connect Google Calendar" card in `VoiceSettingsPage` (or separate settings page). Shows current connection status; tapping triggers same `requestScopes` call.

Connection state stored in `UserProfile` in Firestore: `calendarConnected: bool`.

---

## CalendarSyncService (data/calendar_sync_service.dart)

Runs on demand (not a background daemon — Flutter doesn't support true background on iOS/Android without plugins).

Triggered:
- After user grants calendar permission
- On PlannerPage pull-to-refresh
- After ChatNotifier creates an event (async, fire-and-forget)

```dart
class CalendarSyncService {
  // Push local-only events to GCal, tag them as synced
  Future<void> pushToGoogleCalendar();

  // Pull GCal events not in Firestore, add as googleCalendar source
  Future<void> pullFromGoogleCalendar({required DateTime from, required DateTime to});

  // Full bidirectional sync
  Future<void> sync({required DateTime from, required DateTime to});
}
```

Conflict resolution: last-write-wins based on `updatedAt`. Events deleted from GCal are NOT auto-deleted from Firestore (user must delete explicitly in Nivara).

---

## Chat Event Parsing

### In ChatNotifier.sendMessage (chat_provider.dart)

After stream completes, scan final response for `<event>` tags:

```dart
// regex to extract event JSON
final _eventTagRe = RegExp(r'<event>(.*?)</event>', dotAll: true);

void _parseAndSaveEvents(String responseText, String userId) {
  final matches = _eventTagRe.allMatches(responseText);
  for (final m in matches) {
    final json = jsonDecode(m.group(1)!);
    final event = Event.fromJson({...json, 'userId': userId, 'source': 'local'});
    ref.read(firestoreCalendarRepositoryProvider).createEvent(event);
    // fire-and-forget GCal sync
    ref.read(calendarSyncServiceProvider).pushToGoogleCalendar();
  }
}
```

### System prompt addition

Hermes system prompt gets instruction: when user expresses scheduling intent, include structured event in response using `<event>` tag:

```
<event>{"title":"Lunch with Sarah","startTime":"2026-05-04T13:00:00","endTime":"2026-05-04T14:00:00","description":null,"location":null}</event>
```

Times in ISO 8601. Duration defaults to 1 hour if endTime omitted.

### Confirmation card in MessageBubble

`message_bubble.dart` checks for `<event>` tags in content. If found, renders an inline event card below the text with title, time, sync status, Edit and Delete buttons. The `<event>...</event>` tag itself is stripped from displayed text.

---

## PlannerPage (presentation/pages/planner_page.dart)

### UI

```
AppBar: "My Planner" | sync icon | + icon
[Google Calendar status bar — shows last sync time or "Not connected"]
ScrollView (agenda):
  TODAY — SATURDAY MAY 3
    [EventTile] Team standup · 3:30 PM · 30 min
    [EventTile] Gym session · 6:00 PM · 1 hr
  SUN MAY 4
    [EventTile] Lunch with Sarah · 1:00 PM · 1 hr
  MON MAY 5
    No events
```

Pull-to-refresh triggers `CalendarSyncService.sync`.

AppBar `+` icon opens a simple form (title, date, time) for manual event creation without chat.

### PlannerNotifier (presentation/providers/planner_provider.dart)

```dart
@riverpod
class PlannerNotifier extends _$PlannerNotifier {
  @override
  Future<List<Event>> build() async {
    final from = DateTime.now().subtract(const Duration(days: 1));
    final to = DateTime.now().add(const Duration(days: 30));
    // merge Firestore stream + GCal fetch
    final firestoreEvents = await ref
        .watch(firestoreCalendarRepositoryProvider)
        .watchEvents(from: from, to: to)
        .first;
    final gcalRepo = ref.read(googleCalendarRepositoryProvider);
    final connected = await gcalRepo.isConnected();
    final gcalEvents = connected
        ? await gcalRepo.fetchEvents(from: from, to: to)
        : <Event>[];
    return _merge(firestoreEvents, gcalEvents);
  }

  // de-dupe by googleEventId
  List<Event> _merge(List<Event> firestore, List<Event> gcal) { ... }

  Future<void> refresh() => ref.refresh(plannerNotifierProvider.future);
}
```

### EventTile (presentation/widgets/event_tile.dart)

Left-border color by source:
- Blue (`Color(0xFF4285F4)`) — googleCalendar
- Purple (`Color(0xFF7C6EF7)`) — local (Nivara)
- Green (`Color(0xFF4CAF50)`) — synced

Shows: title, time, duration, source label. Tappable for detail/edit sheet.

---

## CalendarConsentPage (presentation/pages/calendar_consent_page.dart)

Stateless page. Shows:
- Brief explanation of Google Calendar sync
- "Connect Google Calendar" primary button
- "Skip for now" text button

On connect: calls `GoogleSignIn.requestScopes([calendarScope])`. On success, updates `UserProfile.calendarConnected = true`, navigates to `/chat`. On error, shows snackbar.

On skip: navigates to `/chat`.

---

## New Routes (app_router.dart additions)

```dart
GoRoute(
  path: '/planner',
  builder: (_, __) => const PlannerPage(),
),
GoRoute(
  path: '/calendar-consent',
  builder: (_, __) => const CalendarConsentPage(),
),
```

No auth guard needed on `/planner` (GoRouter redirect handles it globally).

Onboarding flow: `assistant-setup` → `calendar-consent` (new) → `chat`

`AssistantSetupPage` completion navigates to `/calendar-consent` instead of `/chat`.

---

## ChatPage changes (chat_page.dart)

Add 📅 icon to AppBar `actions` list (before existing settings icon):

```dart
IconButton(
  icon: const Icon(Icons.calendar_month_outlined),
  tooltip: 'Planner',
  onPressed: () => context.push('/planner'),
),
```

---

## New Dependencies (pubspec.yaml)

```yaml
googleapis: ^13.2.0
extension_google_sign_in_as_googleapis_auth: ^2.0.12
```

`googleapis` provides `CalendarApi`. `extension_google_sign_in_as_googleapis_auth` bridges `GoogleSignIn` authentication to the `AuthClient` interface required by googleapis.

---

## Error Handling

| Scenario | Handling |
|----------|----------|
| GCal not connected | Repository returns empty list; UI shows "Connect" prompt |
| GCal API error during sync | Log error; show snackbar on PlannerPage; Firestore events still shown |
| Malformed `<event>` JSON in chat | Catch parse error, skip event creation, log warning |
| Firestore write failure | Bubble error to ChatNotifier; show snackbar |
| Calendar scope denied by user | `isConnected()` returns false; graceful degradation to local-only |

---

## Files Summary

### New files

| File | Purpose |
|------|---------|
| `lib/features/planner/domain/event.dart` | Event model + EventSource enum |
| `lib/features/planner/domain/calendar_repository.dart` | Abstract repo interface |
| `lib/features/planner/data/firestore_calendar_repository.dart` | Firestore impl |
| `lib/features/planner/data/google_calendar_repository.dart` | GCal API impl |
| `lib/features/planner/data/calendar_sync_service.dart` | Bi-directional sync |
| `lib/features/planner/presentation/pages/planner_page.dart` | Agenda UI |
| `lib/features/planner/presentation/pages/calendar_consent_page.dart` | OAuth consent page |
| `lib/features/planner/presentation/providers/planner_provider.dart` | Riverpod notifier |
| `lib/features/planner/presentation/widgets/event_tile.dart` | Event list row |

### Modified files

| File | Change |
|------|--------|
| `pubspec.yaml` | Add googleapis + extension dep |
| `lib/router/app_router.dart` | Add /planner, /calendar-consent routes |
| `lib/features/chat/presentation/pages/chat_page.dart` | Add 📅 AppBar icon |
| `lib/features/chat/presentation/providers/chat_provider.dart` | Parse `<event>` tags, save events |
| `lib/features/chat/presentation/widgets/message_bubble.dart` | Render event confirmation card |
| `lib/features/profile/presentation/pages/assistant_setup_page.dart` | Navigate to /calendar-consent on complete |
| `lib/voice/voice_settings_page.dart` | Add "Connect Google Calendar" section |

---

## Testing Strategy

- **Unit**: Event `fromJson`/`toJson`, `_eventTagRe` regex parsing, `_merge` deduplication logic, CalendarSyncService sync logic
- **Widget**: PlannerPage renders events grouped by day; EventTile color by source; CalendarConsentPage shows skip button
- **Integration**: ChatNotifier creates event in Firestore after receiving `<event>` tag; FirestoreCalendarRepository roundtrip
- **Manual**: Full OAuth flow on device; GCal sync push/pull; event creation via chat
