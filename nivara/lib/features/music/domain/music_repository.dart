import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_track.dart';

abstract class MusicRepository {
  Future<MusicPlaylist> getPlaylistForMood(MoodCategory mood);
  Future<List<MusicTrack>> getAllTracks();
}
