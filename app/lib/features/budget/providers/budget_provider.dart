import 'package:drift/drift.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/notifications/notification_service.dart';

String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

class BudgetTargetWithCategory {
  BudgetTargetWithCategory({required this.target, required this.category});

  final BudgetTarget target;
  final Category category;
}

/// This month's [BudgetTargets] rows, joined to their category.
final budgetTargetsProvider =
    StreamProvider.autoDispose<List<BudgetTargetWithCategory>>((ref) {
  final db = ref.watch(databaseProvider);
  final month = monthKey(DateTime.now());

  final query = db.select(db.budgetTargets).join([
    innerJoin(
      db.categories,
      db.categories.id.equalsExp(db.budgetTargets.categoryId),
    ),
  ])
    ..where(db.budgetTargets.month.equals(month));

  return query.watch().map((rows) => rows
      .map((row) => BudgetTargetWithCategory(
            target: row.readTable(db.budgetTargets),
            category: row.readTable(db.categories),
          ))
      .toList());
});

/// Sum of this-month non-archived expense transactions for [categoryId].
final categorySpentProvider =
    StreamProvider.autoDispose.family<double, int>((ref, categoryId) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);

  final query = db.select(db.transactions)
    ..where((t) =>
        t.archived.equals(false) &
        t.categoryId.equals(categoryId) &
        t.type.equals('expense') &
        t.date.isBiggerOrEqualValue(monthStart) &
        t.date.isSmallerThanValue(monthEnd));

  return query
      .watch()
      .map((rows) => rows.fold<double>(0, (sum, t) => sum + t.amount));
});

/// One-shot sum of this-month non-archived expense transactions for
/// [categoryId], in `[monthStart, monthEnd)`. Shared by call sites that need
/// a single read rather than a live stream (see [categorySpentProvider] for
/// the reactive `.watch()` equivalent used by the dashboard).
Future<double> _spentForCategory(
  AppDatabase db,
  int categoryId,
  DateTime monthStart,
  DateTime monthEnd,
) async {
  final rows = await (db.select(db.transactions)
        ..where((t) =>
            t.archived.equals(false) &
            t.categoryId.equals(categoryId) &
            t.type.equals('expense') &
            t.date.isBiggerOrEqualValue(monthStart) &
            t.date.isSmallerThanValue(monthEnd)))
      .get();
  return rows.fold<double>(0, (sum, t) => sum + t.amount);
}

/// This month's sweep-eligible categories with their computed leftover —
/// drives both the Sweep section's list and its empty state.
final sweepEligibleProvider = StreamProvider.autoDispose<
    List<({BudgetTargetWithCategory row, double leftover})>>((ref) {
  final db = ref.watch(databaseProvider);
  final month = monthKey(DateTime.now());

  final query = db.select(db.budgetTargets).join([
    innerJoin(
      db.categories,
      db.categories.id.equalsExp(db.budgetTargets.categoryId),
    ),
  ])
    ..where(
      db.budgetTargets.month.equals(month) &
          db.budgetTargets.sweepToSavings.equals(true),
    );

  return query.watch().asyncMap((rows) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final result = <({BudgetTargetWithCategory row, double leftover})>[];

    for (final joined in rows) {
      final target = joined.readTable(db.budgetTargets);
      final category = joined.readTable(db.categories);
      final spent =
          await _spentForCategory(db, category.id, monthStart, monthEnd);
      final leftover = target.targetAmount - spent;
      if (leftover > 0) {
        result.add((
          row: BudgetTargetWithCategory(target: target, category: category),
          leftover: leftover,
        ));
      }
    }
    return result;
  });
});

final budgetNotifierProvider = Provider.autoDispose<BudgetNotifier>((ref) {
  return BudgetNotifier(ref.watch(databaseProvider));
});

class BudgetNotifier {
  BudgetNotifier(this._db);

  final AppDatabase _db;

  /// Upserts one [BudgetTargets] row per entry for the current month.
  Future<void> saveAllocation({
    required Map<int, double> targetByCategory,
    required Map<int, bool> sweepByCategory,
  }) async {
    final month = monthKey(DateTime.now());
    for (final categoryId in targetByCategory.keys) {
      final amount = targetByCategory[categoryId]!;
      final sweep = sweepByCategory[categoryId] ?? false;
      final existing = await (_db.select(_db.budgetTargets)
            ..where((b) =>
                b.categoryId.equals(categoryId) & b.month.equals(month)))
          .getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.budgetTargets).insert(
              BudgetTargetsCompanion.insert(
                categoryId: categoryId,
                month: month,
                targetAmount: amount,
                sweepToSavings: Value(sweep),
              ),
            );
      } else {
        await (_db.update(_db.budgetTargets)
              ..where((b) => b.id.equals(existing.id)))
            .write(BudgetTargetsCompanion(
          targetAmount: Value(amount),
          sweepToSavings: Value(sweep),
        ));
      }
    }
  }

  /// Records the sweep as a real transfer from [fromAccountId] to
  /// [toAccountId], then zeroes the category's remaining target (sets it to
  /// `spentSoFar`) so it can't be swept twice this month.
  Future<void> sweep({
    required BudgetTarget target,
    required double leftover,
    required double spentSoFar,
    required int fromAccountId,
    required int toAccountId,
    required String note,
  }) async {
    await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            type: 'transfer',
            amount: leftover,
            date: DateTime.now(),
            accountId: fromAccountId,
            toAccountId: Value(toAccountId),
            note: Value(note),
          ),
        );
    await (_db.update(_db.budgetTargets)..where((b) => b.id.equals(target.id)))
        .write(BudgetTargetsCompanion(targetAmount: Value(spentSoFar)));
  }
}

/// Edge-triggered 90%/100% overspend check — call after any transaction
/// insert that touches a budgeted expense category (quick-add, full form,
/// recurring auto-log). Fires each threshold once per category per month.
Future<void> checkAndNotifyOverspend(
  AppDatabase db,
  int? categoryId,
  DateTime date,
) async {
  if (categoryId == null) return;
  final month = monthKey(date);

  final target = await (db.select(db.budgetTargets)
        ..where(
            (b) => b.categoryId.equals(categoryId) & b.month.equals(month)))
      .getSingleOrNull();
  if (target == null || target.targetAmount <= 0) return;

  final category =
      await (db.select(db.categories)..where((c) => c.id.equals(categoryId)))
          .getSingle();

  final monthStart = DateTime(date.year, date.month, 1);
  final monthEnd = DateTime(date.year, date.month + 1, 1);
  final spent = await _spentForCategory(db, categoryId, monthStart, monthEnd);
  final ratio = spent / target.targetAmount;

  // Notification ids offset by 2000 so they never collide with the daily
  // reminder (1) or goal nudges (1000 + goal.id) — see NotificationService.
  if (ratio >= 1.0 && !target.notified100) {
    await NotificationService.showOneShot(
      id: 2000 + target.id,
      title:
          'notifications.budget_100'.tr(namedArgs: {'category': category.name.tr()}),
    );
    await (db.update(db.budgetTargets)..where((b) => b.id.equals(target.id)))
        .write(const BudgetTargetsCompanion(notified100: Value(true)));
  } else if (ratio >= 0.9 && !target.notified90) {
    await NotificationService.showOneShot(
      id: 2000 + target.id,
      title:
          'notifications.budget_90'.tr(namedArgs: {'category': category.name.tr()}),
    );
    await (db.update(db.budgetTargets)..where((b) => b.id.equals(target.id)))
        .write(const BudgetTargetsCompanion(notified90: Value(true)));
  }
}
