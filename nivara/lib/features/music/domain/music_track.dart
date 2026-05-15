import 'mood_category.dart';

class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.moodCategory,
    this.assetPath,
    this.spotifyUri,
  });

  final String id;
  final String title;
  final String artist;
  final Duration duration;
  final MoodCategory moodCategory;

  /// Relative asset path for bundled tracks, e.g. 'assets/music/calm/track.mp3'.
  /// Null for Spotify-only tracks.
  final String? assetPath;

  /// Spotify track URI, e.g. 'spotify:track:abc123'.
  /// Null for local-only tracks.
  final String? spotifyUri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MusicTrack && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
