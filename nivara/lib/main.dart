import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/mood_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await MoodNotificationService.init();
    final granted = await MoodNotificationService.requestPermissions();
    if (granted) {
      await MoodNotificationService.scheduleDailyReminder();
    }
  } on Exception catch (e) {
    debugPrint('Notification setup failed: $e');
  }
  runApp(const ProviderScope(child: NivaraApp()));
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
