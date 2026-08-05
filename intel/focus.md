# Focus — Hybrid Budget Model QA + wrap-up

*Last updated: 2026-08-05*

## Top Priorities Right Now
- Hybrid budget model implementation complete (12/12 plan tasks, all reviewed) on branch `worktree-hybrid-budget-model`, `flutter analyze` clean, debug APK built clean. Manual QA on physical device in progress at session end — not yet fully confirmed, not yet merged to `master`.
- User wants to add "whatever he wants" in the Salary & Budget screen — scope unclear (inline category quick-create vs. free-text budget line). Needs a clarifying conversation, not yet started.
- `adb screencap` returns 0 bytes on the user's physical device (HyperOS/Xiaomi-family, model `2201117TY`) — agent can't visually verify UI on this device; logcat-only fallback for now.
- Sprint 6 (backup/restore, notifications, security finalize, PIN recovery/change-PIN) committed as `a3bc708`. Restore fix + backup export still need final device retest (flagged, not blocking).
- Sprint 7 (RTL polish) started — fixed currency locale formatting (5 sites) + Settings chevron mirroring. Needs device verification in AR/Darija.
- Figma design system still not pulled in (MCP hit View-seat quota) — blocks UI-polish only, not data-layer/CRUD work. File: https://www.figma.com/design/CfQ5K7ZLCEXglxOtqDg15L/Moudabir?node-id=1-2

## Hard Deadlines
None specified yet.

## Other Active Work
- Moroccan Darija (`ar-MA`) added as a 4th language, user-requested and verified working.
- PIN recovery code + change-PIN added (user-requested, beyond original Sprint 6 scope), device-verified working.
- iOS build still unverified — no macOS toolchain on this dev machine. Android FLAG_SECURE (screenshot block) shipped; iOS equivalent not built for the same reason.

---
*Update this file whenever priorities shift.*
