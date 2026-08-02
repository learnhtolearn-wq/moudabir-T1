import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/db_key_store.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Accounts, Categories, Transactions, Goals])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultCategories(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.archived);
          }
        },
      );
}

/// Opens the encrypted SQLite connection. The passphrase never touches disk
/// unencrypted — it lives in the platform Keystore/Keychain via
/// [DbKeyStore] and is only used in-memory to unlock the file.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(p.join(dbFolder.path, 'moudabbir.sqlite'));
    final passphrase = await DbKeyStore.getOrCreateKey();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$passphrase';");
        rawDb.execute('PRAGMA cipher_compatibility = 4;');
        if (!_hasCipher(rawDb)) {
          throw StateError(
            'sqlite3mc cipher not active — encrypted DB open failed.',
          );
        }
      },
    );
  });
}

bool _hasCipher(Database database) {
  final result = database.select('PRAGMA cipher_version;');
  return result.isNotEmpty;
}

Future<void> _seedDefaultCategories(AppDatabase db) async {
  const defaults = <(String, String)>[
    ('Alimentation', 'expense'),
    ('Transport', 'expense'),
    ('Logement', 'expense'),
    ('Santé', 'expense'),
    ('Loisirs', 'expense'),
    ('Salaire', 'income'),
    ('Freelance', 'income'),
    ('Autre revenu', 'income'),
  ];
  for (final (name, kind) in defaults) {
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            kind: kind,
            isSystem: const Value(true),
          ),
        );
  }
}
