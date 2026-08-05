# Hybrid Budget Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Moudabbir from pure after-the-fact logging to a hybrid budget model — salary allocation into per-category targets, auto-logged recurring bills, a fast quick-add flow, and a manual per-category leftover sweep into savings.

**Architecture:** Two new Drift tables (`BudgetTargets`, `RecurringTemplates`) alongside Sprint 0's schema. Two new feature folders (`features/budget`, `features/recurring`) follow the existing provider/screen/form-screen pattern used by `features/goals`. Recurring auto-log runs once per app start via a `FutureProvider`, mirroring how `notificationBootstrapProvider` already runs at startup in `main.dart`. New screens (`BudgetScreen`, `RecurringTemplatesScreen`) are reached via `Navigator.of(context).push(MaterialPageRoute(...))` from Settings/Dashboard — **not** new `go_router` routes — matching how `AccountsScreen`, `CategoriesScreen`, and `ChangePinScreen` are already reached from Settings. (The spec's "New routes added to the go_router shell" section is superseded by this: the codebase has no precedent for pushing feature screens as router routes, and introducing one here would be an inconsistent one-off.)

**Sweep source account:** per user decision (this session), the sweep dialog asks the user to pick the "from" account each time (defaulting to nothing pre-selected — the account list minus the savings account), rather than relying on a second stored default. Only the "to" account (`defaultSavingsAccountId`) is a persisted one-time setting, per spec.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, easy_localization, flutter_local_notifications. No test framework is set up in this project (`app/test/` doesn't exist) — verification is `flutter analyze` plus manual device/emulator checks, matching every prior sprint.

---

## Task 1: New Drift tables — `BudgetTargets`, `RecurringTemplates`

**Files:**
- Modify: `app/lib/core/database/tables.dart`
- Modify: `app/lib/core/database/database.dart`

- [ ] **Step 1: Add the two new tables**

Append to `app/lib/core/database/tables.dart`:

```dart
/// Per-month spending target per category (Hybrid Budget Model).
class BudgetTargets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get month => text()(); // 'YYYY-MM', one row per category per month
  RealColumn get targetAmount => real()();
  BoolColumn get sweepToSavings =>
      boolean().withDefault(const Constant(false))();
  // Edge-triggered overspend notification guards — reset implicitly since a
  // new month gets a fresh row (no explicit month-rollover step needed).
  BoolColumn get notified90 => boolean().withDefault(const Constant(false))();
  BoolColumn get notified100 =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Recurring bill/income templates that auto-create transactions on their due day.
class RecurringTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text()(); // income | expense
  RealColumn get amount => real()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  // 1-28 only — every month has at least 28 days, so no clamping is needed.
  IntColumn get dayOfMonth => integer()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastRunMonth => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 2: Register the tables and bump the schema version**

In `app/lib/core/database/database.dart`, change the `@DriftDatabase` annotation:

```dart
@DriftDatabase(
  tables: [Accounts, Categories, Transactions, Goals, BudgetTargets, RecurringTemplates],
)
class AppDatabase extends _$AppDatabase {
```

Change `schemaVersion`:

```dart
  @override
  int get schemaVersion => 5;
```

Add a migration step inside `migration`'s `onUpgrade`:

```dart
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
        },
```

- [ ] **Step 3: Regenerate the Drift code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: `app/lib/core/database/database.g.dart` regenerates with `BudgetTarget`/`BudgetTargets`/`BudgetTargetsCompanion` and `RecurringTemplate`/`RecurringTemplates`/`RecurringTemplatesCompanion` classes, no errors.

- [ ] **Step 4: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/database/tables.dart app/lib/core/database/database.dart app/lib/core/database/database.g.dart
git commit -m "feat: add BudgetTargets and RecurringTemplates tables (schema v5)"
```

---

## Task 2: Default savings account setting

**Files:**
- Create: `app/lib/core/settings/settings_prefs.dart`

- [ ] **Step 1: Write the prefs class**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small persisted app settings beyond PIN/notifications — reuses
/// [FlutterSecureStorage] like [NotificationPrefs] rather than adding a new
/// storage dependency for one value.
class SettingsPrefs {
  SettingsPrefs._();

  static const _storage = FlutterSecureStorage();
  static const _defaultSavingsAccountIdKey =
      'moudabbir_default_savings_account_id';

  static Future<int?> getDefaultSavingsAccountId() async {
    final raw = await _storage.read(key: _defaultSavingsAccountIdKey);
    return raw == null ? null : int.tryParse(raw);
  }

  static Future<void> setDefaultSavingsAccountId(int accountId) {
    return _storage.write(
      key: _defaultSavingsAccountIdKey,
      value: accountId.toString(),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/settings/settings_prefs.dart
git commit -m "feat: add SettingsPrefs for default savings account"
```

---

## Task 3: Notification service — generic one-shot notification

**Files:**
- Modify: `app/lib/core/notifications/notification_service.dart`

- [ ] **Step 1: Add a `showOneShot` method**

Add to `NotificationService` in `app/lib/core/notifications/notification_service.dart` (after `cancelAll`):

```dart
  /// Fires an immediate, non-scheduled notification — used for budget
  /// threshold nudges and sweep confirmations. Reuses the same channel as
  /// the daily reminder / goal nudges.
  static Future<void> showOneShot({
    required int id,
    required String title,
    String body = '',
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add app/lib/core/notifications/notification_service.dart
git commit -m "feat: add NotificationService.showOneShot for immediate nudges"
```

---

## Task 4: Recurring templates provider + auto-run

**Files:**
- Create: `app/lib/features/recurring/providers/recurring_provider.dart`

- [ ] **Step 1: Write the provider file**

```dart
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
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: errors referencing `checkAndNotifyOverspend`/`budget_provider.dart` (Task 5 not done yet) — that's expected at this point; do not commit yet. Continue to Task 5 first, then re-run.

---

## Task 5: Budget provider — targets, spend calc, allocation, sweep, overspend check

**Files:**
- Create: `app/lib/features/budget/providers/budget_provider.dart`

- [ ] **Step 1: Write the provider file**

```dart
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
      final spentRows = await (db.select(db.transactions)
            ..where((t) =>
                t.archived.equals(false) &
                t.categoryId.equals(category.id) &
                t.type.equals('expense') &
                t.date.isBiggerOrEqualValue(monthStart) &
                t.date.isSmallerThanValue(monthEnd)))
          .get();
      final spent = spentRows.fold<double>(0, (sum, t) => sum + t.amount);
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
  final spentRows = await (db.select(db.transactions)
        ..where((t) =>
            t.archived.equals(false) &
            t.categoryId.equals(categoryId) &
            t.type.equals('expense') &
            t.date.isBiggerOrEqualValue(monthStart) &
            t.date.isSmallerThanValue(monthEnd)))
      .get();
  final spent = spentRows.fold<double>(0, (sum, t) => sum + t.amount);
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
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors (this also resolves the Task 4 error from `checkAndNotifyOverspend`).

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/budget/providers/budget_provider.dart app/lib/features/recurring/providers/recurring_provider.dart
git commit -m "feat: add budget targets/sweep/overspend and recurring auto-run providers"
```

---

## Task 6: Wire recurring auto-run into app startup

**Files:**
- Modify: `app/lib/main.dart`

- [ ] **Step 1: Watch the auto-run provider alongside the notification bootstrap**

In `app/lib/main.dart`, add the import:

```dart
import 'features/recurring/providers/recurring_provider.dart';
```

In `_MoudabbirAppState.build`, next to the existing bootstrap watch:

```dart
    final router = ref.watch(appRouterProvider);
    // Side-effect only: reschedules reminders left enabled from a prior
    // session. Result is intentionally unused.
    ref.watch(notificationBootstrapProvider);
    // Side-effect only: fires any recurring bills/income due this month
    // that haven't already run. Result is intentionally unused.
    ref.watch(runDueRecurringTemplatesProvider);
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add app/lib/main.dart
git commit -m "feat: run due recurring templates on app start"
```

---

## Task 7: Recurring templates screen + form

**Files:**
- Create: `app/lib/features/recurring/recurring_templates_screen.dart`
- Create: `app/lib/features/recurring/recurring_form_screen.dart`

- [ ] **Step 1: Write the list screen**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/recurring_provider.dart';
import 'recurring_form_screen.dart';

class RecurringTemplatesScreen extends ConsumerWidget {
  const RecurringTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('recurring.title'.tr())),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('recurring.error'.tr())),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(child: Text('recurring.empty'.tr()));
          }
          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                title: Text(template.name),
                subtitle: Text(
                  'recurring.day_of_month_subtitle'
                      .tr(namedArgs: {'day': '${template.dayOfMonth}'}),
                ),
                trailing: Switch(
                  value: template.active,
                  onChanged: (v) =>
                      ref.read(recurringNotifierProvider).setActive(template.id, v),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecurringFormScreen(template: template),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecurringFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 2: Write the add/edit form screen**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../accounts/providers/accounts_provider.dart';
import '../categories/providers/categories_provider.dart';
import '../transactions/transaction_form_screen.dart' show transactionTypes;
import 'providers/recurring_provider.dart';

class RecurringFormScreen extends ConsumerStatefulWidget {
  const RecurringFormScreen({super.key, this.template});

  final RecurringTemplate? template;

  @override
  ConsumerState<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends ConsumerState<RecurringFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dayController;
  late String _type;
  int? _accountId;
  int? _categoryId;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    _amountController =
        TextEditingController(text: t != null ? t.amount.toString() : '');
    _dayController =
        TextEditingController(text: t != null ? t.dayOfMonth.toString() : '');
    _type = t?.type ?? 'expense';
    _accountId = t?.accountId;
    _categoryId = t?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;

    final notifier = ref.read(recurringNotifierProvider);
    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final day = int.parse(_dayController.text.trim());

    if (_isEditing) {
      await notifier.update(
        widget.template!.copyWith(
          name: name,
          type: _type,
          amount: amount,
          accountId: _accountId!,
          categoryId: drift.Value(_categoryId),
          dayOfMonth: day,
        ),
      );
    } else {
      await notifier.add(
        name: name,
        type: _type,
        amount: amount,
        accountId: _accountId!,
        categoryId: _categoryId,
        dayOfMonth: day,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('recurring.delete_title'.tr()),
        content: Text('recurring.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(recurringNotifierProvider).delete(widget.template!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'recurring.edit_title'.tr() : 'recurring.add_title'.tr()),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'recurring.name'.tr()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'common.required'.tr() : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: transactionTypes
                  .where((t) => t != 'transfer')
                  .map((t) => ButtonSegment(value: t, label: Text('transactions.type.$t'.tr())))
                  .toList(),
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => Text('accounts.error'.tr()),
              data: (accounts) => DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: InputDecoration(labelText: 'transactions.account'.tr()),
                items: accounts
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'common.required'.tr() : null,
              ),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (categories) {
                final filtered = categories.where((c) => c.kind == _type).toList();
                return DropdownButtonFormField<int?>(
                  initialValue: filtered.any((c) => c.id == _categoryId) ? _categoryId : null,
                  decoration: InputDecoration(labelText: 'transactions.category'.tr()),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text('goals.no_linked_account'.tr())),
                    ...filtered.map(
                      (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name.tr())),
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'transactions.amount'.tr()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'common.required'.tr();
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'common.invalid_number'.tr();
                return parsed <= 0 ? 'transactions.amount_positive'.tr() : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dayController,
              decoration: InputDecoration(labelText: 'recurring.day_of_month'.tr()),
              keyboardType: TextInputType.number,
              validator: (v) {
                final parsed = int.tryParse(v?.trim() ?? '');
                if (parsed == null) return 'common.invalid_number'.tr();
                return (parsed < 1 || parsed > 28) ? 'common.invalid_number'.tr() : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: Text('common.save'.tr())),
          ],
        ),
      ),
    );
  }
}
```

Add the missing `drift` import used by `copyWith`'s `Value(...)` call:

```dart
import 'package:drift/drift.dart' as drift;
```

(placed with the other imports at the top of the file, alongside `package:easy_localization/...`).

- [ ] **Step 3: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/recurring/recurring_templates_screen.dart app/lib/features/recurring/recurring_form_screen.dart
git commit -m "feat: add recurring templates list + add/edit screens"
```

---

## Task 8: Budget screen — allocate + sweep

**Files:**
- Create: `app/lib/features/budget/budget_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/settings/settings_prefs.dart';
import '../accounts/providers/accounts_provider.dart';
import '../categories/providers/categories_provider.dart';
import '../dashboard/providers/dashboard_provider.dart';
import 'providers/budget_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, bool> _sweepFlags = {};
  bool _initialized = false;

  final _newCategoryController = TextEditingController();
  bool _addingCategory = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    await ref.read(categoriesNotifierProvider).add(name: name, kind: 'expense');
    _newCategoryController.clear();
    setState(() => _addingCategory = false);
  }

  TextEditingController _controllerFor(int categoryId, double initial) {
    return _controllers.putIfAbsent(
      categoryId,
      () => TextEditingController(text: initial > 0 ? initial.toString() : ''),
    );
  }

  Future<void> _saveAllocation(List<Category> expenseCategories) async {
    final targetByCategory = <int, double>{
      for (final c in expenseCategories)
        c.id: double.tryParse(_controllers[c.id]?.text.trim() ?? '') ?? 0,
    };
    await ref.read(budgetNotifierProvider).saveAllocation(
          targetByCategory: targetByCategory,
          sweepByCategory: _sweepFlags,
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('budget.allocation_saved'.tr())));
    }
  }

  Future<int?> _pickAccount(List<Account> accounts, {required String title}) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ...accounts.map(
              (a) => ListTile(title: Text(a.name), onTap: () => Navigator.pop(ctx, a.id)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sweepCategory(BudgetTargetWithCategory row, double leftover) async {
    final accounts = await ref.read(accountsProvider.future);
    var savingsAccountId = await SettingsPrefs.getDefaultSavingsAccountId();

    if (savingsAccountId == null || !accounts.any((a) => a.id == savingsAccountId)) {
      savingsAccountId =
          await _pickAccount(accounts, title: 'budget.pick_savings_account'.tr());
      if (savingsAccountId == null) return;
      await SettingsPrefs.setDefaultSavingsAccountId(savingsAccountId);
    }

    final fromCandidates = accounts.where((a) => a.id != savingsAccountId).toList();
    final fromAccountId =
        await _pickAccount(fromCandidates, title: 'budget.pick_source_account'.tr());
    if (fromAccountId == null) return;

    final categoryLabel = row.category.name.tr();
    await ref.read(budgetNotifierProvider).sweep(
          target: row.target,
          leftover: leftover,
          spentSoFar: row.target.targetAmount - leftover,
          fromAccountId: fromAccountId,
          toAccountId: savingsAccountId,
          note: 'budget.sweep_note'.tr(namedArgs: {'category': categoryLabel}),
        );
    await NotificationService.showOneShot(
      id: 3000 + row.target.id,
      title: 'notifications.sweep_done'.tr(
        namedArgs: {'category': categoryLabel, 'amount': leftover.toStringAsFixed(2)},
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('budget.sweep_success'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final targetsAsync = ref.watch(budgetTargetsProvider);
    final sweepEligibleAsync = ref.watch(sweepEligibleProvider);
    final monthlyAsync = ref.watch(monthlySummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('budget.title'.tr())),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text('budget.error'.tr())),
        data: (categories) {
          final expenseCategories = categories.where((c) => c.kind == 'expense').toList();

          return targetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text('budget.error'.tr())),
            data: (targets) {
              if (!_initialized) {
                for (final row in targets) {
                  _controllerFor(row.category.id, row.target.targetAmount);
                  _sweepFlags[row.category.id] = row.target.sweepToSavings;
                }
                _initialized = true;
              }

              final allocated = expenseCategories.fold<double>(
                0,
                (sum, c) => sum + (double.tryParse(_controllers[c.id]?.text ?? '') ?? 0),
              );
              final income = monthlyAsync.asData?.value.income ?? 0;
              final remaining = income - allocated;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('budget.allocate_header'.tr(),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('budget.remaining_to_allocate'
                      .tr(namedArgs: {'amount': remaining.toStringAsFixed(2)})),
                  const SizedBox(height: 12),
                  for (final category in expenseCategories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(category.name.tr())),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _controllerFor(category.id, 0),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration:
                                  InputDecoration(labelText: 'budget.target_amount'.tr()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          Checkbox(
                            value: _sweepFlags[category.id] ?? false,
                            onChanged: (v) =>
                                setState(() => _sweepFlags[category.id] = v ?? false),
                          ),
                        ],
                      ),
                    ),
                  if (_addingCategory)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _newCategoryController,
                              autofocus: true,
                              decoration:
                                  InputDecoration(labelText: 'budget.new_category_name'.tr()),
                              onFieldSubmitted: (_) => _addCategory(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: _addCategory,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _addingCategory = false),
                          ),
                        ],
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => setState(() => _addingCategory = true),
                      icon: const Icon(Icons.add),
                      label: Text('budget.add_category'.tr()),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _saveAllocation(expenseCategories),
                    child: Text('budget.save_allocation'.tr()),
                  ),
                  const Divider(height: 32),
                  Text('budget.sweep_header'.tr(),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  sweepEligibleAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Text('budget.error'.tr()),
                    data: (rows) {
                      if (rows.isEmpty) return Text('budget.sweep_empty'.tr());
                      return Column(
                        children: [
                          for (final entry in rows)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.row.category.name.tr()),
                              subtitle: Text(
                                NumberFormat.currency(
                                  locale: context.locale.toString(),
                                  symbol: 'MAD ',
                                  decimalDigits: 2,
                                ).format(entry.leftover),
                              ),
                              trailing: FilledButton(
                                onPressed: () => _sweepCategory(entry.row, entry.leftover),
                                child: Text('budget.sweep_action'.tr()),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/budget/budget_screen.dart
git commit -m "feat: add Salary & Budget screen (allocate + sweep)"
```

---

## Task 9: Quick-add bottom sheet

**Files:**
- Create: `app/lib/features/transactions/quick_add_sheet.dart`

- [ ] **Step 1: Write the sheet**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../accounts/providers/accounts_provider.dart';
import '../budget/providers/budget_provider.dart';
import '../categories/providers/categories_provider.dart';
import 'providers/transactions_provider.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  int? _categoryId;
  int? _accountId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _categoryId == null || _accountId == null) {
      return;
    }
    final note = _noteController.text.trim();
    final categoryId = _categoryId;

    await ref.read(transactionsNotifierProvider).add(
          type: 'expense',
          amount: amount,
          date: DateTime.now(),
          accountId: _accountId!,
          categoryId: categoryId,
          note: note.isEmpty ? null : note,
        );
    await checkAndNotifyOverspend(ref.read(databaseProvider), categoryId, DateTime.now());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    final recentCategoryIds = <int>[];
    for (final row in transactionsAsync.asData?.value ?? const []) {
      final id = row.category?.id;
      if (id != null && !recentCategoryIds.contains(id)) recentCategoryIds.add(id);
      if (recentCategoryIds.length == 3) break;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('transactions.quick_add_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'transactions.amount'.tr()),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (categories) {
                final expenseCategories =
                    categories.where((c) => c.kind == 'expense').toList();
                final pinned = [
                  for (final id in recentCategoryIds)
                    ...expenseCategories.where((c) => c.id == id),
                ];
                final rest =
                    expenseCategories.where((c) => !recentCategoryIds.contains(c.id));
                final ordered = [...pinned, ...rest];

                return Wrap(
                  spacing: 8,
                  children: [
                    for (final category in ordered)
                      ChoiceChip(
                        label: Text(category.name.tr()),
                        selected: _categoryId == category.id,
                        onSelected: (_) => setState(() => _categoryId = category.id),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            accountsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (accounts) {
                _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
                return DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  decoration: InputDecoration(labelText: 'transactions.account'.tr()),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _accountId = v),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(labelText: 'transactions.note'.tr()),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text('common.save'.tr())),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Also check overspend after the full transaction form and after recurring auto-log**

In `app/lib/features/transactions/transaction_form_screen.dart`, add the import:

```dart
import '../budget/providers/budget_provider.dart';
import '../../core/database/database_provider.dart';
```

In `_submit`, right after the `if (_isEditing) { ... } else { ... }` block that calls `notifier.add`/`notifier.update`, before `if (mounted) Navigator.of(context).pop();`, add:

```dart
    if (_type == 'expense' && _categoryId != null) {
      await checkAndNotifyOverspend(ref.read(databaseProvider), _categoryId, _date);
    }
```

(Task 4/5 already wired the recurring auto-run path via `checkAndNotifyOverspend` inside `runDueRecurringTemplatesProvider`.)

- [ ] **Step 3: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/transactions/quick_add_sheet.dart app/lib/features/transactions/transaction_form_screen.dart
git commit -m "feat: add quick-add bottom sheet, wire overspend check into transaction paths"
```

---

## Task 10: Dashboard — FAB, allocate banner, budget progress bars

**Files:**
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Add imports and new widgets**

Add to the top of `app/lib/features/dashboard/dashboard_screen.dart`:

```dart
import '../budget/budget_screen.dart';
import '../budget/providers/budget_provider.dart';
import '../transactions/quick_add_sheet.dart';
```

Add these widgets in the same file, after `_StatCard`:

```dart
class _AllocateBanner extends ConsumerWidget {
  const _AllocateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyAsync = ref.watch(monthlySummaryProvider);
    final targetsAsync = ref.watch(budgetTargetsProvider);

    final hasIncome = (monthlyAsync.asData?.value.income ?? 0) > 0;
    final hasTargets = targetsAsync.asData?.value.isNotEmpty ?? true;
    if (!hasIncome || hasTargets) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        title: Text('dashboard.allocate_banner'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BudgetScreen()),
        ),
      ),
    );
  }
}

class _BudgetProgressSection extends ConsumerWidget {
  const _BudgetProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(budgetTargetsProvider);

    return targetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (targets) {
        if (targets.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('dashboard.budget_progress_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in targets) _BudgetProgressRow(row: row),
          ],
        );
      },
    );
  }
}

class _BudgetProgressRow extends ConsumerWidget {
  const _BudgetProgressRow({required this.row});

  final BudgetTargetWithCategory row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spentAsync = ref.watch(categorySpentProvider(row.category.id));

    return spentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (spent) {
        final target = row.target.targetAmount;
        final ratio = target <= 0 ? 0.0 : (spent / target).clamp(0.0, 1.0);
        final color = ratio >= 1.0
            ? Colors.red
            : ratio >= 0.8
                ? Colors.orange
                : Colors.green;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.category.name.tr()),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: ratio, color: color),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Insert the new sections and FAB into `DashboardScreen.build`**

Replace the existing `build` method's `body`/`Scaffold` with:

```dart
    return Scaffold(
      appBar: AppBar(title: Text('nav.dashboard'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _AllocateBanner(),
          const SizedBox(height: 12),
          _StatCard(
            label: 'dashboard.total_balance'.tr(),
            value: totalAsync,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _StatCard(
            label: 'dashboard.month_income'.tr(),
            value: monthlyAsync.whenData((s) => s.income),
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _StatCard(
            label: 'dashboard.month_expense'.tr(),
            value: monthlyAsync.whenData((s) => s.expense),
            color: Colors.red,
          ),
          const SizedBox(height: 20),
          const _BudgetProgressSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const QuickAddSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
```

- [ ] **Step 3: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/dashboard/dashboard_screen.dart
git commit -m "feat: dashboard FAB, allocate banner, budget progress bars"
```

---

## Task 11: Settings entries for Salary & Budget / Recurring bills

**Files:**
- Modify: `app/lib/features/settings/settings_screen.dart`

- [ ] **Step 1: Add imports**

```dart
import '../budget/budget_screen.dart';
import '../recurring/recurring_templates_screen.dart';
```

- [ ] **Step 2: Add two `ListTile`s next to `manage_categories`**

In the `ListView` `children`, right after the `manage_categories` `ListTile` and before the `Divider()` that follows it:

```dart
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text('settings.manage_budget'.tr()),
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BudgetScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.repeat_outlined),
            title: Text('settings.manage_recurring'.tr()),
            trailing: chevron,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecurringTemplatesScreen()),
            ),
          ),
```

- [ ] **Step 3: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/settings/settings_screen.dart
git commit -m "feat: add Salary & Budget and Recurring bills entries to Settings"
```

---

## Task 12: i18n — fr/en/ar/ar-MA

**Files:**
- Modify: `app/assets/translations/fr.json`
- Modify: `app/assets/translations/en.json`
- Modify: `app/assets/translations/ar.json`
- Modify: `app/assets/translations/ar-MA.json`

- [ ] **Step 1: `fr.json`**

Add `"quick_add_title": "Ajout rapide",` inside `"transactions"` (after `"quick_add_expense"`).

Extend `"dashboard"`:

```json
  "dashboard": {
    "total_balance": "Solde total",
    "month_income": "Revenus de ce mois",
    "month_expense": "Dépenses de ce mois",
    "allocate_banner": "Salaire reçu — Allouer votre budget ▸",
    "quick_add_hint": "Ajout rapide",
    "budget_progress_title": "Suivi du budget"
  },
```

Extend `"settings"` (add after `"manage_categories"`):

```json
    "manage_budget": "Salaire & Budget",
    "manage_recurring": "Prélèvements récurrents",
```

Extend `"notifications"`:

```json
  "notifications": {
    "daily_title": "Enregistrez vos dépenses du jour",
    "daily_body": "Prenez une minute pour noter ce que vous avez dépensé aujourd'hui.",
    "goal_deadline_title": "Échéance d'objectif proche",
    "goal_deadline_body": "« {name} » arrive bientôt à échéance — vérifiez votre progression.",
    "budget_90": "{category} est à 90% du budget.",
    "budget_100": "{category} a dépassé le budget.",
    "sweep_done": "{category} : {amount} transféré vers l'épargne."
  },
```

Add two new top-level sections (place after `"categories"`, before `"auth"`):

```json
  "budget": {
    "title": "Salaire & Budget",
    "error": "Impossible de charger le budget.",
    "allocate_header": "① Allouer le salaire",
    "remaining_to_allocate": "Reste à allouer : {amount}",
    "target_amount": "Objectif",
    "add_category": "+ Ajouter une catégorie",
    "new_category_name": "Nom de la catégorie",
    "save_allocation": "Enregistrer l'allocation",
    "allocation_saved": "Allocation enregistrée",
    "sweep_header": "② Budget non utilisé — Balayer",
    "sweep_empty": "Rien à balayer pour l'instant",
    "sweep_action": "Balayer →",
    "pick_savings_account": "Choisir le compte d'épargne",
    "pick_source_account": "Depuis quel compte ?",
    "sweep_success": "Montant transféré vers l'épargne",
    "sweep_note": "Balayage budget {category}"
  },
  "recurring": {
    "title": "Prélèvements récurrents",
    "error": "Impossible de charger les prélèvements récurrents.",
    "empty": "Aucun prélèvement récurrent. Appuyez sur + pour en ajouter un.",
    "add_title": "Ajouter un prélèvement récurrent",
    "edit_title": "Modifier le prélèvement récurrent",
    "name": "Nom",
    "day_of_month": "Jour du mois",
    "day_of_month_subtitle": "Le {day} de chaque mois",
    "delete_title": "Supprimer le prélèvement",
    "delete_confirm": "Ce prélèvement récurrent ne se déclenchera plus."
  },
```

- [ ] **Step 2: `en.json`** (mirror the same key structure)

```json
    "quick_add_title": "Quick add",
```
(inside `"transactions"`)

```json
  "dashboard": {
    "total_balance": "Total balance",
    "month_income": "This month's income",
    "month_expense": "This month's expenses",
    "allocate_banner": "Salary received — Allocate your budget ▸",
    "quick_add_hint": "Quick add",
    "budget_progress_title": "Budget progress"
  },
```

```json
    "manage_budget": "Salary & Budget",
    "manage_recurring": "Recurring bills",
```

```json
  "notifications": {
    "daily_title": "Log today's expenses",
    "daily_body": "Take a minute to record what you spent today.",
    "goal_deadline_title": "Goal deadline coming up",
    "goal_deadline_body": "\"{name}\" is due soon — check your progress.",
    "budget_90": "{category} is at 90% of budget.",
    "budget_100": "{category} is over budget.",
    "sweep_done": "{category}: {amount} moved to Savings."
  },
```

```json
  "budget": {
    "title": "Salary & Budget",
    "error": "Could not load budget.",
    "allocate_header": "① Allocate salary",
    "remaining_to_allocate": "Remaining to allocate: {amount}",
    "target_amount": "Target",
    "add_category": "+ Add category",
    "new_category_name": "Category name",
    "save_allocation": "Save allocation",
    "allocation_saved": "Allocation saved",
    "sweep_header": "② Unused budget — Sweep",
    "sweep_empty": "Nothing to sweep yet",
    "sweep_action": "Sweep →",
    "pick_savings_account": "Choose savings account",
    "pick_source_account": "From which account?",
    "sweep_success": "Moved to savings",
    "sweep_note": "{category} budget sweep"
  },
  "recurring": {
    "title": "Recurring bills",
    "error": "Could not load recurring bills.",
    "empty": "No recurring bills yet. Tap + to add one.",
    "add_title": "Add recurring bill",
    "edit_title": "Edit recurring bill",
    "name": "Name",
    "day_of_month": "Day of month",
    "day_of_month_subtitle": "The {day}th of every month",
    "delete_title": "Delete recurring bill",
    "delete_confirm": "This recurring bill will stop firing."
  },
```

- [ ] **Step 3: `ar.json`** (Modern Standard Arabic — mirror the same key structure)

```json
    "quick_add_title": "إضافة سريعة",
```

```json
  "dashboard": {
    "total_balance": "الرصيد الإجمالي",
    "month_income": "دخل هذا الشهر",
    "month_expense": "مصروفات هذا الشهر",
    "allocate_banner": "تم استلام الراتب — وزّع ميزانيتك ◂",
    "quick_add_hint": "إضافة سريعة",
    "budget_progress_title": "تقدم الميزانية"
  },
```

```json
    "manage_budget": "الراتب والميزانية",
    "manage_recurring": "الفواتير المتكررة",
```

```json
  "notifications": {
    "daily_title": "سجّل مصاريف اليوم",
    "daily_body": "خذ دقيقة لتسجيل ما أنفقته اليوم.",
    "goal_deadline_title": "اقترب موعد الهدف",
    "goal_deadline_body": "الموعد النهائي لـ \"{name}\" اقترب — تحقق من تقدمك.",
    "budget_90": "{category} وصلت إلى 90% من الميزانية.",
    "budget_100": "{category} تجاوزت الميزانية.",
    "sweep_done": "{category}: تم نقل {amount} إلى الادخار."
  },
```

```json
  "budget": {
    "title": "الراتب والميزانية",
    "error": "تعذر تحميل الميزانية.",
    "allocate_header": "① توزيع الراتب",
    "remaining_to_allocate": "المتبقي للتوزيع: {amount}",
    "target_amount": "الهدف",
    "add_category": "+ إضافة فئة",
    "new_category_name": "اسم الفئة",
    "save_allocation": "حفظ التوزيع",
    "allocation_saved": "تم حفظ التوزيع",
    "sweep_header": "② ميزانية غير مستخدمة — نقل",
    "sweep_empty": "لا يوجد شيء لنقله الآن",
    "sweep_action": "نقل ←",
    "pick_savings_account": "اختر حساب الادخار",
    "pick_source_account": "من أي حساب؟",
    "sweep_success": "تم النقل إلى الادخار",
    "sweep_note": "نقل ميزانية {category}"
  },
  "recurring": {
    "title": "الفواتير المتكررة",
    "error": "تعذر تحميل الفواتير المتكررة.",
    "empty": "لا توجد فواتير متكررة بعد. اضغط + لإضافة واحدة.",
    "add_title": "إضافة فاتورة متكررة",
    "edit_title": "تعديل الفاتورة المتكررة",
    "name": "الاسم",
    "day_of_month": "يوم الشهر",
    "day_of_month_subtitle": "يوم {day} من كل شهر",
    "delete_title": "حذف الفاتورة المتكررة",
    "delete_confirm": "لن يتم تفعيل هذه الفاتورة المتكررة بعد الآن."
  },
```

- [ ] **Step 4: `ar-MA.json`** (Darija — mirror the same key structure)

```json
    "quick_add_title": "زيادة سريعة",
```

```json
  "dashboard": {
    "total_balance": "الرصيد الكامل",
    "month_income": "الدخل ديال هاد الشهر",
    "month_expense": "المصاريف ديال هاد الشهر",
    "allocate_banner": "وصل الصالير — وزّع الميزانية ديالك ◂",
    "quick_add_hint": "زيادة سريعة",
    "budget_progress_title": "تتبع الميزانية"
  },
```

```json
    "manage_budget": "الصالير والميزانية",
    "manage_recurring": "الفواتير المتكررة",
```

```json
  "notifications": {
    "daily_title": "سجل مصاريف اليوم",
    "daily_body": "خود دقيقة باش تسجل شحال صرفتي اليوم.",
    "goal_deadline_title": "آخر أجل ديال الهدف قريب",
    "goal_deadline_body": "آخر أجل ديال \"{name}\" قريب — شوف فين وصلتي.",
    "budget_90": "{category} وصلات لـ90% ديال الميزانية.",
    "budget_100": "{category} فاتت الميزانية.",
    "sweep_done": "{category}: تحول {amount} للادخار."
  },
```

```json
  "budget": {
    "title": "الصالير والميزانية",
    "error": "ما قدرناش نحملو الميزانية.",
    "allocate_header": "① وزّع الصالير",
    "remaining_to_allocate": "الباقي باش توزع: {amount}",
    "target_amount": "الهدف",
    "add_category": "+ زيد فئة",
    "new_category_name": "سمية الفئة",
    "save_allocation": "سجل التوزيع",
    "allocation_saved": "تسجل التوزيع",
    "sweep_header": "② ميزانية ماستعملاتش — حول",
    "sweep_empty": "مازال ما كاين والو باش تحول",
    "sweep_action": "حول ←",
    "pick_savings_account": "اختار حساب الادخار",
    "pick_source_account": "من أي حساب؟",
    "sweep_success": "تحول للادخار",
    "sweep_note": "تحويل ميزانية {category}"
  },
  "recurring": {
    "title": "الفواتير المتكررة",
    "error": "ما قدرناش نحملو الفواتير المتكررة.",
    "empty": "مازال ما كاين حتى فاتورة متكررة. دوز على + باش تزيد وحدة.",
    "add_title": "زيد فاتورة متكررة",
    "edit_title": "بدل الفاتورة المتكررة",
    "name": "السمية",
    "day_of_month": "نهار الشهر",
    "day_of_month_subtitle": "النهار {day} ديال كل شهر",
    "delete_title": "حيد الفاتورة المتكررة",
    "delete_confirm": "هاد الفاتورة المتكررة ماغاديش تخدم مرة أخرى."
  },
```

- [ ] **Step 5: Validate JSON**

Run: `cd app && dart run -e "import 'dart:convert'; import 'dart:io'; for (final f in ['fr','en','ar','ar-MA']) { jsonDecode(File('assets/translations/\$f.json').readAsStringSync()); } print('ok');"`

(If that inline-script form doesn't run cleanly in this environment, just open each file and confirm valid JSON via `flutter analyze` — a malformed translations file fails app startup, not `analyze`, so also do a quick app boot per Task 14.)

Expected: `ok` printed, no `FormatException`.

- [ ] **Step 6: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 7: Commit**

```bash
git add app/assets/translations/fr.json app/assets/translations/en.json app/assets/translations/ar.json app/assets/translations/ar-MA.json
git commit -m "feat: add budget/recurring i18n keys (fr/en/ar/ar-MA)"
```

---

## Task 13: Single-account onboarding gate

**Files:**
- Modify: `app/lib/features/accounts/accounts_form_screen.dart` (optional `onSaved` callback)
- Modify: `app/lib/features/accounts/accounts_screen.dart` (hide "Add" FAB once an account exists)
- Modify: `app/lib/core/router/app_router.dart` (new `/setup-account` route + redirect check)
- Modify: `app/assets/translations/fr.json`, `en.json`, `ar.json`, `ar-MA.json` (one new key)

Existing app has full multi-account CRUD (`AccountsScreen`/`AccountsFormScreen`/`accountsProvider`, all from Sprint 1) — this task doesn't touch that CRUD, it only gates when the "add" path is reachable and forces account #1 to exist before the app is usable, per the spec's Single-Account Onboarding Gate section.

- [ ] **Step 1: Let `AccountsFormScreen` finish without a route to pop back to**

`_submit()` currently ends with `if (mounted) Navigator.of(context).pop();`. When this screen is shown as the onboarding gate's target (no prior route on the stack), `pop()` is a no-op and the user gets stuck. Add an optional callback:

```dart
class AccountsFormScreen extends ConsumerStatefulWidget {
  const AccountsFormScreen({super.key, this.account, this.onSaved});

  final Account? account;

  /// Called instead of [Navigator.pop] after a successful save. Used by the
  /// onboarding gate route, which has no prior route to pop back to.
  final VoidCallback? onSaved;
  // ... rest unchanged
```

In `_submit()`, replace the final line:

```dart
    if (!mounted) return;
    if (widget.onSaved != null) {
      widget.onSaved!();
    } else {
      Navigator.of(context).pop();
    }
```

Default (`onSaved: null`) preserves today's behavior for every existing caller (Settings → Accounts list). Only the new onboarding route passes it.

- [ ] **Step 2: Hide "Add Account" once one exists**

In `accounts_screen.dart`, wrap the FAB:

```dart
      floatingActionButton: accountsAsync.maybeWhen(
        data: (accounts) => accounts.isEmpty
            ? FloatingActionButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountsFormScreen()),
                ),
                child: const Icon(Icons.add),
              )
            : null,
        orElse: () => null,
      ),
```

Editing the existing account (tap on list tile → `AccountsFormScreen(account: account)`) is untouched — still reachable, still supports archive (delete), which is what re-drops the count to 0 and re-triggers the gate on next launch.

- [ ] **Step 3: Add the gate route + redirect check**

In `app_router.dart`, add the import and route:

```dart
import '../../features/accounts/accounts_form_screen.dart';
import '../../features/accounts/providers/accounts_provider.dart';
```

```dart
      GoRoute(
        path: '/setup-account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AccountsFormScreen(
          onSaved: () => GoRouter.of(context).go('/dashboard'),
        ),
      ),
```

Extend `redirect`, after the existing PIN checks (account gate only applies once a PIN exists — otherwise `/setup-pin` already owns the redirect):

```dart
      if (!hasPin && state.matchedLocation != '/setup-pin') return '/setup-pin';
      if (hasPin && !goingToAuth && state.matchedLocation == '/setup-pin') {
        return '/lock';
      }

      if (hasPin && state.matchedLocation != '/lock' && state.matchedLocation != '/setup-pin') {
        final db = ref.read(databaseProvider);
        final accountCount = await (db.selectOnly(db.accounts)
              ..addColumns([db.accounts.id.count()])
              ..where(db.accounts.archived.equals(false)))
            .map((row) => row.read(db.accounts.id.count()) ?? 0)
            .getSingle();
        final goingToSetupAccount = state.matchedLocation == '/setup-account';
        if (accountCount == 0 && !goingToSetupAccount) return '/setup-account';
        if (accountCount > 0 && goingToSetupAccount) return '/dashboard';
      }
      return null;
```

This runs on every navigation (same cost model as the existing `hasPin` check) — a `COUNT(*)` on a tiny local table is negligible. Placed after unlock (`/lock` still gates first) so the account check only applies to an already-unlocked session.

- [ ] **Step 4: New i18n key**

Add one key alongside the existing `accounts.*` block in `fr.json`/`en.json`/`ar.json`/`ar-MA.json` (exact phrasing per locale, matching existing tone):

```json
    "onboarding_intro": "Créez votre compte pour commencer."
```
(`en`: "Create your account to get started." / `ar`: "أنشئ حسابك للبدء." / `ar-MA`: "دير حسابك باش تبدا.")

Show it as a `Text` widget above the form only when `widget.onSaved != null` (i.e., only in the onboarding context) — reuses the same screen without changing its look for the normal add/edit path.

- [ ] **Step 5: Verify**

Run: `cd app && flutter analyze`
Expected: no new errors.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/accounts/accounts_form_screen.dart app/lib/features/accounts/accounts_screen.dart app/lib/core/router/app_router.dart app/assets/translations/*.json
git commit -m "feat: single-account onboarding gate"
```

---

## Task 14: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Static check**

Run: `cd app && flutter analyze`
Expected: clean, zero issues.

- [ ] **Step 2: Build a debug APK and install**

Run: `cd app && flutter build apk --debug`
Then install per the machine's known-good path (see `live/state.md`): `adb install -r build/app/outputs/flutter-apk/app-debug.apk` (adb at `C:\Users\fttah\AppData\Local\Android\Sdk\platform-tools\adb.exe`).

- [ ] **Step 3: Manual walkthrough (matches spec's Testing/Verification section)**

1. Fresh install (or archive the only existing account first). Launch app, unlock PIN — confirm you land on the account-creation screen, not Dashboard, and cannot navigate away without saving one. Save an account, confirm you land on Dashboard. Relaunch — confirm the gate doesn't reappear.
2. Settings → Accounts — confirm the "Add" FAB is gone now that one account exists. Archive (delete) the only account, relaunch — confirm the gate re-triggers.
3. Open Settings → "Salary & Budget". Allocate amounts across 2-3 expense categories, toggle sweep on for one, tap "Save allocation" — confirm "Reste à allouer / Remaining to allocate" updates live as you type, and the value persists after leaving and returning to the screen.
4. In the same Allocate section, tap "+ Add category", type a new name, confirm — confirm it appears immediately as a new allocate row, and also shows up in Settings' category list afterward.
5. From Dashboard, tap the FAB → quick-add sheet. Log an expense against one of the budgeted categories. Confirm it appears in Transactions and the Dashboard's budget progress bar for that category updates (green under 80%, orange 80-100%, red over 100%).
6. Log expenses to cross 90% then 100% of a category's target — confirm exactly one notification fires per threshold (not repeated on further spends in the same category/month).
7. Settings → "Recurring bills" → add one with today's day-of-month. Force-close and relaunch the app — confirm exactly one transaction was auto-logged (check Transactions list), then relaunch again the same day/month and confirm no duplicate.
8. Back in "Salary & Budget", the swept-eligible category (with leftover > 0) should now appear in the Sweep section. Tap "Sweep →": pick a savings account (first time only — confirm it's remembered on the next sweep), then pick a source account, confirm the transfer transaction appears in Transactions and the source/savings account balances update accordingly, and the category disappears from the sweep list (or shows a lower leftover) afterward.
9. Switch language to `ar-MA` (Darija) and `ar` — confirm all new strings render (no raw `budget.*`/`recurring.*`/`accounts.onboarding_intro` keys visible) and RTL layout looks correct on the new screens.

- [ ] **Step 4: Update project docs**

Update `live/state.md` and `intel/focus.md` per `moudabbir-progress` conventions once manual verification passes.

- [ ] **Step 5: Final commit (docs only, if not already covered by prior task commits)**

```bash
git add live/state.md intel/focus.md
git commit -m "docs: log hybrid budget model implementation session"
```
