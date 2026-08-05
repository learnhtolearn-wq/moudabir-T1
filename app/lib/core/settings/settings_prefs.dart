import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small persisted app settings beyond PIN/notifications — reuses
/// [FlutterSecureStorage] like [NotificationPrefs] rather than adding a new
/// storage dependency for one value.
class SettingsPrefs {
  SettingsPrefs._();

  static const _storage = FlutterSecureStorage();
  static const _defaultSavingsAccountIdKey =
      'moudabbir_default_savings_account_id';

  static Future<int?> getDefaultSavingsAccountId() async {
    final raw = await _storage.read(key: _defaultSavingsAccountIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  static Future<void> setDefaultSavingsAccountId(int accountId) {
    return _storage.write(
      key: _defaultSavingsAccountIdKey,
      value: accountId.toString(),
    );
  }
}
