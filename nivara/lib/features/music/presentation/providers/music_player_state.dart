import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_source.dart';
import 'package:nivara/features/music/domain/music_track.dart';

// Sentinel for clearing nullable fields in copyWith
const _sentinel = Object();

class MusicPlayerState {
  const MusicPlayerState({
    this.isPlaying = false,
    this.currentTrack,
    this.currentPlaylist,
    this.progress = Duration.zero,
    this.isMoodAutoPlay = true,
    this.source = MusicSource.local,
  });

  final bool isPlaying;
  final MusicTrack? currentTrack;
  final MusicPlaylist? currentPlaylist;
  final Duration progress;
  final bool isMoodAutoPlay;
  final MusicSource source;

  MusicPlayerState copyWith({
    bool? isPlaying,
    Object? currentTrack = _sentinel,
    Object? currentPlaylist = _sentinel,
    Duration? progress,
    bool? isMoodAutoPlay,
    MusicSource? source,
  }) {
    return MusicPlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentTrack: currentTrack == _sentinel
          ? this.currentTrack
          : currentTrack as MusicTrack?,
      currentPlaylist: currentPlaylist == _sentinel
          ? this.currentPlaylist
          : currentPlaylist as MusicPlaylist?,
      progress: progress ?? this.progress,
      isMoodAutoPlay: isMoodAutoPlay ?? this.isMoodAutoPlay,
      source: source ?? this.source,
    );
  }
}
