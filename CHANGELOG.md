# Changelog

All notable changes to Moudabir, grouped by sprint/update. Newest first.

## Unreleased (v0.1.0+1, current build) — 2026-08-07
- Updated app logo/badge to match resized Figma master (splash 136→195px, lock/PIN-setup 88→126px)
- Regenerated launcher icons (Android + iOS) from new logo source

## v0.1.0+1 — Sprint 7: polish & hardening — 2026-08-06
- Timed splash screen, per-category icons, regenerated launcher icons
- Swapped vault-green accent for gold palette, hid bottom-nav labels
- Renamed app Moudabbir → Moudabir throughout
- Hid budget entry point from dashboard/settings, hid English in language picker
- Single-account UX simplification, biometric prompt host fix
- Blocked duplicate category names and deletion of in-use categories
- Synced UI to expanded Figma design system
- Locale-aware currency formatting, RTL chevron mirroring

## Hybrid budget model (salary allocation, recurring bills, quick-add) — 2026-08-05
- Single-account onboarding gate
- Salary & Budget screen: allocate + sweep flows, budget targets, overspend detection
- Recurring bill templates (list/add/edit), auto-run on app start, deferred until after PIN/biometric unlock
- Quick-add bottom sheet wired into transaction paths, double-tap guards
- Dashboard FAB, allocate banner, budget progress bars
- Branding assets, backup/security hardening pass

## Sprint 6 — settings & security finalize — 2026-08-02
- Local backup/restore, scheduled notifications, PIN recovery flow

## Sprint 4 & 5 — goals, reports, localization — 2026-08-02
- Savings goals
- Category-breakdown / income-vs-expense reports
- Darija (ar-MA) locale, category i18n fixes

## Sprint 3 — dashboard & transaction history — 2026-08-02
- Live dashboard totals (balance, monthly summary)
- Transaction list with search, type, and date-range filters
- fr/en/ar translations for dashboard + filters

## Sprint 2 — income, expenses, transfers — 2026-08-02
- Transaction form (income/expense/transfer toggle)
- Live transaction list, computed account balances
- Archived-account transactions excluded from dashboard totals

## Sprint 1 — accounts & categories — 2026-08-02
- Accounts + categories CRUD (including loans/debts)

## Sprint 0 — technical socle — 2026-08-02
- Flutter project scaffold, Drift schema (accounts/categories/transactions/goals)
- SQLite3MultipleCiphers-encrypted local DB
- PIN + biometric lock, go_router bottom-nav shell
- i18n FR/AR/EN scaffold
