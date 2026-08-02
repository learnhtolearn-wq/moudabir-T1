import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates and stores the database encryption passphrase in the
/// platform Keystore (Android) / Keychain (iOS). Never leaves the device,
/// never touches the cloud.
class DbKeyStore {
  DbKeyStore._();

  static const _storage = FlutterSecureStorage();

  static const _dbKeyName = 'moudabbir_db_passphrase';

  static Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _dbKeyName);
    if (existing != null) return existing;

    final generated = _generatePassphrase();
    await _storage.write(key: _dbKeyName, value: generated);
    return generated;
  }

  static String _generatePassphrase({int length = 32}) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}
