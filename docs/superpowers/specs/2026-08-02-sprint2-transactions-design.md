# Sprint 2 — Income, Expenses, Account Transfers — Design

*Date: 2026-08-02*
*Status: approved for planning*

## Goal

Build CRUD + business logic for income, expense, and transfer transactions on top of the Sprint 0 `Transactions` table, replacing the placeholder Transactions tab. Covers US-002 through US-007, US-011. Extends the `blueprints/crud-sprint.md` pattern with computed account balances and a type-toggling transfer form.

## Schema Change

`Transactions` gains an `archived` boolean column (default `false`), bringing it in line with `Accounts`/`Categories`. Reason: transaction rows are user-facing records a user may want to "delete" without losing audit history, and no other table references a `Transaction` row, so soft-delete (not hard `DELETE`) is the safer default going forward even though nothing currently points at these rows.

- `schemaVersion`: 1 → 2
- `MigrationStrategy.onUpgrade`: `if (from < 2) await m.addColumn(transactions, transactions.archived);`
- DB has never shipped externally (dev-only so far), so no real user data is at risk, but the migration is written properly anyway since this is the pattern going forward.

## Balance Calculation

Balance is **computed on read**, not stored:

```
balance(account) = initialBalance
  + Σ(amount where type = income, accountId = account)
  − Σ(amount where type = expense, accountId = account)
  − Σ(amount where type = transfer, accountId = account)   // transfer out
  + Σ(amount where type = transfer, toAccountId = account) // transfer in
```

Archived transactions are excluded from the sum (soft-deleted = not counted).

Implemented as a Drift aggregate query wrapped in a `.watch()` stream so balances update live when transactions change, matching the reactive pattern already used for lists (no manual refresh anywhere in the app).

## Provider Layer

`lib/features/transactions/providers/transactions_provider.dart`:
- `transactionsProvider` — `StreamProvider<List<TransactionWithDetails>>`, watches all non-archived transactions joined to account name/color and category name/color, sorted `date DESC`.
- `accountBalanceProvider` — `StreamProvider.family<double, int>` keyed by `accountId`, watches the aggregate query above.
- `TransactionsNotifier` (or plain repository methods called from the form) — `addTransaction`, `updateTransaction`, `archiveTransaction`. Each transfer is a single row (`accountId` = from, `toAccountId` = to) — no double-entry row pair.

`lib/features/accounts/providers/accounts_provider.dart` — existing list provider's balance display switches from raw `initialBalance` to `accountBalanceProvider(account.id)` per row.

## UI Layer

**`lib/features/transactions/transactions_screen.dart`** (replaces current placeholder):
- `ConsumerWidget`, `ListView` over `transactionsProvider`.
- Empty state preserved (reuse existing placeholder-style empty message) when list is empty.
- Row: type icon + color (income=green/up, expense=red/down, transfer=neutral/swap), account name, category name (blank for transfer), signed formatted amount (`NumberFormat.currency` using account's `currency`), date.
- `FloatingActionButton` → push `/transactions/add`.
- Tap row → push `/transactions/:id/edit`.
- Long-press or swipe → archive (confirm dialog, sets `archived = true`).

**`lib/features/transactions/transaction_form_screen.dart`**:
- Full-screen route (form has >3 fields).
- `SegmentedButton`/`ToggleButtons` at top: Income / Expense / Transfer. Switching type clears fields not relevant to the new type.
- Income/Expense fields: account (dropdown, non-archived accounts), category (dropdown filtered by `kind` matching income/expense, non-archived), amount, date, note.
- Transfer fields: from-account, to-account (both dropdowns, non-archived accounts), amount, date, note. No category (`categoryId = null`).
- Validation: amount > 0 (numeric parse), account/category required per type, transfer from ≠ to (inline error, not just disabled submit).
- Edit mode: pre-fills from existing row, `type` field locked (changing a transaction's type after creation is out of scope — user deletes and re-adds instead).

## Routing

Nested `GoRoute`s off the Transactions tab shell branch, same as accounts/categories:
- `/transactions/add`
- `/transactions/:id/edit`

## i18n

New `transactions.*` namespace keys added to `fr.json`/`en.json`/`ar.json` in the same pass: list empty state, form field labels, type names, validation messages, confirm-archive dialog text. Existing `transactions.placeholder` key removed once real screen ships.

## Testing / Verification

- `flutter analyze` clean.
- Manual round-trip: add income → account balance updates live without refresh; add expense → balance drops; add transfer → source balance drops, destination balance rises, both visible without refresh.
- Manual: archive a transaction → disappears from list, balance recalculates excluding it.
- Manual: transfer form rejects same from/to account.
- RTL (Arabic) sanity check on the new form and list screen (icons/amount alignment).

## Non-Goals (this sprint)

- Filters, search, date-range — Sprint 3 (dashboard & history).
- Dashboard summary card / totals — Sprint 3.
- Recurring/scheduled transactions — not in original scope list.
- Changing a transaction's `type` post-creation.
- Multi-currency conversion on transfers between accounts with different currencies (transfer just moves the raw `amount` figure; cross-currency math is the existing V2 open clarification point in `intel/wins.md`).

## Decisions Log Entry (pending)

To append to `decisions/ledger.md` once implementation starts: schema v1→v2 migration adding `Transactions.archived`, and "balance = computed on read via aggregate query" as the standing approach (not a stored/maintained column) — reasoning: matches existing `.watch()` reactive pattern, avoids write-side bookkeeping and drift risk, acceptable cost at personal-finance data volumes.
