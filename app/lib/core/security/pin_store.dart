import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores a salted hash of the user's app-lock PIN — never the PIN itself.
class PinStore {
  PinStore._();

  static const _storage = FlutterSecureStorage();

  static const _pinHashKey = 'moudabbir_pin_hash';
  static const _pinSaltKey = 'moudabbir_pin_salt';

  static Future<bool> hasPin() async {
    return await _storage.read(key: _pinHashKey) != null;
  }

  static Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
  }

  static Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final storedHash = await _storage.read(key: _pinHashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(pin, salt) == storedHash;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
  }

  static String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  static String _randomSalt() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return sha256.convert(utf8.encode('$now-moudabbir')).toString();
  }
}
