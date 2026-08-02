# Session State

*Updated at the end of each session. Read this FIRST on startup.*

## Last Session
- **Date:** 2026-08-02 (Sprint 6 committed as `a3bc708`; Sprint 7 started same session)
- **Sprint 7 started:** scoped to RTL visual audit + fixes (user chose this over adding automated widget tests). Code-level audit found 2 bugs, both fixed: (1) `NumberFormat.currency()` calls in dashboard/accounts/transactions/goals/reports never passed `locale:`, so amounts always rendered with US grouping/decimals regardless of active language — unlike `DateFormat` calls which already did this correctly; fixed by adding `locale: context.locale.toString()` to all 5 sites. (2) Settings screen's 4 trailing chevron icons didn't mirror in RTL — fixed via `Directionality.of(context)` check. Needed `hide TextDirection` on easy_localization's import in settings_screen.dart (it re-exports intl's bidi TextDirection, shadowing dart:ui's). `flutter analyze` clean. **Not yet device-verified in AR/Darija.**
- **Date:** 2026-08-02 (Sprint 6)
- **Summary:** Sprint 4 (goals) + Sprint 5 (reports) + Darija/category-i18n work from the prior session was committed at session start (`a44086c`) — was sitting uncommitted for two sessions.
- Sprint 6 built: backup/restore (`share_plus`/`file_picker`, encrypted DB file, same-device only — see decisions/ledger.md), notifications (daily expense reminder + goal-deadline nudges via `flutter_local_notifications`/`timezone`), and security finalize (auto re-lock on background/resume, PIN lockout after 5 attempts, Android `FLAG_SECURE`). US-022 (custom dashboards/KPIs) deferred to V2 per user decision — no spec existed for it.
- User then asked for offline PIN recovery + change-PIN (not in original scope). Added: one-time recovery code (Crockford-base32, shown once at PIN setup and regenerated after every use), `ForgotPinScreen` (recovery code → new PIN), `ChangePinScreen` (Settings), and a Settings entry to manually regenerate the recovery code.
- Hit a Gradle build failure (`file_picker`'s transitive dep needs compileSdk 36; app-level override doesn't cascade to plugin subprojects) — fixed via `subprojects { afterEvaluate { compileSdk = 36 } }` in android/build.gradle.kts, ordered before `evaluationDependsOn(":app")`.
- User found two bugs during manual verification, both fixed and rebuilt:
  1. RecoveryCodeScreen's "Continue" button did nothing after PIN setup/reset — both callers used `pushReplacement`, which disposes the caller's BuildContext before `onContinue` (closing over it) ever fires. Fixed by passing the screen's own live context into the callback instead.
  2. Restore backup did nothing, no error — `file_picker` returned a null `path` for the picked file on the user's Samsung device (SAF quirk). Fixed by requesting `withData: true` and writing bytes directly when available.
- User-verified working on physical device (Android 11): forgot-PIN flow, change PIN, regenerate recovery code, reminders (toggle + time), auto-lock on background/resume. **Restore fix just rebuilt/reinstalled, not yet re-verified by user** — was still-broken before the bugfix, needs a retest. Backup (the export/share-sheet half) not explicitly confirmed either.
- Session ends with all Sprint 6 code **uncommitted**.

## Open Tasks
- **Device-verify Sprint 7 RTL fixes** — switch to AR/Darija on physical device, confirm chevrons mirror in Settings and currency amounts format with correct locale conventions.
- **Verify the restore fix** — user needs to retest Settings → Restore now that `withData: true` is in place; last known state was broken (silent no-op).
- **Confirm backup (export/share sheet) works** — not explicitly confirmed by user this session, only restore was flagged as broken.
- **Commit Sprint 6** once the above is confirmed — nothing from this session is committed yet.
- **Resume design implementation** — paused, blocked on Figma MCP quota (View seat, Professional plan). User will send manual screenshots + tokens for the Dashboard pilot screen when ready. New Blueprint to be created for this (not yet written — needs go-ahead per permissions.md, already granted for concept, not yet drafted).
- Verify iOS build (not yet tested — no macOS toolchain on this dev machine). iOS equivalent of `FLAG_SECURE` (screenshot/recording block) also not built for the same reason.
- Get Figma design system from design team (blocker for UI-polish only, not data layer) — CRUD screens built with plain Material widgets, not yet restyled to design system
- Context7 unavailable on this dev machine (no node/npm) — used official pub.dev/drift docs directly instead; revisit if Context7 becomes available
- Open clarification points still unresolved (see intel/wins.md): MVP/V2 scope split, design delivery date
- Minor Sprint 2 follow-ups (non-blocking, noted during code review): missing `default`/assert branch in `accountBalanceProvider`'s type switch (silent no-op on corrupted `type` data), `ListView.builder` rows in transactions/accounts/goals lists have no stable `key:`, `transactions.archive_title`/`archive_confirm` i18n key names imply soft-archive but back a hard delete (naming inherited from the plan, worth a rename pass later)
- Dashboard totals mix currencies if accounts use different currencies (formatted with hardcoded `MAD` symbol as a known simplification, matching the existing multi-currency V2 deferral) — revisit if/when multi-currency conversion is built
- Stale git branch `worktree-sprint2-transactions` (already merged, same commit as master) — safe to delete, low priority
- Darija (`ar-MA`) built-in Material widget strings (date pickers etc.) fall back to standard Arabic since Flutter's `GlobalMaterialLocalizations` resolves by languageCode only, ignoring country — known/accepted tradeoff, not a bug to fix

## Current Priorities
- Re-verify restore + confirm backup, then commit Sprint 6
- Sprint 7 (full FR/AR/EN + RTL polish and testing) — next build item per Build Queue once Sprint 6 closes out
- Resume design pass on Dashboard once screenshots/tokens are provided

## Active Work
- None — Sprint 6 code complete, most of it device-verified. Restore fix just shipped, awaiting user retest. Not yet committed to git.
