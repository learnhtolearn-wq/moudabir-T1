import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/backup_service.dart';
import '../../core/database/database_provider.dart';
import '../../core/notifications/notification_prefs.dart';
import '../../core/notifications/notification_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/security/pin_store.dart';
import '../accounts/accounts_screen.dart';
import '../auth/change_pin_screen.dart';
import '../auth/recovery_code_screen.dart';
import '../budget/budget_screen.dart';
import '../categories/categories_screen.dart';
import '../recurring/recurring_templates_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;
  bool _remindersEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(
    hour: NotificationPrefs.defaultHour,
    minute: NotificationPrefs.defaultMinute,
  );

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final enabled = await NotificationPrefs.isEnabled();
    final (hour, minute) = await NotificationPrefs.getTime();
    if (!mounted) return;
    setState(() {
      _remindersEnabled = enabled;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chevron = Icon(
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left
          : Icons.chevron_right,
    );
    return Scaffold(
      appBar: AppBar(title: Text('nav.settings'.tr())),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text('settings.manage_accounts'.tr()),
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text('settings.manage_categories'.tr()),
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text('settings.manage_budget'.tr()),
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BudgetScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.repeat_outlined),
            title: Text('settings.manage_recurring'.tr()),
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringTemplatesScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            title: Text('settings.language'.tr()),
            subtitle: Text(context.locale.toString()),
            onTap: () => _showLanguagePicker(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text('settings.backup_now'.tr()),
            subtitle: Text('settings.backup_note'.tr()),
            enabled: !_busy,
            onTap: _handleBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: Text('settings.restore_backup'.tr()),
            enabled: !_busy,
            onTap: _handleRestore,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text('auth.change_pin_title'.tr()),
            trailing: chevron,
            enabled: !_busy,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePinScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: Text('settings.recovery_code'.tr()),
            subtitle: Text('settings.recovery_code_note'.tr()),
            trailing: chevron,
            enabled: !_busy,
            onTap: _handleRegenerateRecoveryCode,
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text('settings.reminders_enabled'.tr()),
            subtitle: Text('settings.reminders_note'.tr()),
            value: _remindersEnabled,
            onChanged: _busy ? null : _handleToggleReminders,
          ),
          if (_remindersEnabled)
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text('settings.reminder_time'.tr()),
              subtitle: Text(_reminderTime.format(context)),
              enabled: !_busy,
              onTap: _handleChangeReminderTime,
            ),
        ],
      ),
    );
  }

  static const _localeLabels = {
    'fr': 'Français',
    'en': 'English',
    'ar': 'العربية',
    'ar_MA': 'الدارجة',
  };

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: context.supportedLocales.map((locale) {
            return ListTile(
              title: Text(_localeLabels[locale.toString()] ?? locale.toString()),
              onTap: () {
                context.setLocale(locale);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _handleBackup() async {
    setState(() => _busy = true);
    try {
      // Flush pending writes and release the file handle before copying it.
      await ref.read(databaseProvider).close();
      await BackupService.exportBackup();
      _showMessage('settings.backup_success'.tr());
    } catch (_) {
      _showMessage('settings.backup_error'.tr());
    } finally {
      // Reopens on next access — cheap, and the connection was just closed.
      ref.invalidate(databaseProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.restore_confirm_title'.tr()),
        content: Text('settings.restore_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settings.restore_confirm_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(databaseProvider).close();
      final restored = await BackupService.importBackup();
      _showMessage(
        (restored ? 'settings.restore_success' : 'settings.restore_cancelled')
            .tr(),
      );
    } catch (_) {
      _showMessage('settings.restore_error'.tr());
    } finally {
      ref.invalidate(databaseProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRegenerateRecoveryCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.recovery_code_confirm_title'.tr()),
        content: Text('settings.recovery_code_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('settings.recovery_code_confirm_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final code = await PinStore.regenerateRecoveryCode();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecoveryCodeScreen(
          code: code,
          onContinue: (ctx) => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  Future<void> _handleToggleReminders(bool value) async {
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        _showMessage('settings.reminders_permission_denied'.tr());
        return;
      }
      await NotificationPrefs.setEnabled(true);
      await NotificationService.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
        title: 'notifications.daily_title'.tr(),
        body: 'notifications.daily_body'.tr(),
      );
      await rescheduleGoalReminders(ref.read(databaseProvider));
    } else {
      await NotificationPrefs.setEnabled(false);
      await NotificationService.cancelAll();
    }
    if (mounted) setState(() => _remindersEnabled = value);
  }

  Future<void> _handleChangeReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;

    await NotificationPrefs.setTime(picked.hour, picked.minute);
    await NotificationService.scheduleDailyReminder(
      hour: picked.hour,
      minute: picked.minute,
      title: 'notifications.daily_title'.tr(),
      body: 'notifications.daily_body'.tr(),
    );
    if (mounted) setState(() => _reminderTime = picked);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
