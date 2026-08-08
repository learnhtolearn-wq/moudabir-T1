# Focus, repo consolidated on GitHub, naming decision + QA backlog next

*Last updated: 2026-08-08*

## Top Priorities Right Now
- **Repo consolidation done this session:** `origin` now points at `github.com/learnhtolearn-wq/moudabir-T1` (pushed). Pulled 4 new commits from `github.com/oraw-light/moudabir` (added as remote `upstream`, pull-only), fast-forwarded `master` to `78ba3da`. That pull included an app-wide rename **Moudabbir to Moudabir**, which conflicts with this project's own `CLAUDE.md` title and Build Queue wording, flagged to user, awaiting a decision (keep the new name, revert it, or update CLAUDE.md to match).
- **Ground-truth correction:** the "uncommitted design work" and "needs a commit" items below and in `live/state.md`'s older entries are stale, `git log` confirms the Figma widget-library sweep, the 2026-08-03 design-install session, Sprint 6, and Sprint 7 are all committed on `master` as of this session.
- **Figma design system sweep** (full sweep, user-confirmed scope): shared widget library `app/lib/core/widgets/app_widgets.dart` (ScreenHeader, AppTextField, AppSelectField/AppOptionTile/showAppOptionSheet, CategoryBadge, ProgressGauge, AppListItem, AppIconAvatar) built from the Figma file's newer components and wired into every screen still on plain Material (Dashboard, Transactions, Goals, Reports, Settings, Budget, Categories, Accounts, Recurring + all their form screens). `flutter analyze` and `flutter build apk --debug` both clean. **Not yet device-verified**, needs a visual pass on a real device/emulator before trusting it.
- Hybrid budget model implementation complete (**14/14 plan tasks**), merged to `master`. **Manual QA on physical device still needs a fresh pass** (previous partial walkthrough predates Task 13 and the pre-auth fix).
- User wants to add "whatever he wants" in the Salary & Budget screen, scope unclear (inline category quick-create vs. free-text budget line). Needs a clarifying conversation, not yet started.
- `adb screencap` returns 0 bytes on the user's physical device (HyperOS/Xiaomi-family, model `2201117TY`), agent can't visually verify UI on this device; logcat-only fallback for now.
- Sprint 6 (backup/restore, notifications, security finalize, PIN recovery/change-PIN) committed as `a3bc708`. Restore fix + backup export still need final device retest (flagged, not blocking).
- Sprint 7 (RTL polish) committed as `a7d4711`, currency locale formatting (5 sites) + Settings chevron mirroring. Needs device verification in AR/Darija.

## Hard Deadlines
None specified yet.

## Other Active Work
- Moroccan Darija (`ar-MA`) added as a 4th language, user-requested and verified working.
- PIN recovery code + change-PIN added (user-requested, beyond original Sprint 6 scope), device-verified working.
- iOS build still unverified, no macOS toolchain on this dev machine. Android FLAG_SECURE (screenshot block) shipped; iOS equivalent not built for the same reason.

---
*Update this file whenever priorities shift.*
