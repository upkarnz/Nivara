import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_repository.dart';
import 'package:nivara/features/music/domain/music_service.dart';
import 'package:nivara/features/music/domain/music_track.dart';

import 'interfaces_test.mocks.dart';

@GenerateMocks([MusicService, MusicRepository])
void main() {
  group('MusicService', () {
    late MockMusicService mockMusicService;

    setUp(() {
      mockMusicService = MockMusicService();
    });

    test('play can be called without error', () async {
      final track = MusicTrack(
        id: 'track-1',
        title: 'Test Track',
        artist: 'Test Artist',
        duration: const Duration(minutes: 3),
        moodCategory: MoodCategory.calm,
      );

      when(mockMusicService.play(track)).thenAnswer((_) async {});

      await expectLater(mockMusicService.play(track), completes);
      verify(mockMusicService.play(track)).called(1);
    });

    test('pause can be called without error', () async {
      when(mockMusicService.pause()).thenAnswer((_) async {});

      await expectLater(mockMusicService.pause(), completes);
      verify(mockMusicService.pause()).called(1);
    });

    test('resume can be called without error', () async {
      when(mockMusicService.resume()).thenAnswer((_) async {});

      await expectLater(mockMusicService.resume(), completes);
      verify(mockMusicService.resume()).called(1);
    });

    test('skip can be called without error', () async {
      when(mockMusicService.skip()).thenAnswer((_) async {});

      await expectLater(mockMusicService.skip(), completes);
      verify(mockMusicService.skip()).called(1);
    });

    test('stop can be called without error', () async {
      when(mockMusicService.stop()).thenAnswer((_) async {});

      await expectLater(mockMusicService.stop(), completes);
      verify(mockMusicService.stop()).called(1);
    });

    test('seekTo can be called without error', () async {
      const position = Duration(seconds: 30);
      when(mockMusicService.seekTo(position)).thenAnswer((_) async {});

      await expectLater(mockMusicService.seekTo(position), completes);
      verify(mockMusicService.seekTo(position)).called(1);
    });
  });

  group('MusicRepository', () {
    late MockMusicRepository mockMusicRepository;

    setUp(() {
      mockMusicRepository = MockMusicRepository();
    });

    test('getPlaylistForMood returns MusicPlaylist', () async {
      final playlist = MusicPlaylist(
        moodCategory: MoodCategory.calm,
        tracks: [
          MusicTrack(
            id: 'track-1',
            title: 'Calm Track',
            artist: 'Artist',
            duration: const Duration(minutes: 4),
            moodCategory: MoodCategory.calm,
          ),
        ],
      );

      when(mockMusicRepository.getPlaylistForMood(MoodCategory.calm))
          .thenAnswer((_) async => playlist);

      final result =
          await mockMusicRepository.getPlaylistForMood(MoodCategory.calm);

      expect(result, isA<MusicPlaylist>());
      expect(result.moodCategory, MoodCategory.calm);
      expect(result.tracks.length, 1);
      verify(mockMusicRepository.getPlaylistForMood(MoodCategory.calm))
          .called(1);
    });

    test('getAllTracks returns List<MusicTrack>', () async {
      final tracks = [
        MusicTrack(
          id: 'track-1',
          title: 'Track One',
          artist: 'Artist A',
          duration: const Duration(minutes: 3),
          moodCategory: MoodCategory.neutral,
        ),
        MusicTrack(
          id: 'track-2',
          title: 'Track Two',
          artist: 'Artist B',
          duration: const Duration(minutes: 5),
          moodCategory: MoodCategory.energized,
        ),
      ];

      when(mockMusicRepository.getAllTracks()).thenAnswer((_) async => tracks);

      final result = await mockMusicRepository.getAllTracks();

      expect(result, isA<List<MusicTrack>>());
      expect(result.length, 2);
      verify(mockMusicRepository.getAllTracks()).called(1);
    });
  });
}
