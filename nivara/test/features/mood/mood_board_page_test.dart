import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/presentation/pages/mood_board_page.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';

void main() {
  Widget buildPage(List<MoodEntry?> week) {
    return ProviderScope(
      overrides: [
        weekMoodProvider.overrideWith((ref) async => week),
      ],
      child: const MaterialApp(home: MoodBoardPage()),
    );
  }

  group('MoodBoardPage', () {
    testWidgets('shows loading spinner while data loads', (tester) async {
      final completer = Completer<List<MoodEntry?>>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weekMoodProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(home: MoodBoardPage()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete(List<MoodEntry?>.filled(7, null));
      await tester.pumpAndSettle();
    });

    testWidgets('shows all 7 day columns', (tester) async {
      final week = List<MoodEntry?>.filled(7, null);
      await tester.pumpWidget(buildPage(week));
      await tester.pump();
      expect(find.text('M'), findsWidgets);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('shows emoji for day with entry', (tester) async {
      final today = DateTime.now();
      final entry = MoodEntry(
        date: DateTime(today.year, today.month, today.day),
        score: 5,
        label: 'great',
        source: MoodSource.passive,
      );
      final week = List<MoodEntry?>.filled(7, null);
      final todayIdx = today.weekday - 1;
      final filledWeek = List<MoodEntry?>.from(week)..[todayIdx] = entry;
      await tester.pumpWidget(buildPage(filledWeek));
      await tester.pump();
      expect(find.text('🤩'), findsOneWidget);
    });

    testWidgets('shows week average chip when data present', (tester) async {
      final today = DateTime.now();
      final entry = MoodEntry(
        date: DateTime(today.year, today.month, today.day),
        score: 4,
        label: 'good',
        source: MoodSource.passive,
      );
      final week = List<MoodEntry?>.filled(7, null);
      final todayIdx = today.weekday - 1;
      final filledWeek = List<MoodEntry?>.from(week)..[todayIdx] = entry;
      await tester.pumpWidget(buildPage(filledWeek));
      await tester.pump();
      expect(find.textContaining('Week avg'), findsOneWidget);
    });
  });
}
