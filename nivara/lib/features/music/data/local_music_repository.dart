import 'package:nivara/features/music/data/music_manifest.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/domain/music_repository.dart';
import 'package:nivara/features/music/domain/music_track.dart';

/// Reads from the compile-time [kMusicManifest] constant.
class LocalMusicRepository implements MusicRepository {
  const LocalMusicRepository();

  @override
  Future<MusicPlaylist> getPlaylistForMood(MoodCategory mood) async {
    final tracks = kMusicManifest
        .where((t) => t.moodCategory == mood)
        .toList(growable: false);
    return MusicPlaylist(moodCategory: mood, tracks: tracks);
  }

  @override
  Future<List<MusicTrack>> getAllTracks() async =>
      List.unmodifiable(kMusicManifest);
}
