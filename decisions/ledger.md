# Decision Ledger

Append-only. Every meaningful call gets logged here.
Format: [YYYY-MM-DD] DECISION: ... | REASONING: ... | CONTEXT: ...

---
[2026-08-02] DECISION: Framework = Flutter | REASONING: better offline local-DB perf (Drift/Isar), single codebase for iOS+Android, strong animation support for dashboards | CONTEXT: Intake, stack pick
[2026-08-02] DECISION: Local DB = SQLite (Drift or Isar) encrypted with SQLCipher, key in Keystore/Keychain | REASONING: hard requirement — offline-first, zero cloud, financial data must be encrypted at rest | CONTEXT: Original spec, Phase 0 cadrage
[2026-08-02] DECISION: Auth = PIN + biometric only, no SMS/email 2FA, no server | REASONING: "2FA without cloud" resolved as local PIN+biometric = two local factors; avoids contradicting no-cloud requirement | CONTEXT: Intake, 2FA/notif question
[2026-08-02] DECISION: Notifications = local scheduled only (flutter_local_notifications), no push/backend | REASONING: keeps app 100% offline-first, matches no-cloud constraint | CONTEXT: Intake, 2FA/notif question
[2026-08-02] DECISION: Architecture = Clean Architecture / MVVM + repository pattern | REASONING: isolates local DB, eases testing, keeps door open for optional future sync without rewrite | CONTEXT: Original spec, Phase 0 cadrage
[2026-08-02] DECISION: i18n = FR/AR/EN with RTL from day one | REASONING: hard requirement in original spec | CONTEXT: Original spec
[2026-08-02] DECISION: Scope = build all 9 epics, task by task, in original sprint order (no MVP trimming) | REASONING: explicit user instruction | CONTEXT: Intake, scope question
[2026-08-02] DECISION: Design system pending from separate team, tracked as blocker for UI sprints only | REASONING: data-layer/backend work not blocked by missing mockups | CONTEXT: Intake, design question
