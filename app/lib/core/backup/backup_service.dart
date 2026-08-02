import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';

/// Exports/imports the raw encrypted DB file. The file is only decryptable
/// on this device — the passphrase lives in the platform Keystore/Keychain
/// ([DbKeyStore]) and is never included in the backup. This makes backups a
/// same-device safety net (undo a bad bulk edit, survive an app data wipe
/// that doesn't also clear Keystore), not a cross-device migration tool.
class BackupService {
  BackupService._();

  /// Copies the live DB file to a timestamped temp file and opens the
  /// platform share sheet so the user can save it wherever they like.
  /// Caller must close the active [AppDatabase] connection before calling.
  static Future<void> exportBackup() async {
    final dbFile = await AppDatabase.resolveFile();
    if (!await dbFile.exists()) {
      throw StateError('No database file found to back up.');
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(
          RegExp('[:.]'),
          '-',
        );
    final backupPath = p.join(tempDir.path, 'moudabbir_backup_$stamp.sqlite');
    final backupFile = await dbFile.copy(backupPath);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(backupFile.path)],
        subject: 'Moudabbir backup',
      ),
    );
  }

  /// Lets the user pick a previously exported backup file and overwrites
  /// the live DB file with it. Returns false if the user cancelled the
  /// picker. Caller must close the active [AppDatabase] connection before
  /// calling, and reinitialize it (e.g. `ref.invalidate(databaseProvider)`)
  /// after this returns true.
  static Future<bool> importBackup() async {
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
    final dbFile = await AppDatabase.resolveFile();

    if (picked.bytes != null) {
      await dbFile.writeAsBytes(picked.bytes!, flush: true);
    } else if (picked.path != null) {
      await File(picked.path!).copy(dbFile.path);
    } else {
      return false;
    }
    return true;
  }
}
