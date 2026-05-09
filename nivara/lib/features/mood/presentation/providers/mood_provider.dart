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
