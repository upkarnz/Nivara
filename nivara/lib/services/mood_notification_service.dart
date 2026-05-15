import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MoodNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'mood_daily';
  static const _channelName = 'Daily Mood Check-In';
  static const _notificationId = 42;

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);
  }

  static Future<void> scheduleDailyReminder() async {
    await _plugin.zonedSchedule(
      _notificationId,
      'How are you feeling today?',
      'Tap to log your mood.',
      _nextInstanceOf9AM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancel(_notificationId);
  }

  static Future<bool> requestPermissions() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final iosGranted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true; // non-iOS defaults to granted

    final androidGranted =
        await android?.requestNotificationsPermission() ?? true;

    return iosGranted && androidGranted;
  }

  @visibleForTesting
  static tz.TZDateTime nextInstanceOf9AM() => _nextInstanceOf9AM();

  static tz.TZDateTime _nextInstanceOf9AM() {
    tz.initializeTimeZones(); // idempotent — safe to call multiple times
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
