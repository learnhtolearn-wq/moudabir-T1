# Hybrid Budget Model — Salary Allocation, Recurring Bills, Quick-Add, Leftover Sweep — Design

*Date: 2026-08-05*
*Status: approved for planning*

## Goal

Move Moudabir from pure after-the-fact transaction logging toward a hybrid budgeting model: allocate salary into category targets on payday, auto-log known recurring bills, log variable spend fast (<10s) as it happens, and let the user sweep unused category budget into savings whenever they choose (not automatically). Covers new ground beyond Sprint 0–3's schema (Accounts, Categories, Transactions, Goals) — no existing sprint covers budgeting/recurring/sweep.

Out of scope for this spec: notification permission plumbing (assumed available from Sprint 6 security/notifications work), multi-currency budgets (matches existing single-currency precedent).

## Data Model

New Drift tables in `lib/core/database/tables.dart`:

```dart
/// Per-month spending target per category (Hybrid Budget Model).
class BudgetTargets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get month => text()(); // 'YYYY-MM', one row per category per month
  RealColumn get targetAmount => real()();
  BoolColumn get sweepToSavings => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Recurring bill/income templates that auto-create transactions on their due day.
class RecurringTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text()(); // income | expense
  RealColumn get amount => real()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get dayOfMonth => integer()(); // 1-28, clamps to month length
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastRunMonth => dateTime().nullable()(); // guards double-fire per month
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

`BudgetTargets.month` uses a string key (`'2026-08'`) rather than a date column — matches simplest query pattern for "this month's targets," avoids timezone/day-of-month ambiguity.

No new table for the sweep action itself — a sweep just creates a normal `Transactions` row (type `transfer`, from a virtual "budget" source represented by zeroing that category's remaining target, to the default savings account) and updates `BudgetTargets.targetAmount` to reflect zero remaining for the rest of the period.

Settings gets one new persisted value: `defaultSavingsAccountId` (nullable int), stored alongside existing settings (PIN, locale, etc. — see `core/security` / `features/settings`).

## Recurring Templates (auto-log on due day)

New file `lib/features/recurring/providers/recurring_provider.dart`:
- `recurringTemplatesProvider` — `StreamProvider<List<RecurringTemplate>>`, all active templates.
- `runDueRecurringTemplatesProvider` — runs on app launch (in the same place Sprint 0's DB-open/auth flow already gates startup): for each active template where `lastRunMonth` isn't the current month AND today's day-of-month >= `dayOfMonth`, insert a `Transactions` row (type/amount/account/category from the template) and set `lastRunMonth` to current month. No user confirmation — matches the "auto-log" decision (fires silently, visible afterward in the transaction list like any other entry).

**`lib/features/recurring/recurring_templates_screen.dart`** (new, reached from Settings):
- List of templates: name, amount, account, category, day-of-month, active toggle.
- Add/edit form: name, type, amount, account picker, category picker, day-of-month (1–28).
- Delete via existing swipe/confirm pattern used in `transactions_screen.dart`.

## Salary & Budget Page

New file `lib/features/budget/budget_screen.dart`, reached from a Dashboard banner ("Salary → Allocate ▸", shown whenever the current month has income transactions but no `BudgetTargets` rows yet) and from Settings.

Single screen, two sections:

**① Allocate** — one row per active (non-archived, kind=`expense`) category: text field for `targetAmount`, toggle for `sweepToSavings`. A running "remaining to allocate" figure (this month's income total minus sum of entered targets) updates live. "Save Allocation" upserts `BudgetTargets` rows for the current month.

A final "+ Add category" row sits below the list. Tapping it reveals an inline text field (name only — `kind` is fixed to `expense` since this list only shows expense categories; icon/color take Sprint 1's existing defaults). Confirming calls the existing Sprint 1 category-create repository function; the new category then appears as a normal allocate row (target field + sweep toggle) in the same list, same session — no separate screen, no new table. Identical result to creating the category from Settings, just reachable without leaving Budget.

**② Unused Budget — Sweep** — computed list, not stored: for every `BudgetTargets` row this month with `sweepToSavings = true` and `leftover = targetAmount - spentSoFar > 0`, show category name + leftover amount + a "Sweep →" button. Categories with leftover ≤ 0 or sweep off don't appear — section shows an empty state ("Nothing to sweep yet") if the list is empty.

Tapping "Sweep →" on a category:
1. Requires `defaultSavingsAccountId` to be set — if not, prompt to pick one (one-time, stored in Settings) before proceeding.
2. Insert a `Transactions` row: type `transfer`, `amount = leftover`, `toAccountId = defaultSavingsAccountId`, note auto-filled (e.g. "Health budget sweep").
3. Update that category's `BudgetTargets.targetAmount` for the current month to `spentSoFar` (i.e., zero remaining) so it can't be swept twice or double-counted in progress bars.
4. Fire a local notification: "{category}: {amount} moved to Savings."

No bulk "sweep all" button — per-category only, per the approved design (keeps each sweep a deliberate action).

No automatic month-end job. No app-launch catch-up sweep logic. This is a deliberate simplification over the earlier auto-sweep idea — the user triggers every sweep manually from this page, whenever they decide the category won't be used further that period.

## Quick-Add (fast daily logging)

**Dashboard changes** (`lib/features/dashboard/dashboard_screen.dart`, extends Sprint 3's stat-card layout):
- Budget progress section added below the existing stat cards: one row per category with a `BudgetTargets` row this month — progress bar colored green (<80% of target spent), orange (80–100%), red (>100%).
- FAB added (dashboard currently has none) opening the quick-add bottom sheet.

New file `lib/features/transactions/quick_add_sheet.dart`:
- Bottom sheet (not a full route) with: numeric amount field (autofocus), category chip row (last 3 used categories pinned first, tap to select, "more" opens full picker), account dropdown (defaults to last-used account), optional note field.
- Save inserts directly into `Transactions` via the existing repository/provider from Sprint 2 — no new write path, just a faster entry surface reusing `transaction_form_screen.dart`'s underlying save logic.

## Overspend Notifications

Extends `runDueRecurringTemplatesProvider`'s app-launch check pattern: after any transaction insert (quick-add, full form, or recurring auto-log) that affects a category with a `BudgetTargets` row this month, recompute `spentSoFar` for that category and compare to `targetAmount`:
- Crossing 90% (from below) → fire local notification once: "{category} is at 90% of budget."
- Crossing 100% (from below) → fire local notification once: "{category} is over budget."
- Both checks are edge-triggered (fire once per threshold per month) — track via two new nullable bool-equivalent flags on `BudgetTargets` (`notified90`, `notified100`) reset when a new month's row is created.

Visual bar (green/orange/red) always reflects current state regardless of notification history — notifications are a one-time nudge, the bar is the persistent source of truth.

## Single-Account Onboarding Gate

App moves from unrestricted multi-account (Sprint 1) to a single-user, single-account model: the app assumes one account per user, but the underlying Accounts CRUD and schema are unchanged — only reachability changes.

- **Gate:** after PIN unlock, before any shell route (Dashboard/Budget/Transactions/etc.) is reachable, check `accounts` row count. If 0, force the existing `AccountFormScreen` (Sprint 1, reused as-is) — same router-gating pattern already used for PIN setup. Router doesn't allow navigation past this screen until an account is saved.
- **Post-creation:** once ≥1 account exists, the accounts list screen hides its "Add Account" FAB/entry point. Editing the existing account stays available.
- **Deletion:** account deletion (existing Sprint 1 flow) stays available; deleting the only account drops the count back to 0, so the gate re-triggers on next launch.
- No new screens, no new table. `BudgetTargets`/`RecurringTemplates`/`Transactions` continue to reference `accountId` exactly as designed above — with one account, every picker in Budget/Recurring/Quick-Add has exactly one option and can preselect it.

## Routing

New routes added to the existing `go_router` shell (`lib/core/router` or equivalent Sprint 0 setup):
- `/budget` → `BudgetScreen`
- `/recurring` → `RecurringTemplatesScreen`

Both reached via push from Dashboard/Settings, not part of the bottom-nav shell itself.

## i18n

New keys added to `fr.json`/`en.json`/`ar.json`/`ar-MA.json` in the same pass:
- `budget.*` — page title, allocate section header, remaining-to-allocate label, sweep section header, sweep button, sweep empty state, sweep confirmation toast text.
- `recurring.*` — screen title, add/edit form labels, day-of-month picker label.
- `dashboard.allocate_banner`, `dashboard.quick_add_hint`.
- `notifications.budget_90`, `notifications.budget_100`, `notifications.sweep_done`.

## Testing / Verification

- `flutter analyze` clean.
- Manual: allocate salary across categories, verify remaining-to-allocate math; log spend via quick-add and confirm progress bar color transitions at 80%/100%; add a recurring template with today's day-of-month, relaunch app, confirm single auto-logged transaction (and no duplicate on a second relaunch same month); sweep a category with leftover, confirm savings account balance increases and category shows zero remaining; confirm notifications fire once per threshold, not repeatedly.
- Manual: fresh install, confirm account-creation screen blocks Dashboard until first account saved; confirm "Add Account" entry point disappears after; delete the only account, relaunch, confirm gate re-triggers.
- Manual: from Budget's Allocate section, add a new category inline, confirm it persists (visible in Settings' category list too) and its target/sweep-toggle behave like any pre-existing category.
