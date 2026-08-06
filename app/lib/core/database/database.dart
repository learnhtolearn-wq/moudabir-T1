import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/db_key_store.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Accounts, Categories, Transactions, Goals, BudgetTargets, RecurringTemplates],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Filename of the encrypted DB file on disk — shared with [BackupService]
  /// so backup/restore and the live connection never disagree on the path.
  static const fileName = 'moudabir.sqlite';

  static Future<File> resolveFile() async {
    final dbFolder = await getApplicationSupportDirectory();
    return File(p.join(dbFolder.path, fileName));
  }

  @override
  int get schemaVersion => 6;

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
          if (from < 3) {
            await m.addColumn(goals, goals.archived);
          }
          if (from < 4) {
            await _migrateSeedCategoryNamesToKeys(this);
          }
          if (from < 5) {
            await m.createTable(budgetTargets);
            await m.createTable(recurringTemplates);
          }
          if (from < 6) {
            await _backfillSeedCategoryIcons(this);
          }
        },
      );
}

/// Opens the encrypted SQLite connection. The passphrase never touches disk
/// unencrypted — it lives in the platform Keystore/Keychain via
/// [DbKeyStore] and is only used in-memory to unlock the file.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await AppDatabase.resolveFile();
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
  final result = database.select('PRAGMA cipher;');
  return result.isNotEmpty;
}

/// Names are i18n translation keys (`categories.seed.*`), not display text —
/// resolved via `.tr()` at every display site so system categories follow
/// the active locale. User-created categories store free text instead;
/// `.tr()` on a key it doesn't recognize just returns the text unchanged.
/// icon/color are the [Categories.iconName]/[Categories.colorHex] pair
/// used by `CategoryIconAvatar` — sourced from the Figma "icon/*" set and
/// the "Métal & Sable" palette (see `AppColors`).
const _seedCategoryDefaults = <(String, String, String, String)>[
  ('categories.seed.food', 'expense', 'basket', 'B23B2E'),
  ('categories.seed.transport', 'expense', 'car', 'BD741D'),
  ('categories.seed.housing', 'expense', 'home', '6F6A5C'),
  ('categories.seed.health', 'expense', 'shield', '8A5A2B'),
  ('categories.seed.leisure', 'expense', 'sparkle', 'E4603E'),
  ('categories.seed.salary', 'income', 'briefcase', 'C9A227'),
  ('categories.seed.freelance', 'income', 'laptop', 'BF8F2E'),
  ('categories.seed.other_income', 'income', 'trend', '7A5A12'),
];

Future<void> _seedDefaultCategories(AppDatabase db) async {
  for (final (name, kind, icon, color) in _seedCategoryDefaults) {
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            kind: kind,
            isSystem: const Value(true),
            iconName: Value(icon),
            colorHex: Value(color),
          ),
        );
  }
}

/// Existing installs (schema v1-v5) seeded system categories before
/// icon/color existed — backfill them by name so upgraded installs pick up
/// the same icons new installs get from [_seedDefaultCategories].
Future<void> _backfillSeedCategoryIcons(AppDatabase db) async {
  for (final (name, _, icon, color) in _seedCategoryDefaults) {
    await (db.update(db.categories)
          ..where((c) => c.name.equals(name) & c.isSystem.equals(true)))
        .write(CategoriesCompanion(
      iconName: Value(icon),
      colorHex: Value(color),
    ));
  }
}

/// Existing installs (schema v1-v3) seeded system categories with hardcoded
/// French display text instead of translation keys — rename those rows to
/// match the new `categories.seed.*` key scheme.
const _seedCategoryNameMigration = <String, String>{
  'Alimentation': 'categories.seed.food',
  'Transport': 'categories.seed.transport',
  'Logement': 'categories.seed.housing',
  'Santé': 'categories.seed.health',
  'Loisirs': 'categories.seed.leisure',
  'Salaire': 'categories.seed.salary',
  'Freelance': 'categories.seed.freelance',
  'Autre revenu': 'categories.seed.other_income',
};

Future<void> _migrateSeedCategoryNamesToKeys(AppDatabase db) async {
  for (final entry in _seedCategoryNameMigration.entries) {
    await (db.update(db.categories)
          ..where((c) => c.name.equals(entry.key) & c.isSystem.equals(true)))
        .write(CategoriesCompanion(name: Value(entry.value)));
  }
}
