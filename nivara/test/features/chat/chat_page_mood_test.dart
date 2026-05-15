import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:nivara/features/auth/data/auth_repository.dart';
import 'package:nivara/features/chat/presentation/pages/chat_page.dart';
import 'package:nivara/features/chat/presentation/providers/chat_provider.dart';
import 'package:nivara/features/mood/data/mood_repository.dart';
import 'package:nivara/features/mood/domain/mood_entry.dart';
import 'package:nivara/features/mood/presentation/providers/mood_provider.dart';
import 'package:nivara/features/profile/presentation/providers/profile_provider.dart';
import 'package:nivara/shared/models/user_profile.dart';

// Re-use the generated mocks from the auth tests so we don't need a second
// build_runner pass.  The path is relative to the test root.
import '../../auth/auth_repository_test.mocks.dart';

// ---------------------------------------------------------------------------
// Fake: MoodRepository
// ---------------------------------------------------------------------------

class FakeMoodRepository extends MoodRepository {
  final MoodEntry? todayEntry;
  FakeMoodRepository({this.todayEntry});

  @override
  Future<MoodEntry?> getToday() async => todayEntry;

  @override
  Future<List<MoodEntry?>> getWeek() async => List.filled(7, null);

  @override
  Future<void> save(MoodEntry entry) async {}
}

// ---------------------------------------------------------------------------
// Helper: build a minimal GoRouter that serves ChatPage at /chat.
// ---------------------------------------------------------------------------
GoRouter _buildRouter({
  Widget Function(BuildContext, GoRouterState)? moodBuilder,
}) {
  return GoRouter(
    initialLocation: '/chat',
    routes: [
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: '/mood',
        builder: moodBuilder ??
            (context, state) =>
                const Scaffold(body: Text('MoodStubPage')),
      ),
      GoRoute(
        path: '/planner',
        builder: (context, state) =>
            const Scaffold(body: Text('PlannerStub')),
      ),
      GoRoute(
        path: '/memory',
        builder: (context, state) =>
            const Scaffold(body: Text('MemoryStub')),
      ),
      GoRoute(
        path: '/settings/voice',
        builder: (context, state) =>
            const Scaffold(body: Text('VoiceStub')),
      ),
    ],
  );
}

/// Builds the full widget tree with all required provider overrides.
Widget _buildApp({
  GoRouter? router,
  MoodEntry? todayMoodEntry,
}) {
  final fakeRepo = FakeMoodRepository(todayEntry: todayMoodEntry);
  final r = router ?? _buildRouter();

  // Build an AuthRepository backed by a stub FirebaseAuth so no real Firebase
  // initialisation is needed.
  final mockFirebaseAuth = MockFirebaseAuth();
  when(mockFirebaseAuth.authStateChanges())
      .thenAnswer((_) => Stream.value(null));
  final fakeAuthRepo = AuthRepository(auth: mockFirebaseAuth);

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuthRepo),
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
      chatNotifierProvider.overrideWith(ChatNotifier.new),
      moodRepositoryProvider.overrideWithValue(fakeRepo),
      todayMoodProvider.overrideWith((ref) async => todayMoodEntry),
    ],
    child: MaterialApp.router(
      routerConfig: r,
    ),
  );
}

void main() {
  group('ChatPage — mood AppBar icon', () {
    testWidgets('mood icon is present in AppBar', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mood_outlined), findsOneWidget);
    });

    testWidgets('tapping mood icon navigates to /mood route', (tester) async {
      final router = _buildRouter(
        moodBuilder: (context, state) =>
            const Scaffold(body: Text('MoodStubPage')),
      );

      await tester.pumpWidget(_buildApp(router: router));
      await tester.pumpAndSettle();

      // Verify mood icon is present before tapping
      expect(find.byIcon(Icons.mood_outlined), findsOneWidget);

      // Tap the mood icon
      await tester.tap(find.byIcon(Icons.mood_outlined));
      await tester.pumpAndSettle();

      // Verify navigation to /mood happened — the stub page text is visible
      expect(find.text('MoodStubPage'), findsOneWidget);
    });
  });
}
