# AI Loop Design — Mood-Aware Tone Adaptation

**Date:** 2026-05-15  
**Status:** Approved

---

## Goal

Make Nivara's conversational tone subtly adapt to the user's recent emotional state, without ever mentioning mood directly. When the user has been feeling low, Nivara becomes warmer and gentler. When they're doing well, Nivara uses its default tone. The effect is invisible — the user feels understood, not analysed.

---

## Architecture

### Components

| Component | Type | Responsibility |
|-----------|------|----------------|
| `weekMoodProvider` | `FutureProvider<List<MoodEntry>>` | Already exists. Returns last 7 mood entries (may be <7 if history is short). |
| `moodToneProvider` | `FutureProvider<String?>` | Reads `weekMoodProvider`, computes rolling average, returns tone hint string or null. |
| `ChatProvider` | `StateNotifier` | Reads `moodToneProvider` before each Hermes call; appends tone hint to system prompt when non-null. |

### Data Flow

```
weekMoodProvider (existing)
        │
        ▼
moodToneProvider
  ┌─────────────────────────────────────────────────────┐
  │  avg ≤ 2.0  →  "Be warm and gentle. Avoid upbeat   │
  │                 openers."                            │
  │  2.1–2.9   →  "Keep your tone calm and measured."   │
  │  ≥ 3.0     →  null  (no injection, default tone)   │
  │  error     →  null  (safe default)                  │
  └─────────────────────────────────────────────────────┘
        │
        ▼
ChatProvider.sendMessage()
  - reads moodToneProvider
  - if non-null: appends hint to system prompt string
  - calls Hermes API with (possibly modified) system prompt
  - tone hint is never shown in UI, never logged to chat history
```

---

## Tone Thresholds

Mood values are integers 1–5 (1 = very low, 5 = very high).

| Rolling 7-day Average | Tone Hint Injected |
|-----------------------|--------------------|
| ≤ 2.0 | `"Be warm and gentle. Avoid upbeat openers."` |
| 2.1 – 2.9 | `"Keep your tone calm and measured."` |
| ≥ 3.0 | `null` — no injection, Nivara uses its default persona |

**Why these thresholds?** Values 1–2 represent genuinely low mood. Values 3–5 are neutral to positive — Nivara's default tone already works well there. The 2.1–2.9 band catches borderline cases with a lighter touch.

**Minimum data requirement:** If `weekMoodProvider` returns an empty list (no mood history yet), `moodToneProvider` returns `null`. No injection until there is enough signal.

---

## System Prompt Injection

The hint is appended to the existing system prompt with two newlines as separator:

```
<existing system prompt>

Be warm and gentle. Avoid upbeat openers.
```

The hint is:
- Never shown in any chat bubble
- Never persisted to Firestore or local storage
- Not included in message history passed to Hermes
- Applied fresh on every `sendMessage()` call (reflects mood changes without requiring app restart)

---

## Error Handling

`moodToneProvider` catches all exceptions and returns `null`. `ChatProvider` treats a null tone as "use default system prompt unchanged". This means any failure in the mood pipeline degrades gracefully — Nivara responds normally rather than throwing.

---

## Files Changed

| File | Action |
|------|--------|
| `lib/features/mood/providers/mood_tone_provider.dart` | **Create** — `moodToneProvider` FutureProvider |
| `lib/features/chat/providers/chat_provider.dart` | **Modify** — inject tone hint before Hermes call |
| `test/features/mood/mood_tone_provider_test.dart` | **Create** — unit tests for all threshold buckets |
| `test/features/chat/chat_provider_tone_test.dart` | **Create** — unit tests for injection + null path |

---

## Testing

### `mood_tone_provider_test.dart`

| Test | Scenario |
|------|----------|
| Returns warm hint | avg ≤ 2.0 (e.g. entries [1, 2, 1, 2, 2]) |
| Returns calm hint | avg 2.1–2.9 (e.g. entries [2, 3, 2, 3, 2]) |
| Returns null | avg ≥ 3.0 (e.g. entries [3, 4, 5, 4, 3]) |
| Returns null | empty list (no history) |
| Returns null | exactly at 2.0 boundary (returns warm, not null) |
| Returns null | exactly at 3.0 boundary (returns null) |
| Returns null on error | weekMoodProvider throws AsyncError |

### `chat_provider_tone_test.dart`

| Test | Scenario |
|------|----------|
| Appends hint to system prompt | moodToneProvider returns non-null hint |
| Uses unmodified system prompt | moodToneProvider returns null |
| Uses unmodified system prompt | moodToneProvider throws |
| Hint not in outbound message list | hint appears in system prompt only, never in messages |

---

## Non-Goals

- Nivara never mentions mood to the user ("I see you've been feeling down lately")
- No UI changes — this is entirely invisible infrastructure
- No new Firestore reads beyond what `weekMoodProvider` already does
- No per-message mood analysis — only the rolling history average is used

---

## Open Questions

None. All decisions made during design session.
