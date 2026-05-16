import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'features/subscription/data/revenue_cat_service.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/mood_notification_service.dart';

/// RevenueCat API keys — one per platform.
/// Replace the placeholder values with your dashboard keys before release.
const _kRevenueCatApiKeyIos = String.fromEnvironment(
  'REVENUECAT_API_KEY_IOS',
  defaultValue: 'appl_REPLACE_ME',
);
const _kRevenueCatApiKeyAndroid = String.fromEnvironment(
  'REVENUECAT_API_KEY_ANDROID',
  defaultValue: 'goog_REPLACE_ME',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialise RevenueCat before runApp so subscription state is available
  // immediately when the widget tree builds.
  final rcService = RevenueCatServiceImpl();
  final rcApiKey = defaultTargetPlatform == TargetPlatform.iOS
      ? _kRevenueCatApiKeyIos
      : _kRevenueCatApiKeyAndroid;
  try {
    await rcService.init(rcApiKey);
  } on Exception catch (e) {
    debugPrint('RevenueCat init failed: $e');
    // Non-fatal — app degrades to Free tier.
  }

  try {
    await MoodNotificationService.init();
    final granted = await MoodNotificationService.requestPermissions();
    if (granted) {
      await MoodNotificationService.scheduleDailyReminder();
    }
  } on Exception catch (e) {
    debugPrint('Notification setup failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(rcService),
      ],
      child: const NivaraApp(),
    ),
  );
}

class NivaraApp extends ConsumerWidget {
  const NivaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Nivara',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
