# Session State

*Updated at the end of each session. Read this FIRST on startup.*

## Last Session
- **Date:** 2026-08-05 — design-only session (no code), spec doc committed as `0dcb0a5`.
- User wants a hybrid budgeting model, not pure after-the-fact logging: allocate salary into per-category targets on payday, auto-log known recurring bills, fast quick-add for daily variable spend, and — new idea from user mid-session — let unspent category budget (e.g. Health with no doctor visit that month) be swept into savings on the user's own timing, not automatically.
- Full brainstorming pass run via `superpowers:brainstorming` skill. Design settled: recurring templates auto-fire (no confirm step); category-level budget targets (not account-only); FAB + smart-defaults quick-add; overspend alert = visual bar + notification (both). Leftover sweep evolved during discussion from "auto month-end job" to a single **Salary & Budget page** the user opens themselves — section ① allocate salary into category targets, section ② lists only sweep-eligible categories with current leftover and a per-category "Sweep →" button (no bulk sweep, no background/app-open catch-up logic).
- Spec written to `docs/superpowers/specs/2026-08-05-hybrid-budget-model-design.md`, committed. Covers 2 new Drift tables (`BudgetTargets`, `RecurringTemplates`), new `budget_screen.dart` + `recurring_templates_screen.dart`, Dashboard FAB + quick-add bottom sheet + per-category progress bars, edge-triggered 90%/100% overspend notifications, new i18n keys. User was reviewing the spec in-IDE at session end — **not yet explicitly approved**, no implementation plan written yet.

## Prior Session
- **Date:** 2026-08-03 — first Figma design pull-in. User gave a node-specific URL (node 17:48, "5. Transactions") from file CfQ5K7ZLCEXglxOtqDg15L. Figma file only has ONE actual screen mockup (Transactions) plus a "Design System" doc page (colors, type, buttons, logo) — no Budget/Charges/Profil screens exist yet.
- Installed: bundled Noto Sans + Noto Sans Arabic + Roboto Mono as local font assets (`app/assets/fonts/`, chose over `google_fonts` package specifically because that fetches over network at runtime — conflicts with offline-first); extracted design tokens into `app/lib/core/theme/app_theme.dart` (AppColors/AppTextStyles/AppTheme) for reuse by every future screen; rebuilt TransactionsScreen to match the mockup (quick-add + Revenu/+ Dépense buttons, day-grouped list with Aujourd'hui/Hier headers, restyled cards) while keeping existing search/filter (not in the mockup, kept anyway — real feature).
- Bottom nav relabeled to match Figma's nav component: Dashboard→Accueil/Home, Goals→Budget, Reports→Charges/Bills, Settings→Profil/Profile (fr/en/ar/ar-MA). Screens themselves unchanged — only labels, since no designs exist yet for Budget/Charges/Profil.
- User found 2 bugs testing on device, both fixed: (1) quick-add "+ Dépense" still showed the full Revenu/Dépense/Virement type switcher after tap, looking like it ignored the choice — type switcher now hidden when opened via quick-add (only shows for the generic add path and when editing). (2) Removing the old generic FAB had silently dropped the only way to add a transfer transaction — added a small swap-icon button next to the two quick-add buttons.
- User then asked to add the app logo (Figma node 5:2, "Logo Moudabir" — full lockup with wordmark, no separate icon-only export). Cropped the icon-only mark (M + wallet, no text) out via PIL since launcher-icon size can't read the wordmark. Used `flutter_launcher_icons` (new dev dependency) to generate Android adaptive + iOS icons from it. Placed the same mark on lock screen, PIN setup screen, and the Transactions header avatar (previously a placeholder person icon). Scope was "everywhere" per user's explicit choice.
- Deploy snag: first `flutter install` after the logo changes silently reused a stale cached APK (timestamp predated the edits) — user correctly caught it ("nothing change"). Root cause not fully diagnosed (suspect `flutter install`'s own staleness check under this environment), worked around by explicit `flutter build apk --release` + direct `adb install -r` (adb at `C:\Users\fttah\AppData\Local\Android\Sdk\platform-tools\adb.exe`, not on PATH in the bash tool). **Use build+adb-install directly for future device deploys on this machine, not bare `flutter install`, until root cause is confirmed.**
- All of the above is uncommitted — nothing from this session is in git yet.

## Prior Session
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
- **Get user approval on hybrid budget model spec** (`docs/superpowers/specs/2026-08-05-hybrid-budget-model-design.md`), then run `superpowers:writing-plans` to turn it into an implementation plan — nothing built yet, design-only session.
- **Commit this session's work** (design system install, Transactions redesign, nav relabel, logo) — nothing committed yet.
- **Diagnose `flutter install` staleness bug** — reused a cached APK after source changes on this machine; worked around with `flutter build apk --release` + direct `adb install -r`, not root-caused.
- **Get design mockups for Budget/Charges/Profil tabs** from design team — currently just relabeled old Goals/Reports/Settings screens with no matching design, tracked as a gap, not silently treated as done.
- **Device-verify Sprint 7 RTL fixes** — switch to AR/Darija on physical device, confirm chevrons mirror in Settings and currency amounts format with correct locale conventions.
- **Retest restore correctly (same install)** — earlier "restore shows nothing / backup size unchanged" report traced to testing across an uninstall+reinstall (wipes Keystore passphrase, backup encrypted under old key can't decrypt — documented same-device-only limitation, not a bug). Retest by exporting and restoring within the same install, no uninstall in between.
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
- Land hybrid budget model: get spec approved, write implementation plan, build (new Sprint, not yet numbered in intel/wins.md)
- Commit this session's design-install + logo work (Transactions redesign, theme tokens, fonts, nav relabel, launcher icon)
- Get Budget/Charges/Profil mockups from design team — only Transactions has a real design so far
- Re-verify restore + confirm backup, then commit Sprint 6
- Sprint 7 (full FR/AR/EN + RTL polish and testing) — next build item per Build Queue once Sprint 6 closes out

## Active Work
- None — design install (fonts, theme tokens, Transactions redesign, nav relabel, app logo) shipped and device-verified by user this session, including a follow-up bugfix round (quick-add type switcher, missing transfer entry). Uncommitted.
