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
