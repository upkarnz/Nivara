import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/music/domain/mood_category.dart';
import 'package:nivara/features/music/domain/music_playlist.dart';
import 'package:nivara/features/music/presentation/providers/music_providers.dart';

/// Maps a rolling 7-day mood average to a [MoodCategory].
///
/// Thresholds:
///   avg ≤ 2.0  → [MoodCategory.calm]
///   > 2.0 < 3.0 → [MoodCategory.neutral]
///   ≥ 3.0      → [MoodCategory.energized]
///   empty / error → null
MoodCategory? moodCategoryFromAverage(double avg) {
  if (avg <= 2.0) return MoodCategory.calm;
  if (avg < 3.0) return MoodCategory.neutral;
  return MoodCategory.energized;
}

/// Returns the matched [MusicPlaylist] for the current 7-day mood average,
/// or null when there is no mood history or an error occurs.
final moodPlaylistProvider = FutureProvider<MusicPlaylist?>((ref) async {
  try {
    final entries = await ref.watch(weekMoodProvider.future);
    final scores = entries
        .whereType<MoodEntry>()
        .map((e) => e.score.toDouble())
        .toList();

    if (scores.isEmpty) return null;

    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final category = moodCategoryFromAverage(avg);
    if (category == null) return null;

    final repo = ref.read(musicRepositoryProvider);
    return await repo.getPlaylistForMood(category);
  } catch (_) {
    return null;
  }
});
