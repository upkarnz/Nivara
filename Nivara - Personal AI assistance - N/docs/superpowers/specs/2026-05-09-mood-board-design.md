# Mood Board Design Spec

## Goal

Add a mood tracking feature to Nivara: passive sentiment detection from chat messages + optional daily check-in, visualised as an emoji timeline + colour bar chart on a dedicated Mood Board page.

## Architecture

Hermes scores mood as a side-effect of normal message processing and returns `mood_score` + `mood_label` alongside the AI reply. Flutter reads these fields, stores one `MoodEntry` per day in Hive, and exposes data via a Riverpod provider. No new backend endpoints, no extra round trips.

## Tech Stack

- **Backend:** Python (Hermes), LLM prompt for mood scoring, existing SSE response pipeline
- **Frontend:** Flutter, Hive (local storage), Riverpod (state), `flutter_local_notifications`

---

## Data Model

### Hermes response additions

Two optional fields appended to existing response:

```json
{
  "reply": "...",
  "mood_score": 3,
  "mood_label": "neutral"
}
```

`mood_score`: integer 1–5 mapping to 😔😐🙂😄🤩  
`mood_label`: short string ("anxious", "great", "neutral", etc.)  
Both fields omitted on scoring failure — Flutter treats absence as no-op.

### Flutter MoodEntry (Hive, typeId: 4)

```dart
@HiveType(typeId: 4)
class MoodEntry extends HiveObject {
  @HiveField(0) DateTime date;        // date only, time zeroed
  @HiveField(1) int score;            // 1–5
  @HiveField(2) String label;
  @HiveField(3) MoodSource source;    // passive | checkin
}

enum MoodSource { passive, checkin }
```

One entry per calendar day. Last passive score wins within a day. Check-in score always overrides passive regardless of order.

---

## Components

### Hermes (backend)

**`mood_scorer.py`** — new module  
Prompts LLM with user message text, parses 1–5 integer + label from response. Runs after main reply generation, before SSE stream closes. Returns `None` on any failure (timeout, parse error, invalid score).

**Message handler** — existing file, small addition  
After generating reply, call `mood_scorer.score(user_message)`. If result is not `None`, attach `mood_score` and `mood_label` to response dict.

### Flutter

**`MoodEntry` + `MoodSource`** — `lib/models/mood_entry.dart`  
Hive model as above. Hive adapter auto-generated via `build_runner`.

**`MoodRepository`** — `lib/repositories/mood_repository.dart`  
Wraps Hive box. Methods: `save(MoodEntry)`, `getWeek()` → `List<MoodEntry?>` (7 items, null = no data), `getToday()` → `MoodEntry?`.

**`MoodProvider`** — `lib/providers/mood_provider.dart`  
Riverpod `StateNotifierProvider`. Exposes `weekEntries` and `todayEntry`. Listens for new entries and rebuilds.

**Chat response parser** — existing file, small addition  
After parsing Hermes response, check for `mood_score` field. If present, call `moodRepository.save(MoodEntry(..., source: MoodSource.passive))`.

**AppBar change** — `lib/pages/chat_page.dart`  
Add 😊 icon to AppBar action list alongside existing 📅 and ⚙️. Taps → `Navigator.push(MoodBoardPage)`.

**`MoodBoardPage`** — `lib/pages/mood_board_page.dart`  
Full-page route. Layout top to bottom:
1. "THIS WEEK" label
2. Emoji row — 7 columns (Mon–Sun), today highlighted. Missing day shows ❓ at 20% opacity.
3. Colour bar chart — one bar per day, height proportional to score (1–5), purple intensity mapped to score (dark = low, bright = high). Missing day = dashed empty bar.
4. Week average chip — "Week avg: 😊 Mostly positive"

**`CheckInCard`** — `lib/widgets/check_in_card.dart`  
Chat bubble widget. Shows "☀️ Good morning, {name} — How are you feeling today?" with 5 emoji tap targets. On tap: saves `MoodEntry(source: checkin)`, widget dismisses.

**Notification scheduler** — `lib/services/mood_notification_service.dart`  
Uses `flutter_local_notifications`. Schedules daily notification at 09:00 local. On tap: opens app to chat page. Nivara sends `CheckInCard` as first message if no check-in recorded for today. Silently disabled if notification permission denied.

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| Hermes mood scoring fails | Omit fields from response; Flutter no-op |
| Multiple passive messages same day | Last score wins |
| Check-in after passive entry | Check-in always wins |
| Notification dismissed without answering | Day stays empty (❓) |
| Notification permission denied | Check-in disabled; passive still runs |
| App reinstalled | Hive data lost; acceptable for v1 |
| Hive write fails | Log + swallow; non-critical |

---

## Out of Scope (v1)

- Cross-device sync
- Mood history beyond 7 days
- Mood-aware AI response tuning
- Export / backup
