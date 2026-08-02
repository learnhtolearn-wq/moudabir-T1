# Sprint 3 — Dashboard Summary & Transaction History/Search/Filters — Design

*Date: 2026-08-02*
*Status: approved for planning*

## Goal

Replace the Dashboard placeholder with a totals summary (US-001), and add search + type + date-range filtering to the existing Transactions list (US-012, US-013, US-014). No new screens, no charts (charts are Sprint 5), no navigation changes.

## Dashboard (US-001)

`lib/features/dashboard/dashboard_screen.dart` becomes a `ConsumerWidget` with three stat cards:
- **Total balance** — sum of all non-archived accounts' computed balances.
- **This month income** — sum of `amount` where `type = income`, `date` in current calendar month, not archived.
- **This month expense** — sum of `amount` where `type = expense`, `date` in current calendar month, not archived.

Transfers excluded from the income/expense monthly totals (they're neutral — money moving between the user's own accounts, not new income or spend). Total balance already nets transfers out via the existing per-account computation.

If there are zero accounts, show a zero-state ("$0.00" cards, no error) rather than an empty/error widget — avoids a sum-over-nothing edge case reading as broken.

## Provider Layer

New file `lib/features/dashboard/providers/dashboard_provider.dart`:
- `totalBalanceProvider` — `StreamProvider<double>`, combines all non-archived accounts' `accountBalanceProvider` streams (from `transactions_provider.dart`) into a single sum. Reactive — updates live on any transaction or account change.
- `monthlySummaryProvider` — `StreamProvider<({double income, double expense})>`, aggregate query over `Transactions` filtered to current month + non-archived, grouped by type.

Both live under `dashboard/providers/`, not `transactions/providers/`, since they're dashboard-specific aggregations distinct from the transaction list/detail providers Sprint 2 built.

## Transaction Filtering (US-012, US-013, US-014)

New file `lib/features/transactions/providers/transaction_filter_provider.dart`:
- `TransactionFilter` (plain class): `searchText`, `type` (nullable — null = all types), `dateRange` (nullable `DateTimeRange`).
- `transactionFilterProvider` — `StateNotifierProvider<TransactionFilterNotifier, TransactionFilter>` holding current filter, with methods `setSearch`, `setType`, `setDateRange`, `clear`.
- `filteredTransactionsProvider` — derived `Provider<AsyncValue<List<TransactionWithDetails>>>`, watches `transactionsProvider` (existing, unchanged) and `transactionFilterProvider`, applies filter client-side: substring match (case-insensitive) on account name / category name / note, exact match on type, inclusive match on date range.

Client-side filtering chosen over SQL-level filtering — single-user local dataset, no evidence of scale requiring query-level filters (matches Sprint 2's YAGNI precedent on multi-currency).

## UI Layer

**`lib/features/transactions/transactions_screen.dart`** (enhanced, not replaced):
- `TextField` search bar pinned above the list, updates `transactionFilterProvider.setSearch` on change (no debounce needed at this data scale).
- Filter row below search: `FilterChip` group for type (All/Income/Expense/Transfer, single-select) + a button opening `showDateRangePicker` for date range, with a small "×" to clear once a range is set.
- List switches from `transactionsProvider` to `filteredTransactionsProvider`.
- Two distinct empty states: "no transactions yet" (filter is default/empty) vs "no matches" (filter active, list empty) — different i18n keys.
- Existing row rendering, FAB, tap-to-edit, archive flow unchanged from Sprint 2.

## Routing

None — no new routes, no nav changes.

## i18n

New keys added to `fr.json`/`en.json`/`ar.json` in the same pass:
- `dashboard.*` — total balance label, this-month income/expense labels (placeholder key removed).
- `transactions.search_hint`, `transactions.filter_all/income/expense/transfer`, `transactions.filter_date_range`, `transactions.filter_clear`, `transactions.no_matches`.

## Testing / Verification

- `flutter analyze` clean.
- Manual: dashboard totals match manual sum across accounts/transactions from Sprint 2 test data.
- Manual: add transactions across 2+ months, confirm this-month totals only count current month.
- Manual: search narrows list by account/category/note text; type filter isolates each type; date range excludes out-of-range rows; clearing filters restores full list.
- Manual: zero-accounts state shows $0.00 cards, not an error.
- RTL (Arabic) sanity check on dashboard cards and the new filter row.

## Non-Goals (this sprint)

- Charts / category breakdown / income-vs-expense visualization — Sprint 5.
- Filter by account or category (only search/type/date-range per approved scope) — could extend later if asked.
- Persisting filter state across app restarts — resets on app relaunch.
- Custom/user-configurable dashboard KPIs — Sprint 6 (US-022).

## Decisions Log Entry (pending)

None expected — this sprint follows existing patterns (Riverpod StreamProvider aggregation, client-side filtering) without introducing a new architectural call. Log only if implementation surfaces a genuine decision.
