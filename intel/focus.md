# Focus — Sprint 6 wrap-up

*Last updated: 2026-08-02*

## Top Priorities Right Now
- Sprints 1-5 committed. Sprint 6 (backup/restore, notifications, security finalize, + user-requested PIN recovery/change-PIN) built and mostly device-verified — restore had a silent-fail bug (file_picker null path on Samsung), just fixed, needs a retest before commit.
- Sprint 6 code sitting uncommitted in the working tree — commit once restore is re-confirmed and backup (export/share) is explicitly confirmed.
- Figma design system still not pulled in (MCP hit View-seat quota) — blocks UI-polish only, not data-layer/CRUD work. File: https://www.figma.com/design/CfQ5K7ZLCEXglxOtqDg15L/Moudabir?node-id=1-2

## Hard Deadlines
None specified yet.

## Other Active Work
- Moroccan Darija (`ar-MA`) added as a 4th language, user-requested and verified working.
- PIN recovery code + change-PIN added (user-requested, beyond original Sprint 6 scope), device-verified working.
- iOS build still unverified — no macOS toolchain on this dev machine. Android FLAG_SECURE (screenshot block) shipped; iOS equivalent not built for the same reason.

---
*Update this file whenever priorities shift.*
