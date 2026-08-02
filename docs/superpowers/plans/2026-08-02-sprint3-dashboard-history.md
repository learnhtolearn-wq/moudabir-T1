# Sprint 3 — Dashboard Summary & Transaction History/Search/Filters — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Dashboard placeholder with live totals (total balance, this-month income/expense), and add search + type + date-range filtering to the existing Transactions list.

**Architecture:** Two new derived Riverpod `Provider`s (not `StreamProvider`s) that recompute from the *existing* `accountsProvider` and `transactionsProvider` streams — no new Drift queries needed, since both dashboard totals and the transaction filter are pure aggregations/filters over data those two providers already stream. This keeps the dashboard and filter reactive (they update live whenever the underlying `.watch()` streams emit) without adding new DB round-trips. Filtering is client-side (`List.where`), matching the spec's explicit choice over SQL-level filtering.

**Tech Stack:** Flutter, Riverpod 2.6.1 (`Provider.autoDispose`, `StateNotifierProvider.autoDispose`), Drift (via existing `accountsProvider`/`transactionsProvider`), easy_localization (re-exports `intl`'s `NumberFormat`/`DateFormat`).

**Note on testing:** Same convention as Sprint 2 — no `test/` directory in this codebase yet. Each task ends with `flutter analyze` and a concrete manual check instead of an automated test.

**Known limitation carried from Sprint 2's multi-currency non-goal:** accounts can have different currencies (`Accounts.currency`, default `MAD`), but "total balance" sums raw `amount`/`initialBalance` numbers with no currency conversion. The dashboard formats totals using the app's default currency (`MAD`) rather than per-account currency, since a single aggregate number can only show one currency symbol. This is a known simplification, not a bug — proper multi-currency totals require the conversion-rate work already deferred to V2 (`intel/wins.md` open clarification point). Flagging here for visibility; not blocking this sprint.

---

### Task 1: Dashboard provider layer

**Files:**
- Create: `app/lib/features/dashboard/providers/dashboard_provider.dart`

- [ ] **Step 1: Write the provider file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/providers/accounts_provider.dart';
import '../../transactions/providers/transactions_provider.dart';

/// Income/expense totals for the current calendar month.
typedef MonthlySummary = ({double income, double expense});

/// Sum of all non-archived accounts' balances. Transfers between the
/// user's own accounts net to zero when summed across every account, so
/// the total is just starting balances plus total income minus total
/// expense — no need to combine per-account balance streams.
final totalBalanceProvider = Provider.autoDispose<AsyncValue<double>>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  final transactionsAsync = ref.watch(transactionsProvider);

  return accountsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (accounts) => transactionsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, s) => AsyncValue.error(e, s),
      data: (rows) {
        var total = accounts.fold<double>(
          0,
          (sum, a) => sum + a.initialBalance,
        );
        for (final row in rows) {
          final t = row.transaction;
          if (t.type == 'income') total += t.amount;
          if (t.type == 'expense') total -= t.amount;
        }
        return AsyncValue.data(total);
      },
    ),
  );
});

/// This-month income/expense totals. Transfers are excluded — they move
/// money between the user's own accounts, not new income or spend.
final monthlySummaryProvider =
    Provider.autoDispose<AsyncValue<MonthlySummary>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (rows) {
      final now = DateTime.now();
      var income = 0.0;
      var expense = 0.0;
      for (final row in rows) {
        final t = row.transaction;
        if (t.date.year != now.year || t.date.month != now.month) continue;
        if (t.type == 'income') income += t.amount;
        if (t.type == 'expense') expense += t.amount;
      }
      return AsyncValue.data((income: income, expense: expense));
    },
  );
});
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/dashboard/providers/dashboard_provider.dart
git commit -m "feat: add dashboard total balance + monthly summary providers"
```

---

### Task 2: Dashboard screen (replace placeholder)

**Files:**
- Modify: `app/lib/features/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Replace the placeholder with stat cards**

Replace the entire contents of `app/lib/features/dashboard/dashboard_screen.dart` with:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalBalanceProvider);
    final monthlyAsync = ref.watch(monthlySummaryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('nav.dashboard'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final AsyncValue<double> value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            value.when(
              loading: () => const Text('…'),
              error: (_, __) => const Text('—'),
              data: (v) => Text(
                // Default-currency formatting — see "Known limitation" note
                // in the plan header re: multi-currency accounts.
                NumberFormat.currency(symbol: 'MAD ', decimalDigits: 2)
                    .format(v),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color),
              ),
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
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/dashboard/dashboard_screen.dart
git commit -m "feat: replace dashboard placeholder with live totals"
```

---

### Task 3: Transaction filter provider layer

**Files:**
- Create: `app/lib/features/transactions/providers/transaction_filter_provider.dart`

- [ ] **Step 1: Write the provider file**

```dart
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transactions_provider.dart';

/// Current search/filter criteria for the transactions list. `type: null`
/// means "all types"; `dateRange: null` means "all time".
class TransactionFilter {
  const TransactionFilter({
    this.searchText = '',
    this.type,
    this.dateRange,
  });

  final String searchText;
  final String? type;
  final DateTimeRange? dateRange;

  bool get isActive =>
      searchText.isNotEmpty || type != null || dateRange != null;

  TransactionFilter copyWith({
    String? searchText,
    String? type,
    bool clearType = false,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return TransactionFilter(
      searchText: searchText ?? this.searchText,
      type: clearType ? null : (type ?? this.type),
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }
}

class TransactionFilterNotifier extends StateNotifier<TransactionFilter> {
  TransactionFilterNotifier() : super(const TransactionFilter());

  void setSearch(String value) {
    state = state.copyWith(searchText: value);
  }

  void setType(String? value) {
    state = value == null
        ? state.copyWith(clearType: true)
        : state.copyWith(type: value);
  }

  void setDateRange(DateTimeRange? value) {
    state = value == null
        ? state.copyWith(clearDateRange: true)
        : state.copyWith(dateRange: value);
  }

  void clear() {
    state = const TransactionFilter();
  }
}

final transactionFilterProvider = StateNotifierProvider.autoDispose<
    TransactionFilterNotifier, TransactionFilter>(
  (ref) => TransactionFilterNotifier(),
);

/// `transactionsProvider`, narrowed by the current `TransactionFilter`.
/// Uses `AsyncValue.whenData` so loading/error states pass through
/// unchanged and only the data case gets filtered.
final filteredTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<TransactionWithDetails>>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final filter = ref.watch(transactionFilterProvider);

  return transactionsAsync.whenData((rows) {
    return rows.where((row) {
      final t = row.transaction;

      if (filter.type != null && t.type != filter.type) return false;

      if (filter.dateRange != null) {
        final start = filter.dateRange!.start;
        final endExclusive =
            filter.dateRange!.end.add(const Duration(days: 1));
        if (t.date.isBefore(start) || !t.date.isBefore(endExclusive)) {
          return false;
        }
      }

      if (filter.searchText.isNotEmpty) {
        final q = filter.searchText.toLowerCase();
        final matchesAccount = row.account.name.toLowerCase().contains(q);
        final matchesToAccount =
            row.toAccount?.name.toLowerCase().contains(q) ?? false;
        final matchesCategory =
            row.category?.name.toLowerCase().contains(q) ?? false;
        final matchesNote = t.note?.toLowerCase().contains(q) ?? false;
        if (!(matchesAccount ||
            matchesToAccount ||
            matchesCategory ||
            matchesNote)) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});
```

- [ ] **Step 2: Verify**

Run: `cd app && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/transactions/providers/transaction_filter_provider.dart
git commit -m "feat: add transaction search/type/date-range filter provider"
```

---

### Task 4: Transactions screen — add search + filter UI

**Files:**
- Modify: `app/lib/features/transactions/transactions_screen.dart`

- [ ] **Step 1: Replace the entire file**

Replace the entire contents of `app/lib/features/transactions/transactions_screen.dart` with:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/transaction_filter_provider.dart';
import 'providers/transactions_provider.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(TransactionFilter filter) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: filter.dateRange,
    );
    if (picked != null) {
      ref.read(transactionFilterProvider.notifier).setDateRange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final notifier = ref.read(transactionFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('nav.transactions'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'transactions.search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: notifier.setSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text('transactions.filter_all'.tr()),
                  selected: filter.type == null,
                  onSelected: (_) => notifier.setType(null),
                ),
                ChoiceChip(
                  label: Text('transactions.filter_income'.tr()),
                  selected: filter.type == 'income',
                  onSelected: (_) => notifier.setType('income'),
                ),
                ChoiceChip(
                  label: Text('transactions.filter_expense'.tr()),
                  selected: filter.type == 'expense',
                  onSelected: (_) => notifier.setType('expense'),
                ),
                ChoiceChip(
                  label: Text('transactions.filter_transfer'.tr()),
                  selected: filter.type == 'transfer',
                  onSelected: (_) => notifier.setType('transfer'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    filter.dateRange == null
                        ? 'transactions.filter_date_range'.tr()
                        : '${DateFormat.yMd(context.locale.toString()).format(filter.dateRange!.start)} '
                            '– '
                            '${DateFormat.yMd(context.locale.toString()).format(filter.dateRange!.end)}',
                  ),
                  onPressed: () => _pickDateRange(filter),
                ),
                if (filter.dateRange != null)
                  ActionChip(
                    avatar: const Icon(Icons.close, size: 18),
                    label: Text('transactions.filter_clear'.tr()),
                    onPressed: () => notifier.setDateRange(null),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('transactions.error'.tr())),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      filter.isActive
                          ? 'transactions.no_matches'.tr()
                          : 'transactions.empty'.tr(),
                    ),
                  );
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
                        : (isTransfer
                            ? Icons.swap_horiz
                            : Icons.arrow_downward);
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
                      subtitle: Text(
                        DateFormat.yMMMd(context.locale.toString())
                            .format(t.date),
                      ),
                      trailing: Text(
                        '$sign$formatted',
                        style: TextStyle(color: color),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              TransactionFormScreen(transaction: t),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
git commit -m "feat: add search + type + date-range filters to transactions list"
```

---

### Task 5: i18n — fr/en/ar

**Files:**
- Modify: `app/assets/translations/en.json`
- Modify: `app/assets/translations/fr.json`
- Modify: `app/assets/translations/ar.json`

- [ ] **Step 1: English** — in `app/assets/translations/en.json`:

Replace:
```json
  "dashboard": { "placeholder": "Dashboard — coming soon" },
```
with:
```json
  "dashboard": {
    "total_balance": "Total balance",
    "month_income": "This month's income",
    "month_expense": "This month's expenses"
  },
```

Replace the `"transactions": { ... }` block's closing section — add these keys inside it, right after `"archive_confirm"` and before `"type"`:
```json
    "search_hint": "Search account, category, or note",
    "filter_all": "All",
    "filter_income": "Income",
    "filter_expense": "Expense",
    "filter_transfer": "Transfer",
    "filter_date_range": "Date range",
    "filter_clear": "Clear",
    "no_matches": "No transactions match your filters.",
```

So the full `transactions` block in `en.json` becomes:
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
    "search_hint": "Search account, category, or note",
    "filter_all": "All",
    "filter_income": "Income",
    "filter_expense": "Expense",
    "filter_transfer": "Transfer",
    "filter_date_range": "Date range",
    "filter_clear": "Clear",
    "no_matches": "No transactions match your filters.",
    "type": {
      "income": "Income",
      "expense": "Expense",
      "transfer": "Transfer"
    }
  },
```

- [ ] **Step 2: French** — in `app/assets/translations/fr.json`, apply the equivalent changes:

Replace:
```json
  "dashboard": { "placeholder": "Tableau de bord — à venir" },
```
with:
```json
  "dashboard": {
    "total_balance": "Solde total",
    "month_income": "Revenus de ce mois",
    "month_expense": "Dépenses de ce mois"
  },
```

Full `transactions` block becomes:
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
    "search_hint": "Rechercher un compte, une catégorie ou une note",
    "filter_all": "Tous",
    "filter_income": "Revenu",
    "filter_expense": "Dépense",
    "filter_transfer": "Virement",
    "filter_date_range": "Période",
    "filter_clear": "Effacer",
    "no_matches": "Aucune transaction ne correspond à vos filtres.",
    "type": {
      "income": "Revenu",
      "expense": "Dépense",
      "transfer": "Virement"
    }
  },
```

- [ ] **Step 3: Arabic** — in `app/assets/translations/ar.json`, apply the equivalent changes:

Replace:
```json
  "dashboard": { "placeholder": "لوحة القيادة — قريباً" },
```
with:
```json
  "dashboard": {
    "total_balance": "الرصيد الإجمالي",
    "month_income": "دخل هذا الشهر",
    "month_expense": "مصروفات هذا الشهر"
  },
```

Full `transactions` block becomes:
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
    "search_hint": "ابحث في الحساب أو الفئة أو الملاحظة",
    "filter_all": "الكل",
    "filter_income": "دخل",
    "filter_expense": "مصروف",
    "filter_transfer": "تحويل",
    "filter_date_range": "الفترة الزمنية",
    "filter_clear": "مسح",
    "no_matches": "لا توجد معاملات مطابقة للفلاتر.",
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
Then run the app and manually check the Dashboard and Transactions tabs in all 3 languages via Settings → Language — confirm no raw-key fallback text (e.g. `dashboard.total_balance` showing literally) and Arabic renders RTL correctly (search bar, filter chips, and stat cards mirror correctly).

- [ ] **Step 5: Commit**

```bash
git add app/assets/translations/en.json app/assets/translations/fr.json app/assets/translations/ar.json
git commit -m "feat: add fr/en/ar translations for dashboard totals + transaction filters"
```

---

### Task 6: End-to-end manual verification

No new files — this task is verification only, run after Task 5 is committed. Use existing Sprint 2 test data (transactions across 2+ months/types) plus add a couple more if needed to cover both the current month and a prior month.

- [ ] **Step 1: Run the app**

Run: `cd app && flutter run`

- [ ] **Step 2: Dashboard totals**

Open Dashboard tab. Manually sum, from Manage Accounts, all non-archived accounts' `initialBalance` + all non-archived income/expense transactions (transfers excluded from the manual sum, matching the spec). Confirm the "Total balance" card matches. Confirm "This month's income"/"This month's expenses" cards match the manual sum of only current-month, non-archived income/expense transactions.

- [ ] **Step 3: Dashboard reactivity**

From the Transactions tab, add a new income transaction dated today. Return to Dashboard without restarting the app. Confirm both "Total balance" and "This month's income" update without manual refresh.

- [ ] **Step 4: Search filter**

On the Transactions tab, type a substring of an existing account name into the search bar. Confirm the list narrows to only matching rows. Clear the search box, confirm the full list returns.

- [ ] **Step 5: Type filter**

Tap the "Income" chip. Confirm only income transactions show. Tap "Expense", then "Transfer", confirming each narrows correctly. Tap "All" to restore the full list.

- [ ] **Step 6: Date range filter**

Tap the date-range chip, pick a range covering only some of the test transactions. Confirm the list excludes out-of-range rows. Tap the "×" clear chip that appears once a range is set, confirm the full list returns.

- [ ] **Step 7: Combined filters + empty state**

Combine a type filter and a search term that together match zero transactions. Confirm the empty state reads "no matches" (`transactions.no_matches`), not "no transactions yet" (`transactions.empty`). Clear all filters, confirm normal empty/list state returns.

- [ ] **Step 8: Zero-accounts edge case (if feasible)**

If a fresh/empty test environment is available, confirm the Dashboard shows $0.00-equivalent cards (via the `MAD 0.00` formatting) rather than an error or crash when there are no accounts yet. If not feasible to test directly, verify by code inspection that `totalBalanceProvider`/`monthlySummaryProvider` naturally resolve to `0` when `accounts`/`rows` are empty lists (no special-case branch needed — confirmed in Task 1's `fold`/loop logic).

- [ ] **Step 9: Report result**

If all checks pass, proceed to Task 7. If any fails, fix inline before moving on — do not defer known-broken behavior to a later sprint.

---

### Task 7: Update tracking files

**Files:**
- Modify: `live/state.md`
- Modify: `intel/wins.md`
- Modify: `decisions/ledger.md` (only if a genuine new architectural call surfaced during implementation — not expected for this sprint per the design doc)

- [ ] **Step 1: Update `live/state.md`**

Move the Sprint 3 "Active Work" into "Last Session", set Open Tasks/Current Priorities to Sprint 4 (savings goals), per the pattern already used after Sprint 1 and Sprint 2.

- [ ] **Step 2: Mark Sprint 3 done in `intel/wins.md`**

Change `- [ ] Sprint 3 — Dashboard & history, ...` to `- [x] Sprint 3 — ... — shipped <date>`.

- [ ] **Step 3: Commit**

```bash
git add live/state.md intel/wins.md
git commit -m "docs: log Sprint 3 completion"
```

---

## Self-Review Notes

- **Spec coverage:** dashboard totals (Tasks 1-2), search/type/date-range filtering (Tasks 3-4), i18n (Task 5), verification (Task 6), zero-accounts edge case (Task 6 Step 8), non-goals untouched (no charts, no account/category filters, no filter persistence across restarts, no custom KPIs added).
- **Implementation deviation from spec:** the spec described `totalBalanceProvider` as "combines all non-archived accounts' `accountBalanceProvider` streams... into a single sum." This plan instead derives the total directly from `accountsProvider` + `transactionsProvider` (summing `initialBalance` + income − expense globally, since transfers net to zero across all accounts). Same reactive behavior and same public provider name/shape (`Provider.autoDispose<AsyncValue<double>>`), but avoids the complexity of dynamically combining a variable-length list of per-account family streams (no `rxdart` dependency in this project to make that easy). Noted here rather than silently diverging.
- **New known limitation surfaced during planning (not in original spec):** aggregate totals mix currencies if accounts use different currencies — documented in the plan header and in a code comment on the dashboard's `_StatCard`. Consistent with the existing Sprint 2 non-goal ("multi-currency conversion... V2"), not a new scope decision.
- **Type consistency:** `TransactionFilter`, `TransactionFilterNotifier`, `transactionFilterProvider`, `filteredTransactionsProvider`, `totalBalanceProvider`, `monthlySummaryProvider`, `MonthlySummary` names used consistently across Tasks 1-4.
- **No placeholders:** every step has complete, runnable code.
