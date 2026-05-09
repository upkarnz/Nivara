import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';

void main() {
  group('MoodEntry', () {
    test('emoji returns correct emoji for each score', () {
      expect(MoodEntry(date: DateTime(2025), score: 1, label: 'sad', source: MoodSource.passive).emoji, '😔');
      expect(MoodEntry(date: DateTime(2025), score: 2, label: 'meh', source: MoodSource.passive).emoji, '😐');
      expect(MoodEntry(date: DateTime(2025), score: 3, label: 'ok', source: MoodSource.passive).emoji, '🙂');
      expect(MoodEntry(date: DateTime(2025), score: 4, label: 'good', source: MoodSource.passive).emoji, '😄');
      expect(MoodEntry(date: DateTime(2025), score: 5, label: 'great', source: MoodSource.passive).emoji, '🤩');
    });

    test('emoji returns question mark for unknown score', () {
      expect(MoodEntry(date: DateTime(2025), score: 99, label: 'wat', source: MoodSource.passive).emoji, '❓');
    });

    test('toJson round-trips via fromJson', () {
      final entry = MoodEntry(
        date: DateTime(2025, 5, 9),
        score: 4,
        label: 'happy',
        source: MoodSource.checkin,
      );
      final json = entry.toJson();
      final restored = MoodEntry.fromJson(json);
      expect(restored.score, 4);
      expect(restored.label, 'happy');
      expect(restored.source, MoodSource.checkin);
      expect(restored.date.year, 2025);
      expect(restored.date.month, 5);
      expect(restored.date.day, 9);
    });

    test('MoodSource has passive and checkin values', () {
      expect(MoodSource.values, containsAll([MoodSource.passive, MoodSource.checkin]));
    });
  });
}
