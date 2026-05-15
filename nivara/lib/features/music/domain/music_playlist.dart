import 'mood_category.dart';
import 'music_track.dart';

class MusicPlaylist {
  const MusicPlaylist({
    required this.moodCategory,
    required this.tracks,
  });

  final MoodCategory moodCategory;
  final List<MusicTrack> tracks;

  bool get isEmpty => tracks.isEmpty;
}
