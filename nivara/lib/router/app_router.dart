import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/pages/sign_in_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/planner/presentation/pages/calendar_consent_page.dart';
import '../features/planner/presentation/pages/planner_page.dart';
import '../features/planner/data/google_calendar_repository.dart';
import '../features/profile/presentation/pages/assistant_setup_page.dart';
import '../features/profile/presentation/pages/profile_setup_page.dart';
import '../voice/voice_settings_page.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final isSignedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/sign-in';

      if (!isSignedIn && !isAuthRoute) return '/welcome';
      if (isSignedIn && isAuthRoute) return '/chat';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupPage(),
      ),
      GoRoute(
        path: '/assistant-setup',
        builder: (context, state) => const AssistantSetupPage(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: '/settings/voice',
        builder: (context, state) => const VoiceSettingsPage(),
      ),
      GoRoute(
        path: '/planner',
        builder: (context, state) => const PlannerPage(),
      ),
      GoRoute(
        path: '/planner/calendar-consent',
        builder: (context, state) {
          final gcalRepo =
              ref.read(googleCalendarRepositoryProvider);
          return CalendarConsentPage(
            onAllow: () async {
              await gcalRepo.requestAccess();
              // ignore: use_build_context_synchronously
              if (context.mounted && context.canPop()) context.pop();
            },
            onSkip: () {
              if (context.canPop()) context.pop();
            },
          );
        },
      ),
    ],
  );
}
