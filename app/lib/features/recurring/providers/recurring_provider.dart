import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../budget/providers/budget_provider.dart';

final recurringTemplatesProvider =
    StreamProvider.autoDispose<List<RecurringTemplate>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.recurringTemplates)
        ..orderBy([(t) => OrderingTerm.asc(t.dayOfMonth)]))
      .watch();
});

final recurringNotifierProvider =
    Provider.autoDispose<RecurringNotifier>((ref) {
  return RecurringNotifier(ref.watch(databaseProvider));
});

class RecurringNotifier {
  RecurringNotifier(this._db);

  final AppDatabase _db;

  Future<void> add({
    required String name,
    required String type,
    required double amount,
    required int accountId,
    int? categoryId,
    required int dayOfMonth,
  }) {
    return _db.into(_db.recurringTemplates).insert(
          RecurringTemplatesCompanion.insert(
            name: name,
            type: type,
            amount: amount,
            accountId: accountId,
            categoryId: Value(categoryId),
            dayOfMonth: dayOfMonth,
          ),
        );
  }

  Future<void> update(RecurringTemplate template) {
    return _db.update(_db.recurringTemplates).replace(template);
  }

  Future<void> setActive(int id, bool active) {
    return (_db.update(_db.recurringTemplates)..where((t) => t.id.equals(id)))
        .write(RecurringTemplatesCompanion(active: Value(active)));
  }

  Future<void> delete(int id) {
    return (_db.delete(_db.recurringTemplates)..where((t) => t.id.equals(id)))
        .go();
  }
}

/// Runs once per app start (see `main.dart`): for every active template
/// whose due day has arrived and hasn't already fired this calendar month,
/// inserts a transaction and stamps `lastRunMonth`. No confirmation step —
/// fires silently, visible afterward like any other transaction.
final runDueRecurringTemplatesProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final templates = await (db.select(db.recurringTemplates)
        ..where((t) => t.active.equals(true)))
      .get();

  for (final template in templates) {
    final lastRun = template.lastRunMonth;
    final alreadyRanThisMonth =
        lastRun != null && lastRun.year == now.year && lastRun.month == now.month;
    if (alreadyRanThisMonth || now.day < template.dayOfMonth) continue;

    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            type: template.type,
            amount: template.amount,
            date: now,
            accountId: template.accountId,
            categoryId: Value(template.categoryId),
            note: Value(template.name),
          ),
        );
    await (db.update(db.recurringTemplates)
          ..where((t) => t.id.equals(template.id)))
        .write(RecurringTemplatesCompanion(
      lastRunMonth: Value(DateTime(now.year, now.month)),
    ));

    if (template.type == 'expense' && template.categoryId != null) {
      await checkAndNotifyOverspend(db, template.categoryId, now);
    }
  }
});
