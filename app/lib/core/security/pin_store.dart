import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores a salted hash of the user's app-lock PIN — never the PIN itself.
/// Also tracks failed attempts to enforce a lockout, since the PIN is only
/// 4-6 digits and would otherwise be brute-forceable at unlimited speed.
///
/// A one-time recovery code (shown once, hashed like the PIN) is the offline
/// fallback for a forgotten PIN — there's no server to email/SMS a reset
/// link to, so this and biometric unlock are the only recovery paths.
class PinStore {
  PinStore._();

  static const _storage = FlutterSecureStorage();

  static const _pinHashKey = 'moudabbir_pin_hash';
  static const _pinSaltKey = 'moudabbir_pin_salt';
  static const _failedAttemptsKey = 'moudabbir_pin_failed_attempts';
  static const _lockedUntilKey = 'moudabbir_pin_locked_until';
  static const _recoveryHashKey = 'moudabbir_recovery_hash';
  static const _recoverySaltKey = 'moudabbir_recovery_salt';

  /// After this many consecutive failures, the PIN field locks out.
  static const maxAttempts = 5;
  static const lockoutDuration = Duration(seconds: 30);

  static Future<bool> hasPin() async {
    return await _storage.read(key: _pinHashKey) != null;
  }

  /// Sets/changes the PIN without touching the recovery code. Used by the
  /// "Change PIN" flow, where the caller already proved PIN knowledge.
  static Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    final hash = _hash(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
    await _resetAttempts();
  }

  static Future<bool> hasRecoveryCode() async {
    return await _storage.read(key: _recoveryHashKey) != null;
  }

  /// Generates a fresh recovery code, stores its hash, and returns the
  /// plaintext code so the caller can show it to the user exactly once.
  /// Call this at initial PIN setup and again after every successful
  /// recovery-code reset — reusing the same code indefinitely would mean a
  /// single leaked code stays valid forever.
  static Future<String> regenerateRecoveryCode() async {
    final code = _generateRecoveryCode();
    final salt = _randomSalt();
    final hash = _hash(_normalizeCode(code), salt);
    await _storage.write(key: _recoverySaltKey, value: salt);
    await _storage.write(key: _recoveryHashKey, value: hash);
    return code;
  }

  static Future<bool> verifyRecoveryCode(String code) async {
    final salt = await _storage.read(key: _recoverySaltKey);
    final storedHash = await _storage.read(key: _recoveryHashKey);
    if (salt == null || storedHash == null) return false;
    return _hash(_normalizeCode(code), salt) == storedHash;
  }

  static String _normalizeCode(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  // Crockford-style charset (no 0/O/1/I/L) so a handwritten code can't be
  // misread; grouped XXXX-XXXX-XXXX for the same reason.
  static const _recoveryChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String _generateRecoveryCode() {
    final rand = Random.secure();
    final raw = List.generate(
      12,
      (_) => _recoveryChars[rand.nextInt(_recoveryChars.length)],
    ).join();
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8, 12)}';
  }

  /// Returns the remaining lockout time, or null if not currently locked.
  static Future<Duration?> lockoutRemaining() async {
    final lockedUntilRaw = await _storage.read(key: _lockedUntilKey);
    if (lockedUntilRaw == null) return null;
    final lockedUntil = DateTime.tryParse(lockedUntilRaw);
    if (lockedUntil == null) return null;
    final remaining = lockedUntil.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Returns false immediately (without checking the PIN) while locked out.
  static Future<bool> verifyPin(String pin) async {
    if (await lockoutRemaining() != null) return false;

    final salt = await _storage.read(key: _pinSaltKey);
    final storedHash = await _storage.read(key: _pinHashKey);
    if (salt == null || storedHash == null) return false;

    final ok = _hash(pin, salt) == storedHash;
    if (ok) {
      await _resetAttempts();
    } else {
      await _recordFailedAttempt();
    }
    return ok;
  }

  static Future<void> _recordFailedAttempt() async {
    final current =
        int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ?? 0;
    final attempts = current + 1;
    await _storage.write(key: _failedAttemptsKey, value: attempts.toString());
    if (attempts >= maxAttempts) {
      final lockedUntil = DateTime.now().add(lockoutDuration);
      await _storage.write(
        key: _lockedUntilKey,
        value: lockedUntil.toIso8601String(),
      );
      await _storage.write(key: _failedAttemptsKey, value: '0');
    }
  }

  static Future<void> _resetAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockedUntilKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _recoveryHashKey);
    await _storage.delete(key: _recoverySaltKey);
    await _resetAttempts();
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
