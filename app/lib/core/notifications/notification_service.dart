import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/database.dart';

/// Local-only scheduled notifications (no push, no server — matches the
/// project's zero-cloud constraint). Two kinds: a repeating daily reminder
/// to log expenses, and one-shot nudges a few days before a goal's deadline.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Notification ids: 1 is the daily reminder; goal nudges use
  // 1000 + goal.id so they never collide with it or each other.
  static const _dailyReminderId = 1;
  static const _goalIdOffset = 1000;

  static const _channelId = 'reminders';
  static const _channelName = 'Reminders';

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() =>
      _plugin.cancel(id: _dailyReminderId);

  /// Replaces all pending goal-deadline nudges with fresh ones computed from
  /// [goals] — call whenever the goal list or reminder settings change.
  static Future<void> rescheduleGoalReminders({
    required List<Goal> goals,
    required String Function(Goal goal) titleBuilder,
    required String Function(Goal goal) bodyBuilder,
    int daysBefore = 3,
  }) async {
    for (final goal in goals) {
      await _plugin.cancel(id: _goalIdOffset + goal.id);
    }

    final now = DateTime.now();
    for (final goal in goals) {
      final deadline = goal.deadline;
      if (goal.achieved || deadline == null) continue;

      final nudgeDate = deadline.subtract(Duration(days: daysBefore));
      if (nudgeDate.isBefore(now)) continue;

      await _plugin.zonedSchedule(
        id: _goalIdOffset + goal.id,
        title: titleBuilder(goal),
        body: bodyBuilder(goal),
        scheduledDate: tz.TZDateTime.from(nudgeDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
