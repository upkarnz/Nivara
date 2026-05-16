import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_repository.dart';
import 'package:nivara/features/music/domain/music_service.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/music_player_notifier.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';

@GenerateMocks([MusicService, MusicRepository])
import 'music_player_notifier_test.mocks.dart';

const _calm01 = MusicTrack(
  id: 'calm_01',
  title: 'Morning Mist',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 4),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/calm_01.mp3',
);

const _calm02 = MusicTrack(
  id: 'calm_02',
  title: 'Rain on Leaves',
  artist: 'Ambient Studio',
  duration: Duration(minutes: 3),
  moodCategory: MoodCategory.calm,
  assetPath: 'assets/music/calm/calm_02.mp3',
);

const _calmPlaylist = MusicPlaylist(
  moodCategory: MoodCategory.calm,
  tracks: [_calm01, _calm02],
);

ProviderContainer makeContainer({
  required MockMusicService service,
  required MockMusicRepository repo,
}) {
  return ProviderContainer(
    overrides: [
      musicServiceProvider.overrideWithValue(service),
      musicRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  late MockMusicService mockService;
  late MockMusicRepository mockRepo;

  setUp(() {
    mockService = MockMusicService();
    mockRepo = MockMusicRepository();
    when(mockService.play(any)).thenAnswer((_) async {});
    when(mockService.pause()).thenAnswer((_) async {});
    when(mockService.resume()).thenAnswer((_) async {});
    when(mockService.skip()).thenAnswer((_) async {});
    when(mockService.stop()).thenAnswer((_) async {});
    when(mockService.seekTo(any)).thenAnswer((_) async {});
    when(mockRepo.getPlaylistForMood(any))
        .thenAnswer((_) async => _calmPlaylist);
  });

  test('initial state has sensible defaults', () {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    final state = container.read(musicPlayerNotifierProvider);
    expect(state.isPlaying, isFalse);
    expect(state.currentTrack, isNull);
    expect(state.isMoodAutoPlay, isTrue);
  });

  test('play sets isPlaying=true and currentTrack', () async {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    await container
        .read(musicPlayerNotifierProvider.notifier)
        .play(_calm01);

    final state = container.read(musicPlayerNotifierProvider);
    expect(state.isPlaying, isTrue);
    expect(state.currentTrack, _calm01);
    verify(mockService.play(_calm01)).called(1);
  });

  test('pause sets isPlaying=false', () async {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    await container.read(musicPlayerNotifierProvider.notifier).play(_calm01);
    await container.read(musicPlayerNotifierProvider.notifier).pause();

    expect(container.read(musicPlayerNotifierProvider).isPlaying, isFalse);
  });

  test('stop clears currentTrack', () async {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    await container.read(musicPlayerNotifierProvider.notifier).play(_calm01);
    await container.read(musicPlayerNotifierProvider.notifier).stop();

    final state = container.read(musicPlayerNotifierProvider);
    expect(state.isPlaying, isFalse);
    expect(state.currentTrack, isNull);
  });

  test('skip advances to next track in playlist', () async {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    await notifier.autoPlayForMood(_calmPlaylist); // plays calm_01
    await notifier.skip();

    expect(container.read(musicPlayerNotifierProvider).currentTrack, _calm02);
  });

  test('skip wraps to first track at end of playlist', () async {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    await notifier.autoPlayForMood(_calmPlaylist); // plays calm_01
    await notifier.skip(); // plays calm_02
    await notifier.skip(); // wraps to calm_01

    expect(container.read(musicPlayerNotifierProvider).currentTrack, _calm01);
  });

  test('autoPlayForMood no-ops when isMoodAutoPlay=false', () async {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    notifier.setMoodAutoPlay(false);
    await notifier.autoPlayForMood(_calmPlaylist);

    expect(container.read(musicPlayerNotifierProvider).currentTrack, isNull);
    verifyNever(mockService.play(any));
  });

  test('autoPlayForMood no-ops when track already playing', () async {
    final container = makeContainer(service: mockService, repo: mockRepo);
    addTearDown(container.dispose);

    final notifier = container.read(musicPlayerNotifierProvider.notifier);
    await notifier.play(_calm01);
    await notifier.autoPlayForMood(_calmPlaylist);

    // play called only once (from direct play, not from autoPlayForMood)
    verify(mockService.play(_calm01)).called(1);
  });
}
