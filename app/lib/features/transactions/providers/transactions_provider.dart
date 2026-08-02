import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

/// One row per transaction, joined to its account and (optional) category
/// so the list screen doesn't need N+1 lookups.
class TransactionWithDetails {
  TransactionWithDetails({
    required this.transaction,
    required this.account,
    this.toAccount,
    this.category,
  });

  final Transaction transaction;
  final Account account;
  final Account? toAccount;
  final Category? category;
}

final transactionsProvider =
    StreamProvider.autoDispose<List<TransactionWithDetails>>((ref) {
  final db = ref.watch(databaseProvider);

  final account = db.alias(db.accounts, 'account');
  final toAccount = db.alias(db.accounts, 'toAccount');

  final query = db.select(db.transactions).join([
    innerJoin(account, account.id.equalsExp(db.transactions.accountId)),
    leftOuterJoin(
      toAccount,
      toAccount.id.equalsExp(db.transactions.toAccountId),
    ),
    leftOuterJoin(
      db.categories,
      db.categories.id.equalsExp(db.transactions.categoryId),
    ),
  ])
    ..where(db.transactions.archived.equals(false))
    ..orderBy([OrderingTerm.desc(db.transactions.date)]);

  return query.watch().map((rows) {
    return rows.map((row) {
      return TransactionWithDetails(
        transaction: row.readTable(db.transactions),
        account: row.readTable(account),
        toAccount: row.readTableOrNull(toAccount),
        category: row.readTableOrNull(db.categories),
      );
    }).toList();
  });
});

/// Live balance for one account: initialBalance plus/minus every
/// non-archived transaction that touches it. Computed on read (not a
/// stored column) so it can never drift from the transaction ledger.
final accountBalanceProvider =
    StreamProvider.autoDispose.family<double, int>((ref, accountId) {
  final db = ref.watch(databaseProvider);

  final accountQuery = db.select(db.accounts)
    ..where((a) => a.id.equals(accountId));
  final txnQuery = db.select(db.transactions)
    ..where((t) =>
        t.archived.equals(false) &
        (t.accountId.equals(accountId) | t.toAccountId.equals(accountId)));

  final accountStream = accountQuery.watchSingle();
  final txnStream = txnQuery.watch();

  return accountStream.asyncExpand((account) {
    return txnStream.map((txns) {
      var balance = account.initialBalance;
      for (final t in txns) {
        switch (t.type) {
          case 'income':
            balance += t.amount;
          case 'expense':
            balance -= t.amount;
          case 'transfer':
            if (t.accountId == accountId) balance -= t.amount;
            if (t.toAccountId == accountId) balance += t.amount;
        }
      }
      return balance;
    });
  });
});

final transactionsNotifierProvider =
    Provider.autoDispose<TransactionsNotifier>((ref) {
  return TransactionsNotifier(ref.watch(databaseProvider));
});

class TransactionsNotifier {
  TransactionsNotifier(this._db);

  final AppDatabase _db;

  Future<void> add({
    required String type,
    required double amount,
    required DateTime date,
    required int accountId,
    int? toAccountId,
    int? categoryId,
    String? note,
  }) {
    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            type: type,
            amount: amount,
            date: date,
            accountId: accountId,
            toAccountId: Value(toAccountId),
            categoryId: Value(categoryId),
            note: Value(note),
          ),
        );
  }

  Future<void> update(Transaction transaction) {
    return _db.update(_db.transactions).replace(transaction);
  }

  Future<void> archive(int id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
        .write(const TransactionsCompanion(archived: Value(true)));
  }
}
