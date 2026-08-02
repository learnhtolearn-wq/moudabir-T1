# CLAUDE.md — Moudabbir
*Offline-first personal finance app for Android + iOS, powered by the Three Engine Model.*

---

## What This Is

Moudabbir — a mobile expense/finance manager (Android + iOS) that keeps all data on-device: no cloud, no backend, encrypted local DB, PIN+biometric auth, FR/AR/EN with RTL.

I run on the Three Engine Model: Architect reasons, Blueprint guides, Equipment executes.
I do not guess when inputs are unclear. I do not act without authority on consequential decisions.
Default mode: Read > Confirm > Sequence > Execute > Report > Improve.

Full model reference: references/three-engine-model.md

---

## Startup Protocol

Every session, before responding:
1. Read `live/state.md` — session context, open tasks, current priorities
2. Read `intel/focus.md` — what matters right now
3. If open or overdue items exist, mention them before diving in
4. Then respond to the request

For any workflow request (new feature, change, or fix):
1. READ the relevant Blueprint (if one exists)
2. MATCH — scan installed skills/MCP tools and use the one that fits the task; only work bare when nothing covers it
3. SCAN equipment/, .tmp/, .env for what's available
4. CONFIRM inputs are sufficient — stop and report if not
5. DOCS — pull current docs via Context7 before writing code against Flutter, Drift/Isar, sqlcipher_flutter_libs, local_auth, flutter_local_notifications, or any other package (web-search official docs as fallback)
6. SEQUENCE the steps before executing
7. EXECUTE, reporting each step (progress updates every 5 items on longer runs)
8. REPORT what was produced and where
9. IMPROVE — update the Blueprint if anything was learned

---

## Decision Tree

```
Blueprint missing?  > Ask: "No Blueprint for this. Create one or brief me directly?"
Equipment missing?  > Check equipment/ first. If nothing exists: ask before building.
Skill available?    > A matching installed skill/tool exists > use it, don't work bare.
Library code?       > Pull current docs via Context7 before writing code or pinning a version.
Inputs unclear?     > Stop. List what's missing. No assumptions.
Owner authority?    > Describe the decision and options. Never choose unilaterally.
Blueprint conflict? > "Blueprint says X but I'm seeing Y. Which takes priority?"
```

---

## North Star

Ship a fully working, secure, offline expense tracker covering all 9 epics — task by task, no MVP trimming — with FR/AR/EN + RTL support, on Android and iOS.

---

## Stack

Flutter · SQLite (Drift or Isar) encrypted with SQLCipher · key in Android Keystore/iOS Keychain · PIN+biometric auth (local_auth) · local-only scheduled notifications · Clean Architecture/MVVM + repository pattern · i18n FR/AR/EN with RTL. Zero cloud/backend for financial data — hard constraint. Full detail: intel/stack.md.

---

## Build Queue

Ranked per the original sprint roadmap (see intel/wins.md for full milestone list):

- [x] Sprint 0 (technical socle) — shipped 2026-08-02: `app/` Flutter project, Drift schema (accounts/categories/transactions/goals), sqlite3mc-encrypted DB, PIN+biometric lock, go_router bottom-nav shell, i18n FR/AR/EN scaffold. `flutter analyze` clean, debug APK verified on Android.
1. **Build this first — Sprint 1:** accounts + categories CRUD (incl. loans/debts) on top of the Sprint 0 schema
2. Sprint 2 — income, expenses, account transfers (core business logic)
3. Sprint 3 — dashboard summary, transaction history/search/filters
4. Sprint 4 — savings goals
5. Sprint 5 — reports (category breakdown, income vs. expense charts)
6. Sprint 6 — settings, local backup/restore, notifications, security finalize
7. Sprint 7 — full FR/AR/EN + RTL polish and testing

Parallel/ongoing: get Figma design system from design team — blocks UI-polish only, not data-layer work. iOS build still unverified (no macOS toolchain available here).

To build any of these: say "build [item]."

---

## Keeping the System Sharp

| When | Do this |
|------|---------|
| Each session end | Update live/state.md |
| When priorities shift | Update intel/focus.md |
| Periodically | Reset intel/wins.md with fresh goals |
| After meaningful decisions | Log in decisions/ledger.md |
| When a workflow solidifies | Add to blueprints/ |
| Same request comes up twice | Build it as a skill |

---

## File Map

| Location | Purpose |
|---|---|
| intel/ | Who you are, the build, focus, crew |
| live/ | Session state, tasks |
| decisions/ | The ledger — every meaningful call |
| templates/ | Reusable doc templates |
| references/playbooks/ | Repeatable processes |
| references/goldstandard/ | Output examples to match |
| blueprints/ | Workflow SOPs |
| equipment/ | Scripts — one job each |
| .tmp/ | Disposable, never committed |
| .env | Credentials — the only place they live |
| archive/ | Nothing gets deleted — moved here |

---

## Archive Rule

Nothing gets deleted. It gets moved to archive/.

---

*Command centre built: 2026-08-02*
