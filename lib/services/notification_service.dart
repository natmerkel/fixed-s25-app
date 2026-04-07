import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> instantAlert({required int id, required String title, required String body}) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trade_alerts',
        'Trade Alerts',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  Future<void> scheduleDailySessionOpen() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'session_alerts',
        'Session Alerts',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    final location = tz.getLocation('Australia/Brisbane');
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, 23);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      100,
      'Trading Session Window Open – 11 PM AEST',
      'Session open. No entries outside 11:00 PM to 3:00 AM AEST.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
