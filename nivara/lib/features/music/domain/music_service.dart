import 'package:nivara/features/music/domain/music_track.dart';

abstract class MusicService {
  Future<void> play(MusicTrack track);
  Future<void> pause();
  Future<void> resume();
  Future<void> skip();
  Future<void> stop();
  Future<void> seekTo(Duration position);
}
