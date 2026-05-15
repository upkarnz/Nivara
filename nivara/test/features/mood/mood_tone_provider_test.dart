import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';

MoodEntry _e(int s) => MoodEntry(
      date: DateTime(2026, 1, 1),
      score: s,
      label: 'test',
      source: MoodSource.checkin,
    );

ProviderContainer _c(List<MoodEntry?> entries) => ProviderContainer(
      overrides: [
        weekMoodProvider.overrideWith((ref) => Future.value(entries)),
      ],
    );

void main() {
  group('moodToneProvider', () {
    test('warm when avg below 2.0', () async {
      final c = _c([_e(1), _e(2), _e(1), _e(2), _e(2)]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future),
          'Be warm and gentle. Avoid upbeat openers.');
    });

    test('warm when avg exactly 2.0', () async {
      final c = _c([_e(2), _e(2), _e(2), _e(2), _e(2)]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future),
          'Be warm and gentle. Avoid upbeat openers.');
    });

    test('calm when avg between 2.0 and 3.0', () async {
      final c = _c([_e(2), _e(3), _e(2), _e(3), _e(2)]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future),
          'Keep your tone calm and measured.');
    });

    test('null when avg exactly 3.0', () async {
      final c = _c([_e(3), _e(3), _e(3)]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future), isNull);
    });

    test('null when avg above 3.0', () async {
      final c = _c([_e(4), _e(5), _e(4), _e(5)]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future), isNull);
    });

    test('null when list is empty', () async {
      final c = _c([]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future), isNull);
    });

    test('skips null entries when computing average', () async {
      // nulls + [1,2] → avg 1.5 → warm
      final c = _c([null, null, _e(1), _e(2)]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future),
          'Be warm and gentle. Avoid upbeat openers.');
    });

    test('null when weekMoodProvider throws', () async {
      final c = ProviderContainer(overrides: [
        weekMoodProvider.overrideWith(
            (ref) => Future.error(Exception('db error'))),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(moodToneProvider.future), isNull);
    });
  });
}
