import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_track.dart';
import 'package:nivara/features/music/presentation/providers/music_player_state.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';

class MusicPlayerNotifier extends Notifier<MusicPlayerState> {
  @override
  MusicPlayerState build() => const MusicPlayerState();

  Future<void> play(MusicTrack track) async {
    final service = ref.read(musicServiceProvider);
    await service.play(track);
    state = state.copyWith(isPlaying: true, currentTrack: track);
  }

  Future<void> pause() async {
    final service = ref.read(musicServiceProvider);
    await service.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    final service = ref.read(musicServiceProvider);
    await service.resume();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> skip() async {
    final playlist = state.currentPlaylist;
    final current = state.currentTrack;
    if (playlist == null || playlist.tracks.isEmpty) return;

    final currentIndex = current == null
        ? -1
        : playlist.tracks.indexOf(current);
    final nextIndex = (currentIndex + 1) % playlist.tracks.length;
    await play(playlist.tracks[nextIndex]);
  }

  Future<void> stop() async {
    final service = ref.read(musicServiceProvider);
    await service.stop();
    state = state.copyWith(
      isPlaying: false,
      currentTrack: null,
    );
  }

  Future<void> autoPlayForMood(MusicPlaylist playlist) async {
    if (!state.isMoodAutoPlay) return;
    if (state.currentTrack != null) return; // already playing
    if (playlist.tracks.isEmpty) return;

    state = state.copyWith(currentPlaylist: playlist);
    await play(playlist.tracks.first);
  }

  Future<void> playForCategory(MoodCategory category) async {
    final repo = ref.read(musicRepositoryProvider);
    final playlist = await repo.getPlaylistForMood(category);
    if (playlist.tracks.isEmpty) return;
    state = state.copyWith(currentPlaylist: playlist);
    await play(playlist.tracks.first);
  }

  void updateProgress(Duration progress) {
    state = state.copyWith(progress: progress);
  }

  void setMoodAutoPlay(bool value) {
    state = state.copyWith(isMoodAutoPlay: value);
  }
}

final musicPlayerNotifierProvider =
    NotifierProvider<MusicPlayerNotifier, MusicPlayerState>(
  MusicPlayerNotifier.new,
);
