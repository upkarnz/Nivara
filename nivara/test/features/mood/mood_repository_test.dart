import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nivara/features/mood/data/mood_repository.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MoodRepository', () {
    test('save and getToday returns the entry', () async {
      final repo = MoodRepository();
      final today = DateTime.now();
      final entry = MoodEntry(date: today, score: 3, label: 'ok', source: MoodSource.passive);
      await repo.save(entry);
      final result = await repo.getToday();
      expect(result?.score, 3);
      expect(result?.label, 'ok');
    });

    test('passive cannot overwrite a checkin', () async {
      final repo = MoodRepository();
      final today = DateTime.now();
      final checkin = MoodEntry(date: today, score: 5, label: 'great', source: MoodSource.checkin);
      final passive = MoodEntry(date: today, score: 2, label: 'meh', source: MoodSource.passive);
      await repo.save(checkin);
      await repo.save(passive);
      final result = await repo.getToday();
      expect(result?.score, 5);
      expect(result?.source, MoodSource.checkin);
    });

    test('checkin overwrites passive', () async {
      final repo = MoodRepository();
      final today = DateTime.now();
      final passive = MoodEntry(date: today, score: 2, label: 'meh', source: MoodSource.passive);
      final checkin = MoodEntry(date: today, score: 5, label: 'great', source: MoodSource.checkin);
      await repo.save(passive);
      await repo.save(checkin);
      final result = await repo.getToday();
      expect(result?.score, 5);
      expect(result?.source, MoodSource.checkin);
    });

    test('getWeek returns 7 elements', () async {
      final repo = MoodRepository();
      final week = await repo.getWeek();
      expect(week.length, 7);
    });

    test('getToday returns null when no entry saved', () async {
      final repo = MoodRepository();
      final result = await repo.getToday();
      expect(result, isNull);
    });
  });
}
