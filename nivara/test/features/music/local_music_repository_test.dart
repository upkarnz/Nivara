import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/music/data/local_music_repository.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_repository.dart';

void main() {
  group('LocalMusicRepository', () {
    const repo = LocalMusicRepository();

    test('implements MusicRepository', () {
      expect(repo, isA<MusicRepository>());
    });

    test('getAllTracks returns 9 tracks', () async {
      final tracks = await repo.getAllTracks();
      expect(tracks.length, 9);
    });

    test('getPlaylistForMood(calm) returns 3 calm tracks', () async {
      final playlist = await repo.getPlaylistForMood(MoodCategory.calm);
      expect(playlist.moodCategory, MoodCategory.calm);
      expect(playlist.tracks.length, 3);
      expect(playlist.tracks.every((t) => t.moodCategory == MoodCategory.calm), isTrue);
    });

    test('getPlaylistForMood(neutral) returns 3 neutral tracks', () async {
      final playlist = await repo.getPlaylistForMood(MoodCategory.neutral);
      expect(playlist.tracks.length, 3);
    });

    test('getPlaylistForMood(energized) returns 3 energized tracks', () async {
      final playlist = await repo.getPlaylistForMood(MoodCategory.energized);
      expect(playlist.tracks.length, 3);
    });
  });
}
