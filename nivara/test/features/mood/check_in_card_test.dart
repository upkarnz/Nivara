import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/data/mood_repository.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/mood/presentation/widgets/check_in_card.dart';
import 'package:nivara/features/profile/presentation/providers/profile_provider.dart';
import 'package:nivara/shared/models/user_profile.dart';

class FakeMoodRepository extends MoodRepository {
  final List<MoodEntry> saved = [];

  @override
  Future<void> save(MoodEntry entry) async {
    saved.add(entry);
  }

  @override
  Future<List<MoodEntry>> getAll() async => saved;

  @override
  Future<MoodEntry?> getToday() async => null;

  @override
  Future<List<MoodEntry?>> getWeek() async => List.filled(7, null);
}

void main() {
  group('CheckInCard', () {
    late FakeMoodRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeMoodRepository();
    });

    Widget buildCard({VoidCallback? onDismiss}) {
      return ProviderScope(
        overrides: [
          assistantConfigProvider.overrideWith(
            (ref) async => const AssistantConfig(
              name: 'Rocky',
              voice: 'neutral',
              speed: 'normal',
              style: 'friendly',
              wakePhrase: 'Hey Rocky',
              aiModel: 'gpt-4',
            ),
          ),
          moodRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CheckInCard(onDismiss: onDismiss ?? () {}),
          ),
        ),
      );
    }

    testWidgets('shows 5 emoji tap targets', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      for (final emoji in ['😔', '😐', '🙂', '😄', '🤩']) {
        expect(find.text(emoji), findsOneWidget);
      }
    });

    testWidgets('tapping an emoji calls onDismiss', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(buildCard(onDismiss: () => dismissed = true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('🙂'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('tapping an emoji saves a MoodEntry via repository', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('😄'));
      await tester.pumpAndSettle();

      expect(fakeRepo.saved.length, 1);
      expect(fakeRepo.saved.first.score, 4);
      expect(fakeRepo.saved.first.label, 'good');
      expect(fakeRepo.saved.first.source, MoodSource.checkin);
    });

    testWidgets('greeting text contains assistant name from provider', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      expect(find.textContaining('Rocky'), findsOneWidget);
    });

    testWidgets('shows placeholder greeting while loading', (tester) async {
      final completer = Completer<AssistantConfig?>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantConfigProvider.overrideWith(
              (ref) => completer.future,
            ),
            moodRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CheckInCard(onDismiss: () {}),
            ),
          ),
        ),
      );

      // Still loading — completer not yet resolved
      await tester.pump();
      expect(find.textContaining('...'), findsOneWidget);

      // Resolve completer to prevent pending-timer assertion
      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('tapping emoji at index 0 saves score 1', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('😔'));
      await tester.pumpAndSettle();

      expect(fakeRepo.saved.first.score, 1);
      expect(fakeRepo.saved.first.label, 'awful');
    });

    testWidgets('tapping emoji at index 4 saves score 5', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pumpAndSettle();

      await tester.tap(find.text('🤩'));
      await tester.pumpAndSettle();

      expect(fakeRepo.saved.first.score, 5);
      expect(fakeRepo.saved.first.label, 'great');
    });
  });
}
