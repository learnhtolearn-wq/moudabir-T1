# Stack

## The Build
Personal finance/expense manager, mobile (Android + iOS). Offline-first, zero cloud dependency, data never leaves device. 9 epics: accounts, income, expenses, categories, dashboard, transaction history/search, savings goals, reports (charts), settings/backup/security. i18n FR/AR/EN with RTL for Arabic.

## Tech / Platform
- **Framework:** Flutter (single codebase, strong offline DB + animation support)
- **Local DB:** SQLite via Drift, encrypted with SQLite3MultipleCiphers (sqlite3mc) — the successor to the now-EOL sqlcipher_flutter_libs, wired via Dart build hooks (`hooks: user_defines: sqlite3: source: sqlite3mc` in pubspec.yaml)
- **Key storage:** Android Keystore / iOS Keychain
- **Auth:** PIN + biometric (local_auth package) — treated as the app's "two local factors," no SMS/email 2FA, no server
- **Notifications:** local scheduled only (flutter_local_notifications) — no push, no backend
- **i18n:** flutter intl / easy_localization, FR/AR/EN, RTL support for Arabic
- **Architecture:** Clean Architecture / MVVM + repository pattern (isolates local DB, future-proofs for optional sync)
- **Crash monitoring (post-launch):** Sentry or equivalent, technical/anonymized logs only — never financial data

## Already Built vs. Open
- **Done:** Full French functional spec (9 epics, US-001 to US-022), phased roadmap (Phase 0–6), architecture decisions locked. **Sprint 0 shipped** (2026-08-02): Flutter project scaffolded in `app/`, Drift schema (Accounts/Categories/Transactions/Goals) with sqlite3mc encryption + Keystore/Keychain-stored passphrase, PIN+biometric lock flow, go_router bottom-nav shell (5 tabs), easy_localization FR/AR/EN scaffold, debug APK builds clean (`flutter analyze` 0 issues, `flutter build apk --debug` succeeds).
- **Open / pending:** Figma design system and mockups — being delivered by a separate design team, not yet received. Blocks UI-polish sprints; does not block data-layer/scaffold work. iOS build not yet verified (no macOS toolchain on this machine — Android verified only).

## Constraints
- No cloud/backend for financial data (hard requirement).
- Must support offline mode fully — no feature depends on network.
- Must ship on both Android and iOS.
- Budget/timeline: not specified.
