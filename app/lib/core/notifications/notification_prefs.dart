import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's reminder preferences. Not sensitive data, but reuses
/// [FlutterSecureStorage] since it's already a dependency (avoids adding
/// shared_preferences just for a couple of small values).
class NotificationPrefs {
  NotificationPrefs._();

  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'moudabbir_notif_enabled';
  static const _hourKey = 'moudabbir_notif_hour';
  static const _minuteKey = 'moudabbir_notif_minute';

  static const defaultHour = 20;
  static const defaultMinute = 0;

  static Future<bool> isEnabled() async =>
      await _storage.read(key: _enabledKey) == 'true';

  static Future<void> setEnabled(bool value) =>
      _storage.write(key: _enabledKey, value: value.toString());

  static Future<(int hour, int minute)> getTime() async {
    final hour =
        int.tryParse(await _storage.read(key: _hourKey) ?? '') ?? defaultHour;
    final minute = int.tryParse(await _storage.read(key: _minuteKey) ?? '') ??
        defaultMinute;
    return (hour, minute);
  }

  static Future<void> setTime(int hour, int minute) async {
    await _storage.write(key: _hourKey, value: hour.toString());
    await _storage.write(key: _minuteKey, value: minute.toString());
  }
}
