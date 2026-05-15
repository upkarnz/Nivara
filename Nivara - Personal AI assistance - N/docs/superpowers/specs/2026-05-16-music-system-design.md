# Music System Design

**Date:** 2026-05-16
**Status:** Approved

---

## Goal

Give Nivara a mood-aware music system that plays royalty-free bundled tracks offline, optionally hands off to Spotify for in-app playback, and integrates with Rocky for both proactive suggestions and voice command control. The experience is always-visible (mini-player bar) with a tap-to-expand full-screen player.

---

## Architecture

### Approach

Unified `MusicService` abstract interface with two concrete implementations (`LocalMusicService`, `SpotifyMusicService`). A single `MusicPlayerNotifier` owns all playback state regardless of source. Mood playlist logic, voice commands, and the mini-player all talk to the same provider tree — the active source is an implementation detail.

### Module Location

`lib/features/music/` — feature-isolated, following the existing `data/domain/presentation` split used by mood and chat features.

---

## Components

### Domain Layer (`domain/`)

| File | Responsibility |
|------|----------------|
| `music_track.dart` | `MusicTrack` entity: id, title, artist, duration, moodTags, assetPath (nullable), spotifyUri (nullable) |
| `music_playlist.dart` | `MusicPlaylist` entity: mood category, ordered `List<MusicTrack>` |
| `mood_category.dart` | `MoodCategory` enum: `calm`, `neutral`, `energized` |
| `music_source.dart` | `MusicSource` enum: `local`, `spotify` |
| `music_service.dart` | Abstract `MusicService`: `play(track)`, `pause()`, `resume()`, `skip()`, `stop()`, `seekTo(Duration)` |
| `music_repository.dart` | Abstract `MusicRepository`: `getPlaylistForMood(MoodCategory)`, `getAllTracks()` |

### Data Layer (`data/`)

| File | Responsibility |
|------|----------------|
| `local_music_service.dart` | Implements `MusicService` using `just_audio` (already in pubspec) |
| `spotify_music_service.dart` | Implements `MusicService` via Spotify iOS/Android SDK |
| `local_music_repository.dart` | Reads Dart-const track manifest + `assets/music/` directory |
| `spotify_repository.dart` | Fetches playlist metadata from Spotify Web API |
| `music_manifest.dart` | Dart const: maps track IDs → title, artist, duration, moodTags, assetPath |

### Presentation Providers (`presentation/providers/`)

| Provider | Type | Responsibility |
|----------|------|----------------|
| `musicSourceProvider` | `StateProvider<MusicSource>` | Active source (default: `local`) |
| `musicServiceProvider` | `Provider<MusicService>` | Resolves correct implementation from `musicSourceProvider` |
| `musicRepositoryProvider` | `Provider<MusicRepository>` | Resolves correct repository |
| `musicPlayerNotifier` | `StateNotifier<MusicPlayerState>` | All playback state, single source of truth |
| `moodPlaylistProvider` | `FutureProvider<MusicPlaylist?>` | Reads mood average → returns matched playlist |
| `spotifyAuthProvider` | `StateNotifier<SpotifyAuthState>` | Spotify login / Premium check state |

### Presentation Widgets (`presentation/`)

| Widget | Responsibility |
|--------|----------------|
| `MusicPage` | Full-screen player: album art, progress bar, controls, playlist list, Spotify toggle |
| `MiniPlayerWidget` | Slim bar above `BottomNavigationBar`; zero-height when no track playing |
| `SpotifyToggleWidget` | Source switch inside `MusicPage`; triggers auth flow if needed |

### Voice Integration

| File | Responsibility |
|------|----------------|
| `music_command_handler.dart` | Matches voice utterances to `musicPlayerNotifier` actions before LLM call |

---

## State Shape

### `MusicPlayerState` (immutable)

```dart
class MusicPlayerState {
  final bool isPlaying;
  final MusicTrack? currentTrack;
  final MusicPlaylist? playlist;
  final Duration progress;
  final bool isMoodAutoPlay;   // persisted to SharedPreferences
  final MusicSource source;    // mirrors musicSourceProvider
}
```

---

## Data Flow

### Mood Playlist Matching

```
weekMoodProvider (existing)
        │
        ▼
moodPlaylistProvider
  avg ≤ 2.0  →  MoodCategory.calm
  2.1–2.9   →  MoodCategory.neutral
  ≥ 3.0     →  MoodCategory.energized
  empty/err  →  null (no auto-play)
        │
        ▼
MusicPlayerNotifier.autoPlayForMood()
  called on MusicPage entry if isMoodAutoPlay == true && currentTrack == null
  loads playlist → plays first track
```

### Playback Flow

```
User action / voice command / auto-play trigger
        │
        ▼
MusicPlayerNotifier
        │
        ▼
musicServiceProvider → LocalMusicService or SpotifyMusicService
        │
        ▼
just_audio (local) OR Spotify SDK (spotify)
        │
        ▼
State update → MiniPlayerWidget + MusicPage rebuild
```

### Source Switching (local ↔ Spotify)

1. User taps toggle in `MusicPage`
2. `musicSourceProvider` flips to `spotify`
3. `musicServiceProvider` resolves `SpotifyMusicService`
4. If not authenticated → `SpotifyAuthFlow` runs; on cancel, toggle reverts to `local`
5. `musicPlayerNotifier` stops local playback, starts equivalent on Spotify
6. Switching back to local is instant (no auth)

---

## UI Layout

### Mini-Player Injection

```
MainShell
  └── Scaffold
        ├── body: current page
        └── bottomNavigationBar: Column(
              children: [
                MiniPlayerWidget(),   // SizedBox.shrink() when no track
                BottomNavigationBar(),
              ]
            )
```

`MusicPage` is pushed as a standard route (not a bottom sheet). The mini-player remains visible in all other screens while music plays.

### Mood-to-Playlist Mapping

| MoodCategory | Score range | Character |
|---|---|---|
| `calm` | avg ≤ 2.0 | Ambient, slow, instrumental |
| `neutral` | 2.1–2.9 | Lo-fi, background, mid-tempo |
| `energized` | ≥ 3.0 | Upbeat, focus beats, bright |

For Spotify: `SpotifyMusicService` searches for a Spotify playlist matching the category label rather than playing a bundled asset.

### Auto-Play Trigger

`MusicPage`'s `initState` calls `musicPlayerNotifier.autoPlayForMood()` if `isMoodAutoPlay == true` and `currentTrack == null`.

---

## Voice Integration

### Command Matching

Commands are matched with simple string patterns before the Hermes call. On match, the action fires and Rocky responds with a short spoken acknowledgement — no LLM round-trip.

| Utterance pattern | Action |
|---|---|
| "play music" / "start music" | `notifier.autoPlayForMood()` |
| "pause" / "stop music" | `notifier.pause()` |
| "resume" / "continue" | `notifier.resume()` |
| "skip" / "next song" | `notifier.skip()` |
| "play something calmer" / "something relaxing" | `notifier.playForCategory(calm)` |
| "play something upbeat" / "energize me" | `notifier.playForCategory(energized)` |
| "turn off music" | `notifier.stop()` |

### Proactive Suggestions

In `ChatNotifier.sendMessage`, after the mood tone hint is resolved, a second check runs:

```
if currentTrack == null
   && moodCategory == calm
   → append to system prompt:
     "If contextually appropriate, suggest the user play some music."
```

Rocky decides whether to surface the suggestion — it is never forced.

---

## Bundled Assets

- Tracks stored in `assets/music/`
- Registered in `pubspec.yaml` under `flutter.assets`
- `music_manifest.dart` — Dart const list mapping each track to its metadata and mood tags
- Minimum: 3 tracks per mood category (9 tracks total)

---

## Error Handling

### Spotify Errors

| Scenario | Behaviour |
|---|---|
| Spotify app not installed | Inline message in toggle area: "Spotify app required" |
| Not Premium | Inline message: "Spotify Premium needed for in-app playback" |
| Auth cancelled | Toggle reverts to `local`, no crash |
| Playback error mid-stream | Fall back to `local`, show snackbar |

### Local Playback Errors

- Asset load failure → skip to next track silently
- All tracks fail → `currentTrack = null`, mini-player hides

### Persistence Errors

- `SharedPreferences` write failure for `isMoodAutoPlay` → silently ignored; in-memory state correct for session

---

## Files Changed

| File | Action |
|------|--------|
| `lib/features/music/domain/music_track.dart` | **Create** |
| `lib/features/music/domain/music_playlist.dart` | **Create** |
| `lib/features/music/domain/mood_category.dart` | **Create** |
| `lib/features/music/domain/music_source.dart` | **Create** |
| `lib/features/music/domain/music_service.dart` | **Create** — abstract interface |
| `lib/features/music/domain/music_repository.dart` | **Create** — abstract interface |
| `lib/features/music/data/music_manifest.dart` | **Create** — Dart const track list |
| `lib/features/music/data/local_music_service.dart` | **Create** — just_audio implementation |
| `lib/features/music/data/spotify_music_service.dart` | **Create** — Spotify SDK implementation |
| `lib/features/music/data/local_music_repository.dart` | **Create** |
| `lib/features/music/data/spotify_repository.dart` | **Create** |
| `lib/features/music/presentation/providers/music_source_provider.dart` | **Create** |
| `lib/features/music/presentation/providers/music_service_provider.dart` | **Create** |
| `lib/features/music/presentation/providers/music_player_notifier.dart` | **Create** |
| `lib/features/music/presentation/providers/mood_playlist_provider.dart` | **Create** |
| `lib/features/music/presentation/providers/spotify_auth_provider.dart` | **Create** |
| `lib/features/music/presentation/pages/music_page.dart` | **Create** |
| `lib/features/music/presentation/widgets/mini_player_widget.dart` | **Create** |
| `lib/features/music/presentation/widgets/spotify_toggle_widget.dart` | **Create** |
| `lib/features/music/presentation/voice/music_command_handler.dart` | **Create** |
| `lib/features/chat/presentation/providers/chat_provider.dart` | **Modify** — add proactive music suggestion check |
| `lib/main_shell.dart` (or equivalent) | **Modify** — inject `MiniPlayerWidget` above `BottomNavigationBar` |
| `pubspec.yaml` | **Modify** — add `assets/music/` and Spotify SDK dependency |
| `assets/music/` | **Create** — bundled royalty-free audio files (min 9 tracks) |
| `test/features/music/` | **Create** — unit tests for all providers and services |

---

## Testing

### `music_player_notifier_test.dart`

| Test | Scenario |
|------|----------|
| Plays track | `play(track)` sets `isPlaying = true`, `currentTrack = track` |
| Pauses | `pause()` sets `isPlaying = false` |
| Skips to next | `skip()` advances to next track in playlist |
| Skip at end of playlist | Wraps to first track |
| Stop clears state | `stop()` sets `currentTrack = null`, `isPlaying = false` |
| Auto-play respects toggle | `autoPlayForMood()` no-ops when `isMoodAutoPlay == false` |
| Auto-play no-ops when playing | Does not interrupt current playback |

### `mood_playlist_provider_test.dart`

| Test | Scenario |
|------|----------|
| Returns calm playlist | avg ≤ 2.0 |
| Returns neutral playlist | avg 2.1–2.9 |
| Returns energized playlist | avg ≥ 3.0 |
| Returns null | Empty mood history |
| Returns null on error | `weekMoodProvider` throws |

### `music_command_handler_test.dart`

| Test | Scenario |
|------|----------|
| "play music" triggers auto-play | Command matched, notifier called |
| "pause" pauses playback | Command matched |
| "something calmer" plays calm | Category override applied |
| Unrecognised utterance passes through | No music action, message proceeds to Hermes |

### `local_music_service_test.dart`

| Test | Scenario |
|------|----------|
| Play completes without error | Track with valid asset path |
| Skip advances index | Two tracks in playlist |
| Asset error skips track | Invalid path silently skipped |

---

## Non-Goals

- No music discovery / search UI
- No user-created playlists
- No streaming from the internet (local tracks are bundled assets)
- No lyrics display
- No social features
- No Firestore reads beyond what `weekMoodProvider` already does

---

## Open Questions

None. All decisions made during design session.
