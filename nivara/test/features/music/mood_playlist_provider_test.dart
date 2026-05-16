import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/mood_playlist_provider.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';

// Re-use mocks from Task 6 (already generated)
import 'music_player_notifier_test.mocks.dart';

MoodEntry _entry(int score) => MoodEntry(
      date: DateTime(2026, 5, 1),
      score: score,
      label: 'test',
      source: MoodSource.passive,
    );

const _calmTrack = MusicTrack(
  id: 'calm_01',
  title: 'Morning Mist',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 4),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/calm_01.mp3',
);

const _neutralTrack = MusicTrack(
  id: 'neutral_01',
  title: 'Coffee Shop Beats',
  artist: 'Lo-Fi Lab',
  duration: Duration(minutes: 3),
  moodCategory: MoodCategory.neutral,
  assetPath: 'assets/music/neutral/neutral_01.mp3',
);

const _energizedTrack = MusicTrack(
  id: 'energized_01',
  title: 'Morning Run',
  artist: 'Focus Beats',
  duration: Duration(minutes: 3),
  moodCategory: MoodCategory.energized,
  assetPath: 'assets/music/energized/energized_01.mp3',
);

void main() {
  // --- Pure function tests (no Riverpod needed) ---

  group('moodCategoryFromAverage', () {
    test('avg <= 2.0 → calm', () {
      expect(moodCategoryFromAverage(1.0), MoodCategory.calm);
      expect(moodCategoryFromAverage(2.0), MoodCategory.calm);
    });

    test('avg 2.1–2.9 → neutral', () {
      expect(moodCategoryFromAverage(2.1), MoodCategory.neutral);
      expect(moodCategoryFromAverage(2.5), MoodCategory.neutral);
      expect(moodCategoryFromAverage(2.9), MoodCategory.neutral);
    });

    test('avg >= 3.0 → energized', () {
      expect(moodCategoryFromAverage(3.0), MoodCategory.energized);
      expect(moodCategoryFromAverage(5.0), MoodCategory.energized);
    });
  });

  // --- Provider tests with overrides ---

  group('moodPlaylistProvider', () {
    late MockMusicRepository mockRepo;

    setUp(() {
      mockRepo = MockMusicRepository();
    });

    ProviderContainer _container(List<MoodEntry?> entries) {
      when(mockRepo.getPlaylistForMood(MoodCategory.calm)).thenAnswer((_) async =>
          const MusicPlaylist(moodCategory: MoodCategory.calm, tracks: [_calmTrack]));
      when(mockRepo.getPlaylistForMood(MoodCategory.neutral)).thenAnswer((_) async =>
          const MusicPlaylist(moodCategory: MoodCategory.neutral, tracks: [_neutralTrack]));
      when(mockRepo.getPlaylistForMood(MoodCategory.energized)).thenAnswer((_) async =>
          const MusicPlaylist(moodCategory: MoodCategory.energized, tracks: [_energizedTrack]));

      return ProviderContainer(
        overrides: [
          weekMoodProvider.overrideWith((_) async => entries),
          musicRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    }

    test('returns calm playlist for avg <= 2.0', () async {
      final c = _container([_entry(1), _entry(2), _entry(2)]); // avg 1.67
      addTearDown(c.dispose);
      final result = await c.read(moodPlaylistProvider.future);
      expect(result?.moodCategory, MoodCategory.calm);
    });

    test('returns neutral playlist for avg 2.1–2.9', () async {
      final c = _container([_entry(2), _entry(3), _entry(3)]); // avg 2.67
      addTearDown(c.dispose);
      final result = await c.read(moodPlaylistProvider.future);
      expect(result?.moodCategory, MoodCategory.neutral);
    });

    test('returns energized playlist for avg >= 3.0', () async {
      final c = _container([_entry(4), _entry(3), _entry(4)]); // avg 3.67
      addTearDown(c.dispose);
      final result = await c.read(moodPlaylistProvider.future);
      expect(result?.moodCategory, MoodCategory.energized);
    });

    test('returns null for empty mood history', () async {
      final c = _container([]);
      addTearDown(c.dispose);
      final result = await c.read(moodPlaylistProvider.future);
      expect(result, isNull);
    });

    test('returns null for list with only null entries', () async {
      final c = _container([null, null]);
      addTearDown(c.dispose);
      final result = await c.read(moodPlaylistProvider.future);
      expect(result, isNull);
    });
  });
}
