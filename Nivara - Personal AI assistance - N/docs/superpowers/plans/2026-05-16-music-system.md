# Music System (Plan 6a — Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a mood-aware local music system with bundled royalty-free tracks, auto-playing mood-matched playlists, a persistent mini-player bar, a full-screen music page, and Rocky voice command control.

**Architecture:** Unified `MusicService` abstract interface backed by `LocalMusicService` (just_audio). A single `MusicPlayerNotifier` (Riverpod `Notifier`) owns all playback state. Mood playlist logic, voice commands, and the mini-player all read from this one provider. A new `AppShell` widget wraps authenticated routes via `ShellRoute` in go_router to keep the mini-player visible across all screens.

**Tech Stack:** Flutter, Riverpod (plain providers, no code-gen), just_audio (already in pubspec), go_router (ShellRoute), shared_preferences (already in pubspec), speech_to_text (already in pubspec for voice commands).

---

## Scope note

This plan covers the core music system (local library + mood playlists + mini-player + full-screen page + voice commands). Spotify SDK integration is Plan 6b and is fully independent of this plan.

---

## File Structure

```
lib/features/music/
├── domain/
│   ├── mood_category.dart          — MoodCategory enum (calm/neutral/energized)
│   ├── music_source.dart           — MusicSource enum (local/spotify)
│   ├── music_track.dart            — MusicTrack entity
│   ├── music_playlist.dart         — MusicPlaylist entity
│   ├── music_service.dart          — abstract MusicService interface
│   └── music_repository.dart       — abstract MusicRepository interface
├── data/
│   ├── music_manifest.dart         — Dart const List<MusicTrack> (9 bundled tracks)
│   ├── local_music_service.dart    — MusicService impl via just_audio
│   └── local_music_repository.dart — MusicRepository impl reading manifest
└── presentation/
    ├── providers/
    │   ├── music_player_notifier.dart  — MusicPlayerState + MusicPlayerNotifier
    │   └── music_providers.dart        — musicServiceProvider, localMusicRepositoryProvider,
    │                                     moodPlaylistProvider
    ├── pages/
    │   └── music_page.dart            — full-screen player
    └── widgets/
        └── mini_player_widget.dart    — slim bar shown above bottom of AppShell

lib/shared/widgets/
└── app_shell.dart                  — ShellRoute scaffold wrapping child + MiniPlayerWidget

lib/router/
└── app_router.dart                 — MODIFY: add ShellRoute + /music route

lib/voice/
└── voice_provider.dart             — MODIFY: intercept music commands in _handleTranscript

lib/features/chat/presentation/providers/
└── chat_provider.dart              — MODIFY: add proactive music suggestion hint

pubspec.yaml                        — MODIFY: register assets/music/ directory
assets/music/calm/                  — 3 royalty-free MP3 tracks
assets/music/neutral/               — 3 royalty-free MP3 tracks
assets/music/energized/             — 3 royalty-free MP3 tracks

test/features/music/
├── music_track_test.dart
├── local_music_repository_test.dart
├── music_player_notifier_test.dart
├── mood_playlist_provider_test.dart
├── mini_player_widget_test.dart
└── music_command_test.dart
```

---

## Task 1: Domain Enums and Entities

**Files:**
- Create: `lib/features/music/domain/mood_category.dart`
- Create: `lib/features/music/domain/music_source.dart`
- Create: `lib/features/music/domain/music_track.dart`
- Create: `lib/features/music/domain/music_playlist.dart`
- Test: `test/features/music/music_track_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/music/music_track_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_source.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';

void main() {
  group('MoodCategory', () {
    test('has three values', () {
      expect(MoodCategory.values.length, 3);
      expect(MoodCategory.values, containsAll([
        MoodCategory.calm,
        MoodCategory.neutral,
        MoodCategory.energized,
      ]));
    });
  });

  group('MusicSource', () {
    test('has two values', () {
      expect(MusicSource.values.length, 2);
      expect(MusicSource.values, containsAll([
        MusicSource.local,
        MusicSource.spotify,
      ]));
    });
  });

  group('MusicTrack', () {
    const track = MusicTrack(
      id: 'calm_01',
      title: 'Rain on Leaves',
      artist: 'Ambient Studio',
      duration: Duration(minutes: 3, seconds: 42),
      moodCategory: MoodCategory.calm,
      assetPath: 'assets/music/calm/rain_on_leaves.mp3',
    );

    test('holds all fields', () {
      expect(track.id, 'calm_01');
      expect(track.title, 'Rain on Leaves');
      expect(track.artist, 'Ambient Studio');
      expect(track.duration, const Duration(minutes: 3, seconds: 42));
      expect(track.moodCategory, MoodCategory.calm);
      expect(track.assetPath, 'assets/music/calm/rain_on_leaves.mp3');
      expect(track.spotifyUri, isNull);
    });

    test('equality by id', () {
      const same = MusicTrack(
        id: 'calm_01',
        title: 'Different Title',
        artist: 'Different Artist',
        duration: Duration(seconds: 10),
        moodCategory: MoodCategory.neutral,
      );
      expect(track, equals(same));
    });
  });

  group('MusicPlaylist', () {
    const track = MusicTrack(
      id: 'calm_01',
      title: 'Rain on Leaves',
      artist: 'Ambient Studio',
      duration: Duration(minutes: 3),
      moodCategory: MoodCategory.calm,
      assetPath: 'assets/music/calm/rain_on_leaves.mp3',
    );

    test('holds mood category and tracks', () {
      const playlist = MusicPlaylist(
        moodCategory: MoodCategory.calm,
        tracks: [track],
      );
      expect(playlist.moodCategory, MoodCategory.calm);
      expect(playlist.tracks, [track]);
    });

    test('isEmpty is true when no tracks', () {
      const playlist = MusicPlaylist(
        moodCategory: MoodCategory.calm,
        tracks: [],
      );
      expect(playlist.isEmpty, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/nivara && flutter test test/features/music/music_track_test.dart
```
Expected: FAIL — target files not found.

- [ ] **Step 3: Create `lib/features/music/domain/mood_category.dart`**

```dart
enum MoodCategory { calm, neutral, energized }
```

- [ ] **Step 4: Create `lib/features/music/domain/music_source.dart`**

```dart
enum MusicSource { local, spotify }
```

- [ ] **Step 5: Create `lib/features/music/domain/music_track.dart`**

```dart
import 'mood_category.dart';

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.moodCategory,
    this.assetPath,
    this.spotifyUri,
  });

  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final MoodCategory moodCategory;

  /// Relative asset path for bundled tracks, e.g. 'assets/music/calm/track.mp3'.
  /// Null for Spotify-only tracks.
  final String? assetPath;

  /// Spotify track URI, e.g. 'spotify:track:abc123'.
  /// Null for local-only tracks.
  final String? spotifyUri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MusicTrack && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 6: Create `lib/features/music/domain/music_playlist.dart`**

```dart
import 'mood_category.dart';
import 'music_track.dart';

class MusicPlaylist {
  const MusicPlaylist({
    required this.moodCategory,
    required this.tracks,
  });

  final MoodCategory moodCategory;
  final List<MusicTrack> tracks;

  bool get isEmpty => tracks.isEmpty;
}
```

- [ ] **Step 7: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/music/music_track_test.dart
```
Expected: All 5 tests pass.

- [ ] **Step 8: Commit**

```bash
cd ~/nivara && git add lib/features/music/domain/ test/features/music/music_track_test.dart
git commit -m "feat(music): add domain entities — MusicTrack, MusicPlaylist, MoodCategory, MusicSource"
```

---

## Task 2: Abstract Interfaces

**Files:**
- Create: `lib/features/music/domain/music_service.dart`
- Create: `lib/features/music/domain/music_repository.dart`

No tests for pure abstract classes — behaviour is tested via concrete implementations in Tasks 3 and 4.

- [ ] **Step 1: Create `lib/features/music/domain/music_service.dart`**

```dart
import 'music_track.dart';

/// Playback contract implemented by LocalMusicService and SpotifyMusicService.
/// skip() is intentionally omitted — skip logic (which track is next) lives
/// in MusicPlayerNotifier which owns the playlist state.
abstract class MusicService {
  Future<void> play(MusicTrack track);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seekTo(Duration position);
  Future<void> dispose();
}
```

- [ ] **Step 2: Create `lib/features/music/domain/music_repository.dart`**

```dart
import 'mood_category.dart';
import 'music_playlist.dart';
import 'music_track.dart';

abstract class MusicRepository {
  MusicPlaylist getPlaylistForMood(MoodCategory category);
  List<MusicTrack> getAllTracks();
}
```

- [ ] **Step 3: Commit**

```bash
cd ~/nivara && git add lib/features/music/domain/music_service.dart lib/features/music/domain/music_repository.dart
git commit -m "feat(music): add abstract MusicService and MusicRepository interfaces"
```

---

## Task 3: Music Manifest

**Files:**
- Create: `lib/features/music/data/music_manifest.dart`
- Modify: `pubspec.yaml` (assets/music/ registration)

No tests — this is a pure Dart const. Correctness is validated by the repository tests in Task 4.

**Before coding:** Source 9 royalty-free MP3/OGG tracks (3 per mood category) from [Free Music Archive](https://freemusicarchive.org) or [ccmixter](https://ccmixter.org). Place them at:
```
assets/music/calm/gentle_rain.mp3
assets/music/calm/morning_mist.mp3
assets/music/calm/still_water.mp3
assets/music/neutral/coffee_house.mp3
assets/music/neutral/afternoon_drift.mp3
assets/music/neutral/soft_focus.mp3
assets/music/energized/forward_motion.mp3
assets/music/energized/bright_start.mp3
assets/music/energized/clear_sky.mp3
```

- [ ] **Step 1: Create the asset directories and add placeholder files (for CI)**

```bash
cd ~/nivara
mkdir -p assets/music/calm assets/music/neutral assets/music/energized
# Place real audio files at the paths above.
# For CI/testing, a 1-second silent MP3 works:
# ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -q:a 9 -acodec libmp3lame silent.mp3
# cp silent.mp3 assets/music/calm/gentle_rain.mp3  (repeat for all 9)
```

- [ ] **Step 2: Register assets in `pubspec.yaml`**

Open `pubspec.yaml`. Under `flutter:`, add the music asset directories. Find the existing `assets:` section (or add one under `flutter:`):

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/music/calm/
    - assets/music/neutral/
    - assets/music/energized/
```

- [ ] **Step 3: Create `lib/features/music/data/music_manifest.dart`**

```dart
import '../domain/mood_category.dart';
import '../domain/music_track.dart';

/// Bundled royalty-free track catalogue.
/// Update assetPath values to match files placed under assets/music/.
const List<MusicTrack> kMusicManifest = [
  // ── Calm ─────────────────────────────────────────────────────────────────
  MusicTrack(
    id: 'calm_01',
    title: 'Gentle Rain',
    artist: 'Ambient Studio',
    duration: Duration(minutes: 3, seconds: 42),
    moodCategory: MoodCategory.calm,
    assetPath: 'assets/music/calm/gentle_rain.mp3',
  ),
  MusicTrack(
    id: 'calm_02',
    title: 'Morning Mist',
    artist: 'Ambient Studio',
    duration: Duration(minutes: 4, seconds: 10),
    moodCategory: MoodCategory.calm,
    assetPath: 'assets/music/calm/morning_mist.mp3',
  ),
  MusicTrack(
    id: 'calm_03',
    title: 'Still Water',
    artist: 'Ambient Studio',
    duration: Duration(minutes: 3, seconds: 55),
    moodCategory: MoodCategory.calm,
    assetPath: 'assets/music/calm/still_water.mp3',
  ),
  // ── Neutral ───────────────────────────────────────────────────────────────
  MusicTrack(
    id: 'neutral_01',
    title: 'Coffee House',
    artist: 'Lo-Fi Collective',
    duration: Duration(minutes: 3, seconds: 20),
    moodCategory: MoodCategory.neutral,
    assetPath: 'assets/music/neutral/coffee_house.mp3',
  ),
  MusicTrack(
    id: 'neutral_02',
    title: 'Afternoon Drift',
    artist: 'Lo-Fi Collective',
    duration: Duration(minutes: 3, seconds: 48),
    moodCategory: MoodCategory.neutral,
    assetPath: 'assets/music/neutral/afternoon_drift.mp3',
  ),
  MusicTrack(
    id: 'neutral_03',
    title: 'Soft Focus',
    artist: 'Lo-Fi Collective',
    duration: Duration(minutes: 4, seconds: 02),
    moodCategory: MoodCategory.neutral,
    assetPath: 'assets/music/neutral/soft_focus.mp3',
  ),
  // ── Energized ─────────────────────────────────────────────────────────────
  MusicTrack(
    id: 'energized_01',
    title: 'Forward Motion',
    artist: 'Beat Workshop',
    duration: Duration(minutes: 3, seconds: 15),
    moodCategory: MoodCategory.energized,
    assetPath: 'assets/music/energized/forward_motion.mp3',
  ),
  MusicTrack(
    id: 'energized_02',
    title: 'Bright Start',
    artist: 'Beat Workshop',
    duration: Duration(minutes: 3, seconds: 30),
    moodCategory: MoodCategory.energized,
    assetPath: 'assets/music/energized/bright_start.mp3',
  ),
  MusicTrack(
    id: 'energized_03',
    title: 'Clear Sky',
    artist: 'Beat Workshop',
    duration: Duration(minutes: 3, seconds: 58),
    moodCategory: MoodCategory.energized,
    assetPath: 'assets/music/energized/clear_sky.mp3',
  ),
];
```

- [ ] **Step 4: Verify pubspec parses correctly**

```bash
cd ~/nivara && flutter pub get
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
cd ~/nivara && git add pubspec.yaml lib/features/music/data/music_manifest.dart assets/music/
git commit -m "feat(music): add music manifest and register assets"
```

---

## Task 4: LocalMusicService

**Files:**
- Create: `lib/features/music/data/local_music_service.dart`
- Test: `test/features/music/local_music_service_test.dart`

The service uses `just_audio`'s `AudioPlayer`. Tests mock the player using a fake to avoid real audio in CI.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/music/local_music_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nivara/features/music/data/local_music_service.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_track.dart';

@GenerateMocks([AudioPlayer])
import 'local_music_service_test.mocks.dart';

const _calmTrack = MusicTrack(
  id: 'calm_01',
  title: 'Gentle Rain',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 3),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/gentle_rain.mp3',
);

void main() {
  late MockAudioPlayer mockPlayer;
  late LocalMusicService service;

  setUp(() {
    mockPlayer = MockAudioPlayer();
    service = LocalMusicService.withPlayer(mockPlayer);
    when(mockPlayer.stop()).thenAnswer((_) async {});
    when(mockPlayer.setAsset(any)).thenAnswer((_) async => null);
    when(mockPlayer.play()).thenAnswer((_) async {});
    when(mockPlayer.pause()).thenAnswer((_) async {});
    when(mockPlayer.seek(any)).thenAnswer((_) async {});
    when(mockPlayer.dispose()).thenAnswer((_) async {});
  });

  test('play stops previous, sets asset, and starts playback', () async {
    await service.play(_calmTrack);
    verifyInOrder([
      mockPlayer.stop(),
      mockPlayer.setAsset('assets/music/calm/gentle_rain.mp3'),
      mockPlayer.play(),
    ]);
  });

  test('pause calls player.pause', () async {
    await service.pause();
    verify(mockPlayer.pause()).called(1);
  });

  test('resume calls player.play', () async {
    await service.resume();
    verify(mockPlayer.play()).called(1);
  });

  test('stop calls player.stop', () async {
    await service.stop();
    verify(mockPlayer.stop()).called(1);
  });

  test('seekTo calls player.seek', () async {
    const pos = Duration(seconds: 30);
    await service.seekTo(pos);
    verify(mockPlayer.seek(pos)).called(1);
  });

  test('dispose calls player.dispose', () async {
    await service.dispose();
    verify(mockPlayer.dispose()).called(1);
  });

  test('play throws ArgumentError when assetPath is null', () async {
    const noPath = MusicTrack(
      id: 'x',
      title: 'X',
      artist: 'X',
      duration: Duration(seconds: 1),
      moodCategory: MoodCategory.calm,
    );
    expect(() => service.play(noPath), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
cd ~/nivara && flutter pub run build_runner build --delete-conflicting-outputs
```
Expected: generates `test/features/music/local_music_service_test.mocks.dart`.

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd ~/nivara && flutter test test/features/music/local_music_service_test.dart
```
Expected: FAIL — `LocalMusicService` not found.

- [ ] **Step 4: Create `lib/features/music/data/local_music_service.dart`**

```dart
import 'package:just_audio/just_audio.dart';

import '../domain/music_service.dart';
import '../domain/music_track.dart';

class LocalMusicService implements MusicService {
  LocalMusicService() : _player = AudioPlayer();

  /// Test-only constructor that accepts a pre-built AudioPlayer.
  LocalMusicService.withPlayer(this._player);

  final AudioPlayer _player;

  @override
  Future<void> play(MusicTrack track) async {
    final path = track.assetPath;
    if (path == null) {
      throw ArgumentError(
        'MusicTrack "${track.id}" has no assetPath — cannot play locally.',
      );
    }
    await _player.stop();
    await _player.setAsset(path);
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
```

- [ ] **Step 5: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/music/local_music_service_test.dart
```
Expected: All 7 tests pass.

- [ ] **Step 6: Commit**

```bash
cd ~/nivara && git add lib/features/music/data/local_music_service.dart test/features/music/
git commit -m "feat(music): implement LocalMusicService with just_audio"
```

---

## Task 5: LocalMusicRepository

**Files:**
- Create: `lib/features/music/data/local_music_repository.dart`
- Test: `test/features/music/local_music_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/music/local_music_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/music/data/local_music_repository.dart';
import 'package:nivara/features/music/data/music_manifest.dart';
import 'package:nivara/features/music/domain/mood_category.dart';

void main() {
  late LocalMusicRepository repo;

  setUp(() => repo = LocalMusicRepository());

  test('getPlaylistForMood(calm) returns only calm tracks', () {
    final playlist = repo.getPlaylistForMood(MoodCategory.calm);
    expect(playlist.moodCategory, MoodCategory.calm);
    expect(playlist.tracks, isNotEmpty);
    for (final t in playlist.tracks) {
      expect(t.moodCategory, MoodCategory.calm);
    }
  });

  test('getPlaylistForMood(neutral) returns only neutral tracks', () {
    final playlist = repo.getPlaylistForMood(MoodCategory.neutral);
    expect(playlist.moodCategory, MoodCategory.neutral);
    expect(playlist.tracks, isNotEmpty);
    for (final t in playlist.tracks) {
      expect(t.moodCategory, MoodCategory.neutral);
    }
  });

  test('getPlaylistForMood(energized) returns only energized tracks', () {
    final playlist = repo.getPlaylistForMood(MoodCategory.energized);
    expect(playlist.moodCategory, MoodCategory.energized);
    expect(playlist.tracks, isNotEmpty);
    for (final t in playlist.tracks) {
      expect(t.moodCategory, MoodCategory.energized);
    }
  });

  test('getAllTracks returns all 9 manifest tracks', () {
    final all = repo.getAllTracks();
    expect(all.length, kMusicManifest.length);
    expect(all, equals(kMusicManifest));
  });

  test('each mood category has at least 3 tracks', () {
    for (final cat in MoodCategory.values) {
      final playlist = repo.getPlaylistForMood(cat);
      expect(
        playlist.tracks.length,
        greaterThanOrEqualTo(3),
        reason: '${cat.name} should have at least 3 tracks',
      );
    }
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/nivara && flutter test test/features/music/local_music_repository_test.dart
```
Expected: FAIL — `LocalMusicRepository` not found.

- [ ] **Step 3: Create `lib/features/music/data/local_music_repository.dart`**

```dart
import '../domain/mood_category.dart';
import '../domain/music_playlist.dart';
import '../domain/music_repository.dart';
import '../domain/music_track.dart';
import 'music_manifest.dart';

class LocalMusicRepository implements MusicRepository {
  @override
  MusicPlaylist getPlaylistForMood(MoodCategory category) {
    final tracks = kMusicManifest
        .where((t) => t.moodCategory == category)
        .toList();
    return MusicPlaylist(moodCategory: category, tracks: tracks);
  }

  @override
  List<MusicTrack> getAllTracks() => List.unmodifiable(kMusicManifest);
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/music/local_music_repository_test.dart
```
Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
cd ~/nivara && git add lib/features/music/data/local_music_repository.dart test/features/music/local_music_repository_test.dart
git commit -m "feat(music): implement LocalMusicRepository from manifest"
```

---

## Task 6: MusicPlayerNotifier

**Files:**
- Create: `lib/features/music/presentation/providers/music_player_notifier.dart`
- Test: `test/features/music/music_player_notifier_test.dart`

`MusicPlayerNotifier` owns all playback state. It reads `musicServiceProvider` and `moodPlaylistProvider` through `ref`. `isMoodAutoPlay` is persisted to SharedPreferences.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/music/music_player_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_service.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';

@GenerateMocks([MusicService])
import 'music_player_notifier_test.mocks.dart';

const _track = MusicTrack(
  id: 'calm_01',
  title: 'Gentle Rain',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 3),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/gentle_rain.mp3',
);

const _track2 = MusicTrack(
  id: 'calm_02',
  title: 'Morning Mist',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 4),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/morning_mist.mp3',
);

const _calmPlaylist = MusicPlaylist(
  moodCategory: MoodCategory.calm,
  tracks: [_track, _track2],
);

ProviderContainer _makeContainer(MockMusicService svc, {MusicPlaylist? playlist}) {
  return ProviderContainer(overrides: [
    musicServiceProvider.overrideWithValue(svc),
    moodPlaylistProvider.overrideWith(
      (ref) async => playlist,
    ),
  ]);
}

void main() {
  late MockMusicService mockService;

  setUp(() {
    mockService = MockMusicService();
    when(mockService.play(any)).thenAnswer((_) async {});
    when(mockService.pause()).thenAnswer((_) async {});
    when(mockService.resume()).thenAnswer((_) async {});
    when(mockService.stop()).thenAnswer((_) async {});
    when(mockService.dispose()).thenAnswer((_) async {});
  });

  test('initial state has no track and is not playing', () {
    final container = _makeContainer(mockService);
    addTearDown(container.dispose);
    final state = container.read(musicPlayerNotifierProvider);
    expect(state.isPlaying, isFalse);
    expect(state.currentTrack, isNull);
    expect(state.isMoodAutoPlay, isTrue);
  });

  test('play sets isPlaying=true and currentTrack', () async {
    final container = _makeContainer(mockService);
    addTearDown(container.dispose);
    await container.read(musicPlayerNotifierProvider.notifier).play(_track);
    final state = container.read(musicPlayerNotifierProvider);
    expect(state.isPlaying, isTrue);
    expect(state.currentTrack, equals(_track));
    verify(mockService.play(_track)).called(1);
  });

  test('pause sets isPlaying=false', () async {
    final container = _makeContainer(mockService);
    addTearDown(container.dispose);
    await container.read(musicPlayerNotifierProvider.notifier).play(_track);
    await container.read(musicPlayerNotifierProvider.notifier).pause();
    expect(container.read(musicPlayerNotifierProvider).isPlaying, isFalse);
    verify(mockService.pause()).called(1);
  });

  test('resume sets isPlaying=true', () async {
    final container = _makeContainer(mockService);
    addTearDown(container.dispose);
    await container.read(musicPlayerNotifierProvider.notifier).play(_track);
    await container.read(musicPlayerNotifierProvider.notifier).pause();
    await container.read(musicPlayerNotifierProvider.notifier).resume();
    expect(container.read(musicPlayerNotifierProvider).isPlaying, isTrue);
    verify(mockService.resume()).called(1);
  });

  test('skip advances to next track and wraps at end', () async {
    final container = _makeContainer(mockService, playlist: _calmPlaylist);
    addTearDown(container.dispose);
    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    await notifier.play(_track);
    // set playlist state so skip knows what track is next
    await notifier.setPlaylist(_calmPlaylist, startIndex: 0);
    await notifier.skip();
    expect(container.read(musicPlayerNotifierProvider).currentTrack, equals(_track2));
    // skip again — wraps to index 0
    await notifier.skip();
    expect(container.read(musicPlayerNotifierProvider).currentTrack, equals(_track));
  });

  test('stop clears currentTrack and sets isPlaying=false', () async {
    final container = _makeContainer(mockService);
    addTearDown(container.dispose);
    await container.read(musicPlayerNotifierProvider.notifier).play(_track);
    await container.read(musicPlayerNotifierProvider.notifier).stop();
    final state = container.read(musicPlayerNotifierProvider);
    expect(state.isPlaying, isFalse);
    expect(state.currentTrack, isNull);
    verify(mockService.stop()).called(1);
  });

  test('autoPlayForMood does nothing when isMoodAutoPlay is false', () async {
    final container = _makeContainer(mockService, playlist: _calmPlaylist);
    addTearDown(container.dispose);
    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    notifier.setMoodAutoPlay(enabled: false);
    await notifier.autoPlayForMood();
    verifyNever(mockService.play(any));
  });

  test('autoPlayForMood does nothing when already playing', () async {
    final container = _makeContainer(mockService, playlist: _calmPlaylist);
    addTearDown(container.dispose);
    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    await notifier.play(_track);
    await notifier.autoPlayForMood();
    // play was called once (explicit), not a second time via autoPlay
    verify(mockService.play(any)).called(1);
  });

  test('autoPlayForMood plays first track of mood playlist', () async {
    final container = _makeContainer(mockService, playlist: _calmPlaylist);
    addTearDown(container.dispose);
    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    await notifier.autoPlayForMood();
    expect(container.read(musicPlayerNotifierProvider).currentTrack, equals(_track));
    verify(mockService.play(_track)).called(1);
  });

  test('autoPlayForMood does nothing when playlist is null', () async {
    final container = _makeContainer(mockService);
    addTearDown(container.dispose);
    await container.read(musicPlayerNotifierProvider.notifier).autoPlayForMood();
    verifyNever(mockService.play(any));
  });
}
```

- [ ] **Step 2: Run build_runner to update mocks**

```bash
cd ~/nivara && flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd ~/nivara && flutter test test/features/music/music_player_notifier_test.dart
```
Expected: FAIL — provider files not found.

- [ ] **Step 4: Create `lib/features/music/presentation/providers/music_player_notifier.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/mood_category.dart';
import '../../domain/music_playlist.dart';
import '../../domain/music_track.dart';
import 'music_providers.dart';

// ── State ────────────────────────────────────────────────────────────────────

class MusicPlayerState {
  const MusicPlayerState({
    required this.isPlaying,
    required this.currentTrack,
    required this.playlist,
    required this.currentIndex,
    required this.isMoodAutoPlay,
  });

  final bool isPlaying;
  final MusicTrack? currentTrack;
  final MusicPlaylist? playlist;
  final int currentIndex;
  final bool isMoodAutoPlay;

  static const _sentinel = Object();

  MusicPlayerState copyWith({
    bool? isPlaying,
    Object? currentTrack = _sentinel,
    Object? playlist = _sentinel,
    int? currentIndex,
    bool? isMoodAutoPlay,
  }) {
    return MusicPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentTrack: currentTrack == _sentinel
          ? this.currentTrack
          : currentTrack as MusicTrack?,
      playlist: playlist == _sentinel
          ? this.playlist
          : playlist as MusicPlaylist?,
      currentIndex: currentIndex ?? this.currentIndex,
      isMoodAutoPlay: isMoodAutoPlay ?? this.isMoodAutoPlay,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class MusicPlayerNotifier extends Notifier<MusicPlayerState> {
  @override
  MusicPlayerState build() {
    ref.onDispose(() async {
      try {
        await ref.read(musicServiceProvider).dispose();
      } catch (_) {}
    });
    return const MusicPlayerState(
      isPlaying: false,
      currentTrack: null,
      playlist: null,
      currentIndex: 0,
      isMoodAutoPlay: true,
    );
  }

  Future<void> play(MusicTrack track) async {
    await ref.read(musicServiceProvider).play(track);
    state = state.copyWith(isPlaying: true, currentTrack: track);
  }

  Future<void> pause() async {
    await ref.read(musicServiceProvider).pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    if (state.currentTrack == null) return;
    await ref.read(musicServiceProvider).resume();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> stop() async {
    await ref.read(musicServiceProvider).stop();
    state = state.copyWith(
      isPlaying: false,
      currentTrack: null,
    );
  }

  /// Sets the active playlist and starts playback from [startIndex].
  Future<void> setPlaylist(MusicPlaylist playlist, {int startIndex = 0}) async {
    state = state.copyWith(playlist: playlist, currentIndex: startIndex);
    await play(playlist.tracks[startIndex]);
  }

  Future<void> skip() async {
    final playlist = state.playlist;
    if (playlist == null || playlist.isEmpty) return;
    final nextIndex = (state.currentIndex + 1) % playlist.tracks.length;
    state = state.copyWith(currentIndex: nextIndex);
    await play(playlist.tracks[nextIndex]);
  }

  Future<void> autoPlayForMood() async {
    if (!state.isMoodAutoPlay) return;
    if (state.isPlaying) return;
    try {
      final playlist = await ref.read(moodPlaylistProvider.future);
      if (playlist == null || playlist.isEmpty) return;
      await setPlaylist(playlist);
    } catch (_) {
      // Non-critical — auto-play failure must not crash the app.
    }
  }

  Future<void> playForCategory(MoodCategory category) async {
    final repo = ref.read(localMusicRepositoryProvider);
    final playlist = repo.getPlaylistForMood(category);
    if (playlist.isEmpty) return;
    await setPlaylist(playlist);
  }

  void setMoodAutoPlay({required bool enabled}) {
    state = state.copyWith(isMoodAutoPlay: enabled);
    _persistMoodAutoPlay(enabled);
  }

  Future<void> _persistMoodAutoPlay(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_mood_autoplay', value);
    } catch (_) {
      // Persistence failure is non-critical.
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final musicPlayerNotifierProvider =
    NotifierProvider<MusicPlayerNotifier, MusicPlayerState>(
  MusicPlayerNotifier.new,
);
```

- [ ] **Step 5: Create `lib/features/music/presentation/providers/music_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local_music_repository.dart';
import '../../data/local_music_service.dart';
import '../../domain/mood_category.dart';
import '../../domain/music_playlist.dart';
import '../../domain/music_repository.dart';
import '../../domain/music_service.dart';
import '../../../../features/mood/domain/mood_entry.dart';
import '../../../../features/mood/presentation/providers/mood_provider.dart';

final localMusicRepositoryProvider = Provider<MusicRepository>(
  (_) => LocalMusicRepository(),
);

final musicServiceProvider = Provider<MusicService>(
  (_) => LocalMusicService(),
);

/// Reads the 7-day mood average and returns the matching playlist.
/// Returns null when there is insufficient mood history or an error occurs.
final moodPlaylistProvider = FutureProvider<MusicPlaylist?>((ref) async {
  try {
    final entries = await ref.watch(weekMoodProvider.future);
    final scores = entries
        .whereType<MoodEntry>()
        .map((e) => e.score)
        .toList();
    if (scores.isEmpty) return null;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final category = avg <= 2.0
        ? MoodCategory.calm
        : avg < 3.0
            ? MoodCategory.neutral
            : MoodCategory.energized;
    final repo = ref.read(localMusicRepositoryProvider);
    return repo.getPlaylistForMood(category);
  } catch (_) {
    return null;
  }
});
```

- [ ] **Step 6: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/music/music_player_notifier_test.dart
```
Expected: All 9 tests pass.

- [ ] **Step 7: Commit**

```bash
cd ~/nivara && git add lib/features/music/presentation/providers/ test/features/music/music_player_notifier_test.dart
git commit -m "feat(music): add MusicPlayerNotifier, MusicPlayerState, and music providers"
```

---

## Task 7: moodPlaylistProvider tests

**Files:**
- Test: `test/features/music/mood_playlist_provider_test.dart`

The provider itself was written in Task 6. These tests verify the threshold logic independently.

- [ ] **Step 1: Write the tests**

```dart
// test/features/music/mood_playlist_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';

List<MoodEntry?> _entries(List<int> scores) => scores
    .map((s) => MoodEntry(
          date: DateTime(2026, 5, 1),
          score: s,
          label: 'test',
          source: MoodSource.checkin,
        ))
    .toList();

ProviderContainer _container(List<MoodEntry?> entries) {
  return ProviderContainer(overrides: [
    weekMoodProvider.overrideWith((ref) async => entries),
  ]);
}

void main() {
  test('returns calm playlist when avg <= 2.0', () async {
    final c = _container(_entries([1, 2, 1, 2, 2]));
    addTearDown(c.dispose);
    final playlist = await c.read(moodPlaylistProvider.future);
    expect(playlist?.moodCategory, MoodCategory.calm);
  });

  test('returns neutral playlist when avg is 2.1–2.9', () async {
    final c = _container(_entries([2, 3, 2, 3, 2]));
    addTearDown(c.dispose);
    final playlist = await c.read(moodPlaylistProvider.future);
    expect(playlist?.moodCategory, MoodCategory.neutral);
  });

  test('returns energized playlist when avg >= 3.0', () async {
    final c = _container(_entries([3, 4, 5, 4, 3]));
    addTearDown(c.dispose);
    final playlist = await c.read(moodPlaylistProvider.future);
    expect(playlist?.moodCategory, MoodCategory.energized);
  });

  test('returns null when mood history is empty', () async {
    final c = _container([]);
    addTearDown(c.dispose);
    final playlist = await c.read(moodPlaylistProvider.future);
    expect(playlist, isNull);
  });

  test('returns null when weekMoodProvider throws', () async {
    final c = ProviderContainer(overrides: [
      weekMoodProvider.overrideWith((ref) async => throw Exception('db error')),
    ]);
    addTearDown(c.dispose);
    final playlist = await c.read(moodPlaylistProvider.future);
    expect(playlist, isNull);
  });

  test('exactly 2.0 average returns calm (not neutral)', () async {
    final c = _container(_entries([2, 2]));
    addTearDown(c.dispose);
    final playlist = await c.read(moodPlaylistProvider.future);
    expect(playlist?.moodCategory, MoodCategory.calm);
  });

  test('exactly 3.0 average returns energized', () async {
    final c = _container(_entries([3, 3]));
    addTearDown(c.dispose);
    final playlist = await c.read(moodPlaylistProvider.future);
    expect(playlist?.moodCategory, MoodCategory.energized);
  });
}
```

- [ ] **Step 2: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/music/mood_playlist_provider_test.dart
```
Expected: All 7 tests pass.

- [ ] **Step 3: Commit**

```bash
cd ~/nivara && git add test/features/music/mood_playlist_provider_test.dart
git commit -m "test(music): add moodPlaylistProvider threshold tests"
```

---

## Task 8: AppShell + ShellRoute Navigation

**Files:**
- Create: `lib/shared/widgets/app_shell.dart`
- Modify: `lib/router/app_router.dart`

AppShell wraps the route's child with a Scaffold that renders `MiniPlayerWidget` in its `bottomNavigationBar` slot. ShellRoute wraps the five main authenticated routes.

- [ ] **Step 1: Create `lib/shared/widgets/app_shell.dart`**

```dart
import 'package:flutter/material.dart';

import '../../features/music/presentation/widgets/mini_player_widget.dart';

/// Persistent scaffold shown across all authenticated main routes.
/// Renders the music mini-player at the bottom of every screen.
class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      // MiniPlayerWidget returns SizedBox.shrink() when no track is playing,
      // so this slot has zero height when music is idle.
      bottomNavigationBar: const MiniPlayerWidget(),
    );
  }
}
```

Note: `MiniPlayerWidget` is created in Task 9. You will get a compile error here until Task 9 is complete — proceed in order.

- [ ] **Step 2: Modify `lib/router/app_router.dart`**

Replace the full file content with:

```dart
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/pages/sign_in_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/memory/presentation/pages/memory_page.dart';
import '../features/music/presentation/pages/music_page.dart';
import '../features/planner/presentation/pages/calendar_consent_page.dart';
import '../features/planner/presentation/pages/planner_page.dart';
import '../features/planner/data/google_calendar_repository.dart';
import '../features/mood/presentation/pages/mood_board_page.dart';
import '../features/profile/presentation/pages/assistant_setup_page.dart';
import '../features/profile/presentation/pages/profile_setup_page.dart';
import '../shared/widgets/app_shell.dart';
import '../voice/voice_settings_page.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final isSignedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/sign-in';

      if (!isSignedIn && !isAuthRoute) return '/welcome';
      if (isSignedIn && isAuthRoute) return '/chat';
      return null;
    },
    routes: [
      // ── Unauthenticated routes (no shell, no mini-player) ──────────────────
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupPage(),
      ),
      GoRoute(
        path: '/assistant-setup',
        builder: (context, state) => const AssistantSetupPage(),
      ),
      // ── Sub-pages that break out of the shell ─────────────────────────────
      GoRoute(
        path: '/settings/voice',
        builder: (context, state) => const VoiceSettingsPage(),
      ),
      GoRoute(
        path: '/planner/calendar-consent',
        builder: (context, state) {
          final gcalRepo = ref.read(googleCalendarRepositoryProvider);
          return CalendarConsentPage(
            onAllow: () async {
              await gcalRepo.requestAccess();
              // ignore: use_build_context_synchronously
              if (context.mounted && context.canPop()) context.pop();
            },
            onSkip: () {
              if (context.canPop()) context.pop();
            },
          );
        },
      ),
      // ── Main authenticated shell (mini-player always visible) ──────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, state) => const ChatPage(),
          ),
          GoRoute(
            path: '/music',
            builder: (context, state) => const MusicPage(),
          ),
          GoRoute(
            path: '/planner',
            builder: (context, state) => const PlannerPage(),
          ),
          GoRoute(
            path: '/memory',
            builder: (context, state) => const MemoryPage(),
          ),
          GoRoute(
            path: '/mood',
            builder: (context, state) => const MoodBoardPage(),
          ),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 3: Verify app still compiles (ignoring missing MusicPage/MiniPlayerWidget for now)**

```bash
cd ~/nivara && flutter analyze lib/router/
```
Expected: errors only about missing `MusicPage` and `MiniPlayerWidget` — these are resolved in Tasks 9 and 10.

- [ ] **Step 4: Commit**

```bash
cd ~/nivara && git add lib/shared/widgets/app_shell.dart lib/router/app_router.dart
git commit -m "feat(music): add AppShell with ShellRoute — mini-player persists across screens"
```

---

## Task 9: MiniPlayerWidget

**Files:**
- Create: `lib/features/music/presentation/widgets/mini_player_widget.dart`
- Test: `test/features/music/mini_player_widget_test.dart`

The mini-player is a slim 56 dp bar: album-colour swatch, track title, artist, play/pause button, expand arrow. Hidden (zero height) when no track is playing.

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/features/music/mini_player_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';
import 'package:nivara/features/music/presentation/widgets/mini_player_widget.dart';
import 'package:nivara/features/music/domain/music_service.dart';

@GenerateMocks([MusicService])
import 'mini_player_widget_test.mocks.dart';

const _track = MusicTrack(
  id: 'calm_01',
  title: 'Gentle Rain',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 3),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/gentle_rain.mp3',
);

MusicPlayerState _stateWith({MusicTrack? track, bool isPlaying = false}) {
  return MusicPlayerState(
    isPlaying: isPlaying,
    currentTrack: track,
    playlist: null,
    currentIndex: 0,
    isMoodAutoPlay: true,
  );
}

Widget _wrap(MusicPlayerState initialState, MockMusicService svc) {
  return ProviderScope(
    overrides: [
      musicPlayerNotifierProvider.overrideWith(
        () => _FakeNotifier(initialState),
      ),
      musicServiceProvider.overrideWithValue(svc),
      moodPlaylistProvider.overrideWith((ref) async => null),
    ],
    child: const MaterialApp(home: Scaffold(body: MiniPlayerWidget())),
  );
}

class _FakeNotifier extends MusicPlayerNotifier {
  _FakeNotifier(this._initial);
  final MusicPlayerState _initial;
  @override
  MusicPlayerState build() => _initial;
}

void main() {
  late MockMusicService mockService;
  setUp(() {
    mockService = MockMusicService();
    when(mockService.pause()).thenAnswer((_) async {});
    when(mockService.play(any)).thenAnswer((_) async {});
    when(mockService.resume()).thenAnswer((_) async {});
    when(mockService.dispose()).thenAnswer((_) async {});
  });

  testWidgets('renders nothing when no track is playing', (tester) async {
    await tester.pumpWidget(_wrap(_stateWith(), mockService));
    expect(find.byType(SizedBox), findsWidgets);
    // No track title visible
    expect(find.text('Gentle Rain'), findsNothing);
  });

  testWidgets('shows track title and artist when track is set', (tester) async {
    await tester.pumpWidget(
      _wrap(_stateWith(track: _track, isPlaying: true), mockService),
    );
    expect(find.text('Gentle Rain'), findsOneWidget);
    expect(find.text('Ambient Studio'), findsOneWidget);
  });

  testWidgets('shows pause icon when isPlaying=true', (tester) async {
    await tester.pumpWidget(
      _wrap(_stateWith(track: _track, isPlaying: true), mockService),
    );
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('shows play icon when isPlaying=false and track exists',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_stateWith(track: _track, isPlaying: false), mockService),
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run build_runner**

```bash
cd ~/nivara && flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd ~/nivara && flutter test test/features/music/mini_player_widget_test.dart
```
Expected: FAIL — `MiniPlayerWidget` not found.

- [ ] **Step 4: Create `lib/features/music/presentation/widgets/mini_player_widget.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/music_player_notifier.dart';

class MiniPlayerWidget extends ConsumerWidget {
  const MiniPlayerWidget({super.key});

  static const _height = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerNotifierProvider);
    final track = state.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final notifier = ref.read(musicPlayerNotifierProvider.notifier);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/music'),
      child: Container(
        height: _height,
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Mood-colour swatch acting as album art placeholder
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            // Track info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    track.artist,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Play / pause
            IconButton(
              icon: Icon(
                state.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () async {
                if (state.isPlaying) {
                  await notifier.pause();
                } else {
                  await notifier.resume();
                }
              },
            ),
            // Expand arrow (navigates to full player)
            const Icon(Icons.keyboard_arrow_up),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/music/mini_player_widget_test.dart
```
Expected: All 4 tests pass.

- [ ] **Step 6: Commit**

```bash
cd ~/nivara && git add lib/features/music/presentation/widgets/mini_player_widget.dart test/features/music/mini_player_widget_test.dart
git commit -m "feat(music): add MiniPlayerWidget — slim bar shown above screen bottom"
```

---

## Task 10: MusicPage (Full-Screen Player)

**Files:**
- Create: `lib/features/music/presentation/pages/music_page.dart`

Widget test is lightweight — full interaction is covered by notifier tests. We verify the page mounts without errors and shows key controls.

- [ ] **Step 1: Create `lib/features/music/presentation/pages/music_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/music_player_notifier.dart';

class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  @override
  void initState() {
    super.initState();
    // Trigger mood auto-play when the page opens (if enabled and nothing playing).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(musicPlayerNotifierProvider.notifier).autoPlayForMood();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerNotifierProvider);
    final notifier = ref.read(musicPlayerNotifierProvider.notifier);
    final theme = Theme.of(context);
    final track = state.currentTrack;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music'),
        actions: [
          // Mood auto-play toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mood',
                style: theme.textTheme.bodySmall,
              ),
              Switch(
                value: state.isMoodAutoPlay,
                onChanged: (v) => notifier.setMoodAutoPlay(enabled: v),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Album art placeholder
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.music_note,
                size: 80,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 32),
            // Track info
            if (track != null) ...[
              Text(
                track.title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ] else
              Text(
                'No track playing',
                style: theme.textTheme.bodyLarge,
              ),
            const SizedBox(height: 40),
            // Controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.stop),
                  onPressed: () => notifier.stop(),
                  tooltip: 'Stop',
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: track == null
                      ? null
                      : () async {
                          if (state.isPlaying) {
                            await notifier.pause();
                          } else {
                            await notifier.resume();
                          }
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 64),
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 40,
                  icon: const Icon(Icons.skip_next),
                  onPressed: track == null ? null : () => notifier.skip(),
                  tooltip: 'Skip',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Playlist — shows track list for current mood
            if (state.playlist != null) ...[
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: state.playlist!.tracks.length,
                  itemBuilder: (context, i) {
                    final t = state.playlist!.tracks[i];
                    final isCurrent = t == track;
                    return ListTile(
                      leading: isCurrent
                          ? Icon(Icons.volume_up,
                              color: theme.colorScheme.primary)
                          : const Icon(Icons.music_note),
                      title: Text(
                        t.title,
                        style: isCurrent
                            ? TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                      subtitle: Text(t.artist),
                      onTap: () => notifier.play(t),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify the full app compiles**

```bash
cd ~/nivara && flutter analyze lib/
```
Expected: no errors (only warnings acceptable).

- [ ] **Step 3: Commit**

```bash
cd ~/nivara && git add lib/features/music/presentation/pages/music_page.dart
git commit -m "feat(music): add MusicPage full-screen player with playlist view"
```

---

## Task 11: Voice Command Handler

**Files:**
- Modify: `lib/voice/voice_provider.dart`
- Test: `test/features/music/music_command_test.dart`

Music commands are matched in `_handleTranscript` before the Hermes path. On match, the action fires immediately and Rocky speaks a short acknowledgement.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/music/music_command_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/voice/music_command.dart';

void main() {
  group('matchMusicCommand', () {
    test('play music → MusicCommand.play', () {
      expect(matchMusicCommand('play music'), MusicCommand.play);
      expect(matchMusicCommand('start music'), MusicCommand.play);
      expect(matchMusicCommand('PLAY MUSIC'), MusicCommand.play);
    });

    test('pause / stop music → MusicCommand.pause', () {
      expect(matchMusicCommand('pause'), MusicCommand.pause);
      expect(matchMusicCommand('stop music'), MusicCommand.pause);
    });

    test('resume / continue → MusicCommand.resume', () {
      expect(matchMusicCommand('resume'), MusicCommand.resume);
      expect(matchMusicCommand('continue playing'), MusicCommand.resume);
    });

    test('skip / next song → MusicCommand.skip', () {
      expect(matchMusicCommand('skip'), MusicCommand.skip);
      expect(matchMusicCommand('next song'), MusicCommand.skip);
    });

    test('turn off music → MusicCommand.stop', () {
      expect(matchMusicCommand('turn off music'), MusicCommand.stop);
    });

    test('calmer / relaxing → MusicCommand.playCalmCategory', () {
      expect(matchMusicCommand('play something calmer'), MusicCommand.playCalmCategory);
      expect(matchMusicCommand('something relaxing'), MusicCommand.playCalmCategory);
      expect(matchMusicCommand('calm down'), MusicCommand.playCalmCategory);
    });

    test('upbeat / energize → MusicCommand.playEnergizedCategory', () {
      expect(matchMusicCommand('play something upbeat'), MusicCommand.playEnergizedCategory);
      expect(matchMusicCommand('energize me'), MusicCommand.playEnergizedCategory);
    });

    test('unrecognised utterance returns null', () {
      expect(matchMusicCommand('what is the weather'), isNull);
      expect(matchMusicCommand('set a timer'), isNull);
      expect(matchMusicCommand(''), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd ~/nivara && flutter test test/features/music/music_command_test.dart
```
Expected: FAIL — `music_command.dart` not found.

- [ ] **Step 3: Create `lib/voice/music_command.dart`**

```dart
/// All music actions that can be triggered by voice without an LLM call.
enum MusicCommand {
  play,
  pause,
  resume,
  skip,
  stop,
  playCalmCategory,
  playEnergizedCategory,
}

/// Returns the matching [MusicCommand] for [transcript], or null if the
/// transcript does not describe a music command.
/// Comparison is case-insensitive.
MusicCommand? matchMusicCommand(String transcript) {
  final lower = transcript.toLowerCase();
  if (lower.contains('play music') || lower.contains('start music')) {
    return MusicCommand.play;
  }
  if (lower.contains('turn off music')) return MusicCommand.stop;
  if (lower.contains('stop music') || lower == 'pause') {
    return MusicCommand.pause;
  }
  if (lower.contains('skip') || lower.contains('next song')) {
    return MusicCommand.skip;
  }
  if (lower.contains('resume') || lower.contains('continue playing')) {
    return MusicCommand.resume;
  }
  if (lower.contains('calmer') ||
      lower.contains('relaxing') ||
      lower.contains('calm down')) {
    return MusicCommand.playCalmCategory;
  }
  if (lower.contains('upbeat') ||
      lower.contains('energize')) {
    return MusicCommand.playEnergizedCategory;
  }
  return null;
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/music/music_command_test.dart
```
Expected: All 8 tests pass.

- [ ] **Step 5: Modify `lib/voice/voice_provider.dart`**

Add the import at the top and replace `_handleTranscript` with the version below. Leave all other methods unchanged.

**Add imports** (after existing imports):
```dart
import '../features/music/domain/mood_category.dart';
import '../features/music/presentation/providers/music_player_notifier.dart';
import 'music_command.dart';
```

**Replace `_handleTranscript`**:
```dart
  Future<void> _handleTranscript(String transcript) async {
    if (transcript.isEmpty) {
      state = VoiceState.idle;
      return;
    }
    state = VoiceState.processing;

    // Attempt music command first — no LLM round-trip needed.
    final musicCmd = matchMusicCommand(transcript);
    if (musicCmd != null) {
      await _executeMusicCommand(musicCmd);
      return;
    }

    // No music command — fall through to normal AI processing.
    await _speak('Processing: $transcript');
  }

  Future<void> _executeMusicCommand(MusicCommand cmd) async {
    final notifier = ref.read(musicPlayerNotifierProvider.notifier);
    try {
      switch (cmd) {
        case MusicCommand.play:
          await notifier.autoPlayForMood();
        case MusicCommand.pause:
          await notifier.pause();
        case MusicCommand.resume:
          await notifier.resume();
        case MusicCommand.skip:
          await notifier.skip();
        case MusicCommand.stop:
          await notifier.stop();
        case MusicCommand.playCalmCategory:
          await notifier.playForCategory(MoodCategory.calm);
        case MusicCommand.playEnergizedCategory:
          await notifier.playForCategory(MoodCategory.energized);
      }
    } catch (_) {
      // Non-critical: voice command failure must not crash the assistant.
    }
    await _speak('On it.');
  }
```

- [ ] **Step 6: Verify voice_provider compiles**

```bash
cd ~/nivara && flutter analyze lib/voice/voice_provider.dart
```
Expected: no errors.

- [ ] **Step 7: Commit**

```bash
cd ~/nivara && git add lib/voice/music_command.dart lib/voice/voice_provider.dart test/features/music/music_command_test.dart
git commit -m "feat(music): add voice command handler — intercept music commands before LLM"
```

---

## Task 12: Rocky Proactive Music Suggestion

**Files:**
- Modify: `lib/features/chat/presentation/providers/chat_provider.dart`
- Test: `test/features/chat/chat_provider_music_suggestion_test.dart`

When Rocky is about to respond and the user's mood is calm (avg ≤ 2.0) and nothing is playing, a soft hint is appended to the system prompt suggesting Rocky mention music if contextually appropriate.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/chat/chat_provider_music_suggestion_test.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';
import 'package:nivara/features/chat/presentation/providers/chat_provider.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';
import 'package:nivara/features/profile/presentation/providers/profile_provider.dart';
import 'package:nivara/features/settings/presentation/providers/ai_model_provider.dart';

@GenerateMocks([HermesClient])
import 'chat_provider_music_suggestion_test.mocks.dart';

// Re-uses the fake notifier pattern from mood tone tests.
class _FakeAiModelNotifier extends AiModelNotifier {
  @override
  Future<String> build() async => 'claude';
}

class _FakeMusicNotifier extends MusicPlayerNotifier {
  _FakeMusicNotifier(this._track);
  final MusicTrack? _track;
  @override
  MusicPlayerState build() => MusicPlayerState(
        isPlaying: false,
        currentTrack: _track,
        playlist: null,
        currentIndex: 0,
        isMoodAutoPlay: true,
      );
}

void main() {
  late MockHermesClient fakeClient;

  setUp(() {
    fakeClient = MockHermesClient();
    when(fakeClient.chatStream(
      messages: anyNamed('messages'),
      assistantName: anyNamed('assistantName'),
      aiModel: anyNamed('aiModel'),
    )).thenAnswer((_) => Stream.fromIterable([
          const TextChunk('Hello'),
          const DoneChunk(),
        ]));
  });

  List<Map<String, String>>? _captureMessages() {
    final captured = verify(fakeClient.chatStream(
      messages: captureAnyNamed('messages'),
      assistantName: anyNamed('assistantName'),
      aiModel: anyNamed('aiModel'),
    )).captured;
    return captured.first as List<Map<String, String>>?;
  }

  test('appends music suggestion hint when mood is calm and nothing is playing',
      () async {
    final container = ProviderContainer(overrides: [
      hermesClientProvider.overrideWithValue(fakeClient),
      moodToneProvider.overrideWith((ref) async => null), // no tone hint
      weekMoodProvider.overrideWith((ref) async => [
            // avg 1.5 → calm
          ]),
      assistantConfigProvider.overrideWith((ref) async => null),
      aiModelNotifierProvider.overrideWith(_FakeAiModelNotifier.new),
      musicPlayerNotifierProvider.overrideWith(
        () => _FakeMusicNotifier(null), // no current track
      ),
      musicServiceProvider.overrideWithValue(
        throw UnimplementedError(), // not called in this path
      ),
      moodPlaylistProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('Hey');

    final messages = _captureMessages();
    expect(
      messages?.any((m) =>
          m['role'] == 'system' &&
          (m['content'] ?? '').contains('suggest') &&
          (m['content'] ?? '').contains('music')),
      isTrue,
    );
  });

  test('does not append hint when music is already playing', () async {
    final container = ProviderContainer(overrides: [
      hermesClientProvider.overrideWithValue(fakeClient),
      moodToneProvider.overrideWith((ref) async => null),
      weekMoodProvider.overrideWith((ref) async => []),
      assistantConfigProvider.overrideWith((ref) async => null),
      aiModelNotifierProvider.overrideWith(_FakeAiModelNotifier.new),
      musicPlayerNotifierProvider.overrideWith(
        () => _FakeMusicNotifier(const MusicTrack(
          id: 'calm_01',
          title: 'Gentle Rain',
          artist: 'Ambient Studio',
          duration: Duration(minutes: 3),
          moodCategory: MoodCategory.calm,
          assetPath: 'assets/music/calm/gentle_rain.mp3',
        )),
      ),
      musicServiceProvider.overrideWithValue(
        throw UnimplementedError(),
      ),
      moodPlaylistProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    await container.read(chatNotifierProvider.notifier).sendMessage('Hey');

    final messages = _captureMessages();
    final systemMessages =
        messages?.where((m) => m['role'] == 'system').toList() ?? [];
    // No system message with music suggestion expected
    for (final msg in systemMessages) {
      expect(
        (msg['content'] ?? '').contains('music'),
        isFalse,
        reason: 'music hint should not be injected when music is playing',
      );
    }
  });
}
```

- [ ] **Step 2: Run build_runner**

```bash
cd ~/nivara && flutter pub run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd ~/nivara && flutter test test/features/chat/chat_provider_music_suggestion_test.dart
```
Expected: FAIL — music suggestion not yet injected.

- [ ] **Step 4: Modify `lib/features/chat/presentation/providers/chat_provider.dart`**

Add these imports after the existing mood import:
```dart
import '../../../music/domain/mood_category.dart';
import '../../../music/presentation/providers/music_player_notifier.dart';
import '../../../music/presentation/providers/music_providers.dart';
```

In `sendMessage`, after the tone hint block and before building `hermesMessages`, add:

```dart
    // Check whether to append a proactive music suggestion hint.
    // Only appended when: mood is calm, no track is currently playing.
    String? musicSuggestionHint;
    try {
      final moodPlaylist = await ref.read(moodPlaylistProvider.future);
      final isCalm = moodPlaylist?.moodCategory == MoodCategory.calm;
      final isPlaying =
          ref.read(musicPlayerNotifierProvider).currentTrack != null;
      if (isCalm && !isPlaying) {
        musicSuggestionHint =
            'If contextually appropriate, suggest the user play some music.';
      }
    } catch (_) {
      // Non-critical — degrade gracefully.
    }
```

Then update `hermesMessages` to include the music hint:

```dart
    final hermesMessages = [
      if (toneHint != null) {'role': 'system', 'content': toneHint},
      if (musicSuggestionHint != null)
        {'role': 'system', 'content': musicSuggestionHint},
      ...baseMessages,
    ];
```

- [ ] **Step 5: Run tests — expect pass**

```bash
cd ~/nivara && flutter test test/features/chat/chat_provider_music_suggestion_test.dart
```
Expected: All 2 tests pass.

- [ ] **Step 6: Run full test suite**

```bash
cd ~/nivara && flutter test
```
Expected: all tests pass (or pre-existing failures only — no regressions introduced).

- [ ] **Step 7: Commit**

```bash
cd ~/nivara && git add lib/features/chat/presentation/providers/chat_provider.dart test/features/chat/chat_provider_music_suggestion_test.dart
git commit -m "feat(music): Rocky suggests music when mood is calm and nothing is playing"
```

---

## Done

All 12 tasks complete. The music system now provides:

- ✅ Bundled royalty-free local tracks (9 tracks, 3 per mood)
- ✅ Mood-matched auto-play playlist when MusicPage opens
- ✅ Mini-player bar visible across all main screens
- ✅ Full-screen MusicPage with playlist view and controls
- ✅ Voice commands: play, pause, resume, skip, stop, change mood
- ✅ Rocky proactive music suggestion when mood is calm

**Next: Plan 6b — Spotify Integration** (Spotify SDK, SpotifyMusicService, auth flow, source switching).
