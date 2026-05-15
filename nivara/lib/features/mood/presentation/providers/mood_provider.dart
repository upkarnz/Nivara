import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mood_repository.dart';
import '../../domain/mood_entry.dart';

final moodRepositoryProvider = Provider<MoodRepository>(
  (ref) => MoodRepository(),
);

final weekMoodProvider = FutureProvider<List<MoodEntry?>>((ref) async {
  final repo = ref.read(moodRepositoryProvider);
  return repo.getWeek();
});

final todayMoodProvider = FutureProvider<MoodEntry?>((ref) async {
  final repo = ref.read(moodRepositoryProvider);
  return repo.getToday();
});

/// Returns a tone hint string to inject silently into the Hermes system prompt,
/// or null when the user's recent mood is neutral/positive (no injection needed).
///
/// Threshold rules (rolling 7-day average of non-null scores):
///   avg <= 2.0           → warm/gentle hint
///   avg > 2.0 && < 3.0  → calm/measured hint
///   avg >= 3.0           → null (use Nivara's default tone)
///   empty list / error   → null
final moodToneProvider = FutureProvider<String?>((ref) async {
  try {
    final entries = await ref.watch(weekMoodProvider.future);
    final scores = entries
        .whereType<MoodEntry>()
        .map((e) => e.score)
        .toList();
    if (scores.isEmpty) return null;
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    if (avg <= 2.0) return 'Be warm and gentle. Avoid upbeat openers.';
    if (avg < 3.0) return 'Keep your tone calm and measured.';
    return null;
  } catch (_) {
    return null;
  }
});
