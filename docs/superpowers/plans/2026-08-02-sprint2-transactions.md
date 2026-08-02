# Sprint 2 — Income, Expenses, Account Transfers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Transactions tab placeholder with working income/expense/transfer CRUD, backed by a computed-on-read account balance.

**Architecture:** Extends the existing `blueprints/crud-sprint.md` pattern (Riverpod `StreamProvider` over Drift `.watch()`, plain `Navigator.push`/`MaterialPageRoute` — this codebase does NOT use nested `go_router` routes for sub-screens, only `Navigator.push` from the parent list screen, per `accounts_screen.dart`/`settings_screen.dart`). Adds one schema migration (`Transactions.archived`) and one new computed provider (`accountBalanceProvider`, a `StreamProvider.family<double, int>`) for live balances.

**Tech Stack:** Flutter, Drift (generated `Transaction`/`TransactionsCompanion`), Riverpod 2.6.1, easy_localization (re-exports `intl`'s `NumberFormat`), go_router (top-level tab only — no nested routes here).

**Note on testing:** This codebase has no `test/` directory and no unit tests yet (Sprint 0/1 shipped with `flutter analyze` + manual verification only, per `blueprints/crud-sprint.md` step 7). This plan follows that established convention rather than introducing TDD unilaterally — each task ends with an analyze run and a concrete manual check instead of an automated test. If the user wants a test suite started, that's a separate decision to raise, not bundled into this sprint silently.

---

### Task 1: Schema migration — `Transactions.archived`

**Files:**
- Modify: `app/lib/core/database/tables.dart`
- Modify: `app/lib/core/database/database.dart`
- Regenerate: `app/lib/core/database/database.g.dart` (via build_runner, not hand-edited)

- [ ] **Step 1: Add the column to the table definition**

In `app/lib/core/database/tables.dart`, inside `class Transactions extends Table`, add after `note`:

```dart
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
```

Full `Transactions` class after the change:

```dart
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // income | expense | transfer
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  @ReferenceName('sourceTransactions')
  IntColumn get accountId =>
      integer().references(Accounts, #id)();
  // Only set for transfers: the destination account.
  @ReferenceName('destinationTransactions')
  IntColumn get toAccountId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

- [ ] **Step 2: Bump schema version and add migration**

In `app/lib/core/database/database.dart`, replace:

```dart
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaultCategories(this);
        },
      );
```

with:

```dart
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
```

- [ ] **Step 3: Regenerate Drift code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: completes with `[INFO] Succeeded after ...` and no errors; `database.g.dart` now has an `archived` field on `Transaction`/`TransactionsCompanion`.

- [ ] **Step 4: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/database/tables.dart app/lib/core/database/database.dart app/lib/core/database/database.g.dart
git commit -m "feat: add Transactions.archived column, schema v2 migration"
```

---

### Task 2: Transactions provider layer

**Files:**
- Create: `app/lib/features/transactions/providers/transactions_provider.dart`

- [ ] **Step 1: Write the provider file**

```dart
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
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/transactions/providers/transactions_provider.dart
git commit -m "feat: add transactions list + computed account balance providers"
```

---

### Task 3: Switch accounts list to computed balance

**Files:**
- Modify: `app/lib/features/accounts/accounts_screen.dart`

- [ ] **Step 1: Import the new provider and use it per row**

In `app/lib/features/accounts/accounts_screen.dart`, add import:

```dart
import '../transactions/providers/transactions_provider.dart';
```

Replace the row-building body (inside `itemBuilder`) — change:

```dart
              final account = accounts[index];
              final formatted = NumberFormat.currency(
                symbol: account.currency,
                decimalDigits: 2,
              ).format(account.initialBalance);
              return ListTile(
                leading: CircleAvatar(child: Text(account.name[0].toUpperCase())),
                title: Text(account.name),
                subtitle: Text('accounts.type.${account.type}'.tr()),
                trailing: Text(formatted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountsFormScreen(account: account),
                  ),
                ),
              );
```

to:

```dart
              final account = accounts[index];
              final balanceAsync = ref.watch(accountBalanceProvider(account.id));
              final formatted = balanceAsync.when(
                data: (balance) => NumberFormat.currency(
                  symbol: account.currency,
                  decimalDigits: 2,
                ).format(balance),
                loading: () => '…',
                error: (_, __) => '—',
              );
              return ListTile(
                leading: CircleAvatar(child: Text(account.name[0].toUpperCase())),
                title: Text(account.name),
                subtitle: Text('accounts.type.${account.type}'.tr()),
                trailing: Text(formatted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountsFormScreen(account: account),
                  ),
                ),
              );
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/accounts/accounts_screen.dart
git commit -m "feat: show live computed balance on accounts list"
```

---

### Task 4: Transaction form screen (income/expense/transfer toggle)

**Files:**
- Create: `app/lib/features/transactions/transaction_form_screen.dart`

- [ ] **Step 1: Write the form screen**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../accounts/providers/accounts_provider.dart';
import '../categories/providers/categories_provider.dart';
import 'providers/transactions_provider.dart';

const transactionTypes = ['income', 'expense', 'transfer'];

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _type;
  late DateTime _date;
  int? _accountId;
  int? _toAccountId;
  int? _categoryId;
  String? _transferError;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController =
        TextEditingController(text: t != null ? t.amount.toString() : '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _type = t?.type ?? transactionTypes.first;
    _date = t?.date ?? DateTime.now();
    _accountId = t?.accountId;
    _toAccountId = t?.toAccountId;
    _categoryId = t?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() => _transferError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;
    if (_type == 'transfer' && (_toAccountId == null || _toAccountId == _accountId)) {
      setState(() => _transferError = 'transactions.transfer_same_account'.tr());
      return;
    }

    final notifier = ref.read(transactionsNotifierProvider);
    final amount = double.parse(_amountController.text.trim());
    final note = _noteController.text.trim();

    if (_isEditing) {
      await notifier.update(
        widget.transaction!.copyWith(
          amount: amount,
          date: _date,
          accountId: _accountId!,
          toAccountId: Value(_type == 'transfer' ? _toAccountId : null),
          categoryId: Value(_type == 'transfer' ? null : _categoryId),
          note: Value(note.isEmpty ? null : note),
        ),
      );
    } else {
      await notifier.add(
        type: _type,
        amount: amount,
        date: _date,
        accountId: _accountId!,
        toAccountId: _type == 'transfer' ? _toAccountId : null,
        categoryId: _type == 'transfer' ? null : _categoryId,
        note: note.isEmpty ? null : note,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('transactions.archive_title'.tr()),
        content: Text('transactions.archive_confirm'.tr()),
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
      await ref.read(transactionsNotifierProvider).archive(widget.transaction!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'transactions.edit_title'.tr()
            : 'transactions.add_title'.tr()),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _archive,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: transactionTypes
                  .map((t) => ButtonSegment(
                        value: t,
                        label: Text('transactions.type.$t'.tr()),
                      ))
                  .toList(),
              selected: {_type},
              onSelectionChanged: _isEditing
                  ? null
                  : (selection) => setState(() {
                        _type = selection.first;
                        _categoryId = null;
                        _toAccountId = null;
                        _transferError = null;
                      }),
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => Text('accounts.error'.tr()),
              data: (accounts) => DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: _type == 'transfer'
                      ? 'transactions.from_account'.tr()
                      : 'transactions.account'.tr(),
                ),
                items: accounts
                    .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) => v == null ? 'common.required'.tr() : null,
              ),
            ),
            if (_type == 'transfer') ...[
              const SizedBox(height: 16),
              accountsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (accounts) => DropdownButtonFormField<int>(
                  initialValue: _toAccountId,
                  decoration:
                      InputDecoration(labelText: 'transactions.to_account'.tr()),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _toAccountId = v;
                    _transferError = null;
                  }),
                  validator: (v) => v == null ? 'common.required'.tr() : null,
                ),
              ),
              if (_transferError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _transferError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (categories) {
                  final filtered =
                      categories.where((c) => c.kind == _type).toList();
                  return DropdownButtonFormField<int>(
                    initialValue: filtered.any((c) => c.id == _categoryId)
                        ? _categoryId
                        : null,
                    decoration:
                        InputDecoration(labelText: 'transactions.category'.tr()),
                    items: filtered
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'common.required'.tr() : null,
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'transactions.amount'.tr()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'common.required'.tr();
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'common.invalid_number'.tr();
                if (parsed <= 0) return 'transactions.amount_positive'.tr();
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('transactions.date'.tr()),
              subtitle: Text(DateFormat.yMMMd(context.locale.toString()).format(_date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(labelText: 'transactions.note'.tr()),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!` (this step will surface any missing i18n key usage as a runtime concern, not an analyze error — i18n keys are added in Task 6, but the Dart code compiles independently of whether the JSON keys exist yet)

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/transactions/transaction_form_screen.dart
git commit -m "feat: add transaction form (income/expense/transfer toggle)"
```

---

### Task 5: Transaction list screen (replace placeholder)

**Files:**
- Modify: `app/lib/features/transactions/transactions_screen.dart`

- [ ] **Step 1: Replace the placeholder with the real list**

Replace the entire contents of `app/lib/features/transactions/transactions_screen.dart` with:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/transactions_provider.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.transactions'.tr())),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('transactions.error'.tr())),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(child: Text('transactions.empty'.tr()));
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final t = row.transaction;
              final isIncome = t.type == 'income';
              final isTransfer = t.type == 'transfer';
              final sign = isIncome ? '+' : (isTransfer ? '' : '-');
              final color = isIncome
                  ? Colors.green
                  : (isTransfer ? Colors.grey : Colors.red);
              final icon = isIncome
                  ? Icons.arrow_upward
                  : (isTransfer ? Icons.swap_horiz : Icons.arrow_downward);
              final formatted = NumberFormat.currency(
                symbol: row.account.currency,
                decimalDigits: 2,
              ).format(t.amount);
              final subtitle = isTransfer
                  ? '${row.account.name} → ${row.toAccount?.name ?? ''}'
                  : '${row.account.name}'
                      '${row.category != null ? ' · ${row.category!.name}' : ''}';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                title: Text(subtitle),
                subtitle: Text(DateFormat.yMMMd(context.locale.toString()).format(t.date)),
                trailing: Text('$sign$formatted', style: TextStyle(color: color)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TransactionFormScreen(transaction: t),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/transactions/transactions_screen.dart
git commit -m "feat: replace transactions placeholder with live list"
```

---

### Task 6: i18n — fr/en/ar

**Files:**
- Modify: `app/assets/translations/en.json`
- Modify: `app/assets/translations/fr.json`
- Modify: `app/assets/translations/ar.json`

- [ ] **Step 1: English** — in `app/assets/translations/en.json`, replace:

```json
  "transactions": { "placeholder": "Transaction history — coming soon" },
```

with:

```json
  "transactions": {
    "title": "Transactions",
    "empty": "No transactions yet. Tap + to add one.",
    "error": "Could not load transactions.",
    "add_title": "Add transaction",
    "edit_title": "Edit transaction",
    "account": "Account",
    "from_account": "From account",
    "to_account": "To account",
    "category": "Category",
    "amount": "Amount",
    "amount_positive": "Amount must be greater than zero",
    "date": "Date",
    "note": "Note",
    "transfer_same_account": "From and to account must be different",
    "archive_title": "Delete transaction",
    "archive_confirm": "This transaction will be removed from your history and balances.",
    "type": {
      "income": "Income",
      "expense": "Expense",
      "transfer": "Transfer"
    }
  },
```

- [ ] **Step 2: French** — in `app/assets/translations/fr.json`, replace the equivalent `"transactions": { "placeholder": ... }` line with:

```json
  "transactions": {
    "title": "Transactions",
    "empty": "Aucune transaction. Appuyez sur + pour en ajouter une.",
    "error": "Impossible de charger les transactions.",
    "add_title": "Ajouter une transaction",
    "edit_title": "Modifier la transaction",
    "account": "Compte",
    "from_account": "Compte source",
    "to_account": "Compte destination",
    "category": "Catégorie",
    "amount": "Montant",
    "amount_positive": "Le montant doit être supérieur à zéro",
    "date": "Date",
    "note": "Note",
    "transfer_same_account": "Les comptes source et destination doivent être différents",
    "archive_title": "Supprimer la transaction",
    "archive_confirm": "Cette transaction sera retirée de l'historique et des soldes.",
    "type": {
      "income": "Revenu",
      "expense": "Dépense",
      "transfer": "Virement"
    }
  },
```

- [ ] **Step 3: Arabic** — in `app/assets/translations/ar.json`, replace the equivalent `"transactions": { "placeholder": ... }` line with:

```json
  "transactions": {
    "title": "المعاملات",
    "empty": "لا توجد معاملات بعد. اضغط + لإضافة واحدة.",
    "error": "تعذر تحميل المعاملات.",
    "add_title": "إضافة معاملة",
    "edit_title": "تعديل المعاملة",
    "account": "الحساب",
    "from_account": "من حساب",
    "to_account": "إلى حساب",
    "category": "الفئة",
    "amount": "المبلغ",
    "amount_positive": "يجب أن يكون المبلغ أكبر من صفر",
    "date": "التاريخ",
    "note": "ملاحظة",
    "transfer_same_account": "يجب أن يكون حساب المصدر مختلفًا عن حساب الوجهة",
    "archive_title": "حذف المعاملة",
    "archive_confirm": "ستتم إزالة هذه المعاملة من السجل والأرصدة.",
    "type": {
      "income": "دخل",
      "expense": "مصروف",
      "transfer": "تحويل"
    }
  },
```

- [ ] **Step 4: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!`
Then run the app (`flutter run`) and manually open Transactions tab in each of the 3 languages via Settings → Language to confirm no missing-key fallback text (`easy_localization` shows the raw key like `transactions.title` if a key is missing) and Arabic renders RTL correctly.

- [ ] **Step 5: Commit**

```bash
git add app/assets/translations/en.json app/assets/translations/fr.json app/assets/translations/ar.json
git commit -m "feat: add fr/en/ar translations for transactions"
```

---

### Task 7: End-to-end manual verification

No new files — this task is verification only, run after Task 6 is committed.

- [ ] **Step 1: Run the app**

Run: `cd app && flutter run` (or existing device/emulator workflow used in Sprint 0/1)

- [ ] **Step 2: Income round-trip**

Add an income transaction on an existing account. Confirm: transaction appears at top of Transactions list with a green up-arrow and `+` amount; navigate to Settings → Manage accounts and confirm that account's balance increased by the entered amount, with no manual refresh needed.

- [ ] **Step 3: Expense round-trip**

Add an expense transaction on the same account. Confirm: red down-arrow, `-` amount in list; account balance in Manage accounts decreased accordingly.

- [ ] **Step 4: Transfer round-trip**

Add a transfer between two different accounts. Confirm: neutral swap icon, `From → To` account names shown, no category shown; source account balance decreased, destination account balance increased, both visible in Manage accounts without refresh.

- [ ] **Step 5: Transfer same-account rejection**

In the transfer form, pick the same account for "From" and "To". Confirm inline error `transactions.transfer_same_account` text shown and submit is blocked.

- [ ] **Step 6: Delete (archive)**

Open an existing transaction, tap the delete icon, confirm the dialog. Confirm: transaction disappears from the list and the affected account's balance recalculates to exclude it.

- [ ] **Step 7: Report result**

If all 6 checks pass, proceed to Task 8. If any fails, fix inline before moving on — do not defer known-broken behavior to a later sprint.

---

### Task 8: Update tracking files

**Files:**
- Modify: `live/state.md`
- Modify: `intel/wins.md`
- Modify: `decisions/ledger.md`

- [ ] **Step 1: Update `live/state.md`**

Move the Sprint 2 "Active Work" into "Last Session", set Open Tasks/Current Priorities to Sprint 3 (dashboard & history), per the pattern already used after Sprint 1.

- [ ] **Step 2: Mark Sprint 2 done in `intel/wins.md`**

Change `- [ ] Sprint 2 — Income & expenses, ...` to `- [x] Sprint 2 — ... — shipped <date>`.

- [ ] **Step 3: Append to `decisions/ledger.md`** (append-only, do not edit prior lines)

```
[<date>] DECISION: Transactions.archived added (schema v1->v2), balance computed on read via aggregate query (not stored/maintained column) | REASONING: matches existing .watch() reactive pattern used by accounts/categories, avoids write-side bookkeeping and drift risk between a stored balance and the transaction ledger; acceptable cost at personal-finance data volumes | CONTEXT: Sprint 2 build, docs/superpowers/specs/2026-08-02-sprint2-transactions-design.md
```

- [ ] **Step 4: Commit**

```bash
git add live/state.md intel/wins.md decisions/ledger.md
git commit -m "docs: log Sprint 2 completion"
```

---

## Self-Review Notes

- **Spec coverage:** schema change (Task 1), computed balance (Task 2), provider layer (Task 2), list+form UI (Tasks 4-5), accounts balance display swap (Task 3), i18n (Task 6), verification (Task 7), non-goals untouched (no filters/search/dashboard/recurring/type-switch-after-create added). All spec sections covered.
- **Routing deviation from spec:** the design doc said "nested `GoRoute`s" — corrected here to `Navigator.push`/`MaterialPageRoute`, because that's what `accounts_screen.dart` and `settings_screen.dart` actually do in this codebase. Following existing pattern over the spec's assumption.
- **Type consistency:** `TransactionWithDetails`, `accountBalanceProvider`, `transactionsNotifierProvider`, `TransactionFormScreen` names used consistently across Tasks 2-5.
- **No placeholders:** every step has complete, runnable code.
