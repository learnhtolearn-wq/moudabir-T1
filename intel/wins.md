# Goals and Milestones

*Revisit and reset periodically.*
*Last updated: 2026-08-02*

## Current Goals
- Working offline-first MVP covering all 9 epics, task by task per the original roadmap
- Pass security/encryption + offline + multilingual test pass (Phase 3)
- Closed beta via TestFlight/Internal Testing (Phase 4)
- Store publication FR/AR/EN (Phase 5)

## Full Phase Plan (source: plan de développement, 2026-08-02)

- [x] **Phase 0 — Cadrage technique** — stack, DB, chiffrement, auth, i18n, architecture decisions. Design maquettes/system already delivered by separate team (per user, this plan assumes design as input to Phase 1, not Phase 0 output). See decisions/ledger.md.
- [x] **Phase 1 — Socle technique (Sprint 0)** — repo/CI init, encrypted local DB schema (accounts/transactions/categories/goals), nav skeleton, i18n FR/AR/EN scaffold, PIN/biometric screen. NOTE: design-system component integration (buttons, transaction cards, category pickers) not yet pulled in — Figma still pending per intel/focus.md.
- [ ] **Phase 2 — MVP by functional lots**
  - [x] Sprint 1 — Accounts, categories, core data model (US-008, US-009, US-010 incl. loans/debts; account model for US-002/005/011) — shipped 2026-08-02
  - [ ] Sprint 2 — Income & expenses, core business logic (US-002, US-003, US-004 income; US-005, US-006, US-007 expenses; US-011 transfers)
  - [ ] Sprint 3 — Dashboard & history (US-001 summary; US-012, US-013, US-014 history/search/filters)
  - [ ] Sprint 4 — Savings goals (US-015, US-016)
  - [ ] Sprint 5 — Reports (US-017 category breakdown chart; US-018 income vs expense chart)
  - [ ] Sprint 6 — Settings & security finalize (US-019, US-020 backup/restore; US-021 notifications; US-022 custom dashboards/KPIs; Epic 9 finalize if not done in Phase 1)
  - [ ] Sprint 7 — Full multilingual finalization (FR/AR/EN complete, RTL testing, in-app language switch)
- [ ] **Phase 3 — Tests** — unit tests (balance calc, report aggregation), integration tests (DB encryption, backup/restore), manual offline-mode test, security tests (at-rest encryption, no log leaks), multilingual tests (RTL, truncation, date/amount formats), UI-vs-maquette conformity check
- [ ] **Phase 4 — Closed beta** — TestFlight (iOS) / Internal Testing (Android), feedback on dashboard ergonomics + quick entry, adjustments before publish
- [ ] **Phase 5 — Publication** — App Store/Play Store listings (screenshots x3 languages, description), privacy policy/GDPR conformity check, submission
- [ ] **Phase 6 — Post-launch** — crash monitoring (Sentry or equiv., anonymized technical logs only — no financial data), email support channel (48h SLA), V2 roadmap (multi-currency, widgets, PDF export, etc.)

## Open Clarification Points (from plan, not yet resolved)
- **MVP vs V2 split** — possible cut: Epics 1-5 + base security as MVP, defer reports/goals/custom dashboards to V2 for faster first release. Owner decision needed — not yet made.
- **Design deliverable timing** — exact date maquettes/design system land with dev team not yet specified; conditions real Phase 1/2 UI-polish start. Tracked as blocker in intel/focus.md.

Resolved already (see decisions/ledger.md): 2FA-without-cloud → PIN+biometric as two local factors. Notifications → local-scheduled only, no push/server.
