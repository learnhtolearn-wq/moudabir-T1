import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';
import '../security/db_key_store.dart';
import 'backup_crypto.dart';

/// Bundles the live encrypted DB file with a copy of its passphrase —
/// wrapped under a user-chosen backup password via [BackupCrypto] — into a
/// single portable archive. Unlike a raw copy of the DB file (decryptable
/// only by this device's Keystore/Keychain entry), this bundle restores
/// correctly on a different device or after a reinstall, as long as the
/// backup password is known. The backup password itself is never written
/// to disk or included in the bundle.
class BackupService {
  BackupService._();

  static const _dbEntryName = 'moudabbir.sqlite';
  static const _keyEntryName = 'key.json';

  /// Zip local-file-header signature — used to tell a portable bundle
  /// apart from a pre-bundle-format raw encrypted DB file at restore time.
  static const _zipMagic = [0x50, 0x4B, 0x03, 0x04];

  /// Copies the live DB file into a password-protected portable bundle and
  /// opens the platform share sheet so the user can save it wherever they
  /// like. Caller must close the active [AppDatabase] connection first.
  static Future<void> exportBackup(String backupPassword) async {
    final dbFile = await AppDatabase.resolveFile();
    if (!await dbFile.exists()) {
      throw StateError('No database file found to back up.');
    }

    final dbBytes = await dbFile.readAsBytes();
    final passphrase = await DbKeyStore.getOrCreateKey();
    final wrappedKey = await BackupCrypto.wrapKey(
      dbPassphrase: passphrase,
      password: backupPassword,
    );

    final archive = Archive()
      ..addFile(ArchiveFile(_dbEntryName, dbBytes.length, dbBytes))
      ..addFile(_textEntry(_keyEntryName, wrappedKey));

    final zipBytes = ZipEncoder().encode(archive);

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(
          RegExp('[:.]'),
          '-',
        );
    final backupPath = p.join(tempDir.path, 'moudabbir_backup_$stamp.mbkp');
    final backupFile = await File(backupPath).writeAsBytes(zipBytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backupFile.path)],
        subject: 'Moudabbir backup',
      ),
    );
  }

  /// Lets the user pick a previously exported backup, unwraps the DB
  /// passphrase with [backupPassword], and overwrites the live DB file and
  /// stored passphrase with the restored ones. Returns false if the user
  /// cancelled the picker. Throws [BackupPasswordException] on a wrong
  /// password. Caller must close the active [AppDatabase] connection
  /// first, and reinitialize it (e.g. `ref.invalidate(databaseProvider)`)
  /// after this returns true.
  static Future<bool> importBackup(String backupPassword) async {
    // withData: true — some SAF providers (seen on Samsung's file manager)
    // return a null `path` for the picked file with no error, which read
    // as a silent no-op restore. Bytes are always populated, so write
    // those directly instead of relying on a filesystem path existing.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null) return false;

    final picked = result.files.single;
    final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
    final dbFile = await AppDatabase.resolveFile();

    if (!_looksLikeZipBundle(bytes)) {
      // Pre-bundle-format backup: a raw copy of the encrypted DB file,
      // decryptable only by this device's still-current Keystore
      // passphrase. Restore as-is for backward compatibility.
      await dbFile.writeAsBytes(bytes, flush: true);
      return true;
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final dbEntry = archive.findFile(_dbEntryName);
    final keyEntry = archive.findFile(_keyEntryName);
    if (dbEntry == null || keyEntry == null) {
      throw const FormatException('Not a Moudabbir backup file.');
    }

    final wrappedKey = utf8.decode(keyEntry.content as List<int>);
    final passphrase = await BackupCrypto.unwrapKey(
      wrapped: wrappedKey,
      password: backupPassword,
    );

    await dbFile.writeAsBytes(dbEntry.content as List<int>, flush: true);
    await DbKeyStore.setKey(passphrase);
    return true;
  }

  static ArchiveFile _textEntry(String name, String text) {
    final bytes = utf8.encode(text);
    return ArchiveFile(name, bytes.length, bytes);
  }

  static bool _looksLikeZipBundle(List<int> bytes) {
    if (bytes.length < _zipMagic.length) return false;
    for (var i = 0; i < _zipMagic.length; i++) {
      if (bytes[i] != _zipMagic[i]) return false;
    }
    return true;
  }
}
