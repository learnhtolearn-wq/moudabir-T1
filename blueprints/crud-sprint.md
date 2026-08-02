# Blueprint — Feature CRUD Sprint

*Reusable SOP for building a "list + add/edit/delete" feature slice on top of the Sprint 0 Drift schema (Accounts, Categories, Transactions, Goals). First used: Sprint 1 (accounts + categories). Reuse for Sprint 2 (income/expense/transfer), Sprint 4 (goals), etc.*

---

## When to Use
Any sprint whose scope is "CRUD screens for table X" — i.e. the Drift table already exists (from Sprint 0) and the task is exposing create/read/update/delete/archive through UI.

## Stack Conventions (locked in, don't re-decide)
- **State mgmt:** Riverpod 2.6.1 — `StreamProvider`/`AsyncNotifierProvider` watching Drift's reactive `.watch()` queries, not `FutureProvider` for lists (need live updates on insert/edit/delete).
- **DB access:** Drift generated DAOs/companion classes (`XCompanion.insert(...)`, `.update()`, table `.select()...watch()`). No raw SQL.
- **Routing:** go_router. CRUD list screens hang off existing tabs (e.g. Settings → "Manage accounts" / "Manage categories") since the 5-tab shell (dashboard/transactions/goals/reports/settings) is fixed by Sprint 0 nav — do not add new bottom-nav tabs for CRUD sub-features. Use nested `GoRoute` push (not shell branch).
- **Soft delete:** Tables have `archived` boolean — "delete" in UI = set `archived: true`, never a hard `DELETE` (preserves referential integrity for Transactions/Goals that reference Accounts/Categories). Provide "archived items" filter, not a trash/undo flow (out of scope unless asked).
- **i18n:** Every user-facing string goes in `assets/translations/{fr,en,ar}.json` under a namespace matching the feature (e.g. `accounts.*`, `categories.*`). Never hardcode strings. Add all 3 languages in the same pass — do not leave AR/FR stubs for later.
- **Forms:** Flutter `Form` + `TextFormField` with inline validation (required fields, numeric parsing for amounts). Simple `AlertDialog` or full-screen route for add/edit — prefer full-screen route once a form has more than ~3 fields (accounts/categories qualify).
- **Currency/amount display:** `initialBalance`/`targetAmount` etc. are `real()` — format with `NumberFormat.currency` (intl, already a transitive dep via easy_localization) using the account's `currency` field.

## Steps
1. **Confirm scope** — which table(s), which US numbers, does it need a dedicated screen or does it slot into an existing placeholder screen (e.g. Settings).
2. **Docs check** — pull current Drift docs for reactive queries/companion updates via Context7 if available on this machine (currently unavailable — no node/npm — fall back to `drift.simonbinder.eu` official docs, per decisions/ledger.md 2026-08-02 precedent).
3. **Provider layer** — one Riverpod provider file per table under `lib/features/<feature>/providers/`: a `.watch()` stream provider for the list, plus notifier methods for insert/update/archive.
4. **UI layer** — list screen (`ListView` + empty state) and add/edit screen (form), under `lib/features/<feature>/`. Follow existing placeholder screen's `StatelessWidget` + `easy_localization` `.tr()` pattern until state is needed, then convert to `ConsumerWidget`.
5. **Wire routing** — add nested `GoRoute`s off the relevant shell branch.
6. **i18n** — add all strings to all 3 translation files in the same commit-worthy chunk.
7. **Verify** — `flutter analyze` clean, manual run confirms add/edit/archive round-trips and list updates live (no manual refresh needed — that's the point of `.watch()`).
8. **Report + log** — update `live/state.md`, mark sprint item in `intel/wins.md`, append to `decisions/ledger.md` only if a genuine new architectural call was made (not for routine CRUD following this Blueprint).

## Non-Goals (don't add unless asked)
- Multi-currency conversion logic (currency is stored per-account, no cross-rate math yet — that's V2 per intel/wins.md open clarification points).
- Undo/trash UI beyond the archived filter.
- Bulk import/export (that's Sprint 6, backup/restore).
