import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_track.dart';

/// Compile-time constant track catalogue.
/// Asset paths match files registered in pubspec.yaml under assets/music/.
const List<MusicTrack> kMusicManifest = [
  // --- Calm ---
  MusicTrack(
    id: 'calm_01',
    title: 'Morning Mist',
    artist: 'Ambient Studio',
    duration: Duration(minutes: 4, seconds: 12),
    moodCategory: MoodCategory.calm,
    assetPath: 'assets/music/calm/calm_01.mp3',
  ),
  MusicTrack(
    id: 'calm_02',
    title: 'Rain on Leaves',
    artist: 'Ambient Studio',
    duration: Duration(minutes: 3, seconds: 45),
    moodCategory: MoodCategory.calm,
    assetPath: 'assets/music/calm/calm_02.mp3',
  ),
  MusicTrack(
    id: 'calm_03',
    title: 'Still Waters',
    artist: 'Ambient Studio',
    duration: Duration(minutes: 5, seconds: 0),
    moodCategory: MoodCategory.calm,
    assetPath: 'assets/music/calm/calm_03.mp3',
  ),
  // --- Neutral ---
  MusicTrack(
    id: 'neutral_01',
    title: 'Coffee Shop Beats',
    artist: 'Lo-Fi Lab',
    duration: Duration(minutes: 3, seconds: 30),
    moodCategory: MoodCategory.neutral,
    assetPath: 'assets/music/neutral/neutral_01.mp3',
  ),
  MusicTrack(
    id: 'neutral_02',
    title: 'Study Session',
    artist: 'Lo-Fi Lab',
    duration: Duration(minutes: 4, seconds: 0),
    moodCategory: MoodCategory.neutral,
    assetPath: 'assets/music/neutral/neutral_02.mp3',
  ),
  MusicTrack(
    id: 'neutral_03',
    title: 'Midday Flow',
    artist: 'Lo-Fi Lab',
    duration: Duration(minutes: 3, seconds: 55),
    moodCategory: MoodCategory.neutral,
    assetPath: 'assets/music/neutral/neutral_03.mp3',
  ),
  // --- Energized ---
  MusicTrack(
    id: 'energized_01',
    title: 'Morning Run',
    artist: 'Focus Beats',
    duration: Duration(minutes: 3, seconds: 20),
    moodCategory: MoodCategory.energized,
    assetPath: 'assets/music/energized/energized_01.mp3',
  ),
  MusicTrack(
    id: 'energized_02',
    title: 'Power Hour',
    artist: 'Focus Beats',
    duration: Duration(minutes: 4, seconds: 10),
    moodCategory: MoodCategory.energized,
    assetPath: 'assets/music/energized/energized_02.mp3',
  ),
  MusicTrack(
    id: 'energized_03',
    title: 'Peak Performance',
    artist: 'Focus Beats',
    duration: Duration(minutes: 3, seconds: 50),
    moodCategory: MoodCategory.energized,
    assetPath: 'assets/music/energized/energized_03.mp3',
  ),
];
