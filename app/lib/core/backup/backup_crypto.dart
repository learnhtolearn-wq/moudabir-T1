import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Wraps/unwraps the DB passphrase with a user-chosen backup password so a
/// portable backup can be restored on a different device — or after this
/// device's Keystore/Keychain entry is gone — without ever persisting the
/// password itself anywhere. The DB file stays sqlite3mc-encrypted at rest
/// throughout; this only protects the copy of its passphrase riding along
/// inside the backup bundle.
class BackupCrypto {
  BackupCrypto._();

  static const _iterations = 210000;

  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  static final _cipher = AesGcm.with256bits();

  static Future<String> wrapKey({
    required String dbPassphrase,
    required String password,
  }) async {
    final salt = _randomBytes(16);
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final secretBox = await _cipher.encrypt(
      utf8.encode(dbPassphrase),
      secretKey: secretKey,
    );

    return jsonEncode({
      'v': 1,
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'ciphertext': base64Encode(secretBox.cipherText),
    });
  }

  /// Throws [BackupPasswordException] on a wrong password or a malformed
  /// blob — deliberately not distinguished, so a bad guess can't be used
  /// to probe which part failed.
  static Future<String> unwrapKey({
    required String wrapped,
    required String password,
  }) async {
    try {
      final map = jsonDecode(wrapped) as Map<String, dynamic>;
      final salt = base64Decode(map['salt'] as String);
      final iterations = map['iterations'] as int;

      final pbkdf2 = iterations == _iterations
          ? _pbkdf2
          : Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: iterations,
              bits: 256,
            );
      final secretKey = await pbkdf2.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );

      final secretBox = SecretBox(
        base64Decode(map['ciphertext'] as String),
        nonce: base64Decode(map['nonce'] as String),
        mac: Mac(base64Decode(map['mac'] as String)),
      );

      final plain = await _cipher.decrypt(secretBox, secretKey: secretKey);
      return utf8.decode(plain);
    } catch (_) {
      throw const BackupPasswordException();
    }
  }

  static Uint8List _randomBytes(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rand.nextInt(256)));
  }
}

class BackupPasswordException implements Exception {
  const BackupPasswordException();
}
