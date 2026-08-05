import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

final accountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.accounts)
        ..where((a) => a.archived.equals(false))
        ..orderBy([(a) => OrderingTerm.asc(a.name)]))
      .watch();
});

/// Whether at least one non-archived account exists. Derived from
/// [accountsProvider] so the "archived == false" filter has a single source
/// of truth. Deliberately NOT autoDispose: the router reads this on every
/// navigation via `ref.read`, and keeping it alive for the app session means
/// that read is served from Riverpod's cache (and kept fresh by the
/// underlying Drift stream) instead of re-issuing a DB query each time.
final hasAnyAccountProvider = Provider<AsyncValue<bool>>((ref) {
  final accounts = ref.watch(accountsProvider);
  return accounts.whenData((list) => list.isNotEmpty);
});

final accountsNotifierProvider =
    Provider.autoDispose<AccountsNotifier>((ref) {
  return AccountsNotifier(ref.watch(databaseProvider));
});

class AccountsNotifier {
  AccountsNotifier(this._db);

  final AppDatabase _db;

  Future<void> add({
    required String name,
    required String type,
    required String currency,
    required double initialBalance,
    String? colorHex,
    String? iconName,
  }) {
    return _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            name: name,
            type: type,
            currency: Value(currency),
            initialBalance: Value(initialBalance),
            colorHex: Value(colorHex),
            iconName: Value(iconName),
          ),
        );
  }

  Future<void> update(Account account) {
    return _db.update(_db.accounts).replace(account);
  }

  Future<void> archive(int id) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
        .write(const AccountsCompanion(archived: Value(true)));
  }
}
