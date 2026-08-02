import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../database/database_provider.dart';
import 'notification_prefs.dart';
import 'notification_service.dart';

/// Runs once on app start: initializes the plugin, and if the user had
/// reminders enabled on a previous launch, reschedules them. Goal nudges are
/// recomputed from the current goal list since deadlines may have changed.
final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  await NotificationService.init();
  if (!await NotificationPrefs.isEnabled()) return;

  final (hour, minute) = await NotificationPrefs.getTime();
  await NotificationService.scheduleDailyReminder(
    hour: hour,
    minute: minute,
    title: 'notifications.daily_title'.tr(),
    body: 'notifications.daily_body'.tr(),
  );

  await rescheduleGoalReminders(ref.read(databaseProvider));
});

/// Recomputes and reschedules goal-deadline nudges from the current goal
/// list. Called on app start and again whenever the Settings screen toggles
/// reminders on or the goal list changes. Takes the database directly
/// (rather than a Ref) since callers include both [FutureProvider]'s `Ref`
/// and Settings' `WidgetRef`, which don't share a common `read` interface.
Future<void> rescheduleGoalReminders(AppDatabase db) async {
  final goals =
      await (db.select(db.goals)..where((g) => g.archived.equals(false)))
          .get();
  await NotificationService.rescheduleGoalReminders(
    goals: goals,
    titleBuilder: (g) =>
        'notifications.goal_deadline_title'.tr(namedArgs: {'name': g.name}),
    bodyBuilder: (g) =>
        'notifications.goal_deadline_body'.tr(namedArgs: {'name': g.name}),
  );
}
