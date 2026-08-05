# Focus — Hybrid budget model: plan done, build next

*Last updated: 2026-08-05*

## Top Priorities Right Now
- Hybrid budget model plan (14 tasks) committed at `docs/superpowers/plans/2026-08-05-hybrid-budget-model.md` — spec approved, nothing built yet. Next session: execute via `superpowers:subagent-driven-development` or `superpowers:executing-plans`.
- First Figma design pull-in shipped earlier session (Transactions screen, shared theme tokens, bundled fonts, nav relabel, app logo) — device-verified by user, **still uncommitted**. Commit before/alongside budget build.
- Figma file (CfQ5K7ZLCEXglxOtqDg15L) only has ONE real screen mockup (Transactions) — Budget/Charges/Profil tabs are old Goals/Reports/Settings screens just relabeled. Need actual mockups from design team before those get restyled.
- Sprint 6 (backup/restore, notifications, security finalize, PIN recovery/change-PIN) committed as `a3bc708`. Restore/backup retest false-alarmed on an uninstall+reinstall (Keystore passphrase wipe, documented limitation) — needs a clean same-install retest, not a code fix.
- Sprint 7 (RTL polish) committed as `a7d4711` — currency locale formatting (5 sites) + Settings chevron mirroring. Needs device verification in AR/Darija.

## Hard Deadlines
None specified yet.

## Other Active Work
- Moroccan Darija (`ar-MA`) added as a 4th language, user-requested and verified working.
- PIN recovery code + change-PIN added (user-requested, beyond original Sprint 6 scope), device-verified working.
- iOS build still unverified — no macOS toolchain on this dev machine. Android FLAG_SECURE (screenshot block) shipped; iOS equivalent not built for the same reason.

---
*Update this file whenever priorities shift.*
