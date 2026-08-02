# Stack

## The Build
Personal finance/expense manager, mobile (Android + iOS). Offline-first, zero cloud dependency, data never leaves device. 9 epics: accounts, income, expenses, categories, dashboard, transaction history/search, savings goals, reports (charts), settings/backup/security. i18n FR/AR/EN with RTL for Arabic.

## Tech / Platform
- **Framework:** Flutter (single codebase, strong offline DB + animation support)
- **Local DB:** SQLite via Drift or Isar, encrypted with SQLCipher
- **Key storage:** Android Keystore / iOS Keychain
- **Auth:** PIN + biometric (local_auth package) — treated as the app's "two local factors," no SMS/email 2FA, no server
- **Notifications:** local scheduled only (flutter_local_notifications) — no push, no backend
- **i18n:** flutter intl / easy_localization, FR/AR/EN, RTL support for Arabic
- **Architecture:** Clean Architecture / MVVM + repository pattern (isolates local DB, future-proofs for optional sync)
- **Crash monitoring (post-launch):** Sentry or equivalent, technical/anonymized logs only — never financial data

## Already Built vs. Open
- **Done:** Full French functional spec (9 epics, US-001 to US-022), phased roadmap (Phase 0–6), architecture decisions locked (this session).
- **Open / pending:** Figma design system and mockups — being delivered by a separate design team, not yet received. Blocks UI-polish sprints; does not block data-layer/scaffold work.

## Constraints
- No cloud/backend for financial data (hard requirement).
- Must support offline mode fully — no feature depends on network.
- Must ship on both Android and iOS.
- Budget/timeline: not specified.
