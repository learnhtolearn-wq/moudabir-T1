---
name: moudabir-progress
description: Use when tracking work on the Moudabir Flutter finance app — logging what was built this session, updating live/state.md, intel/focus.md, or decisions/ledger.md, or producing a detailed progress/work report for this project. Trigger phrases: "/moudabir-progress", "track my work", "log this work", "update work log", "what did I build", "session summary", "log progress" (Moudabir context).
---

# Moudabir Progress Tracker

## Overview
Work-tracking skill for the Moudabir project (see project CLAUDE.md). Two jobs: (1) **log** — record what got built this session into the project's own tracking files, (2) **report** — read those files plus live repo state and produce a detailed status report. Not a generic-progress skill (that's zerostop-progress, a different project) — this one is scoped to Moudabir's file map.

## When to Use
- End of a work session (or when told to) → **log** mode
- User asks "progress", "where are we", "what's done", "give me details" → **report** mode
- Do NOT use for creating Blueprints or Equipment — those follow permissions.md (ask first)

## File Map (Moudabir-specific)
| File | Holds |
|---|---|
| `live/state.md` | Last session summary, open tasks, current priorities |
| `intel/focus.md` | Top priorities right now, deadlines |
| `intel/wins.md` | Sprint/milestone list, goals |
| `decisions/ledger.md` | Append-only decision log (DECISION / REASONING / CONTEXT) |
| `app/lib/` | Actual Flutter source — ground truth for "what's built" |

## Log Mode — Steps
1. Diff against last recorded state: `git log --oneline -20`, `git status`, and compare `app/lib/` tree against what `live/state.md` last described.
2. Identify: files added/changed, features completed, decisions made (new lib choices, architecture calls, blockers hit/cleared).
3. Update `live/state.md`: move current "Active Work" into "Last Session" summary, refresh "Open Tasks" and "Current Priorities".
4. If a new hard decision was made (framework/library/architecture choice), append one line to `decisions/ledger.md` — never edit past entries, append-only.
5. If priorities shifted, update `intel/focus.md`.
6. Report back what was updated, in 3-5 lines.

## Report Mode — Steps
1. Read `live/state.md`, `intel/focus.md`, `intel/wins.md`, `decisions/ledger.md`.
2. Cross-check claims against ground truth: `flutter analyze`-worthy files under `app/lib/` (Glob/Grep, not full read) — confirm sprint items marked "done" actually have corresponding code, flag any drift.
3. Compute progress: sprints done / total sprints in `intel/wins.md` milestone list = overall %.
4. **Output inline as an ASCII text block in the chat response — never an Artifact link, never a table.** User standing preference: always see the chart directly in the context window. Use this exact template, filled with live data (bar = 27 chars, `█` filled / `░` empty, proportional to %; status icons ✅ shipped / 🔵 next up / ⬜ pending / 🟠 blocked):

```
MOUDABIR — BUILD DASHBOARD
<subtitle: what the app is, sprint count>

OVERALL PROGRESS: NN%  [bar]  X/Y shipped
CURRENT SPRINT:   <name — one-line focus>
OPEN BLOCKERS:    <count> (<short names>)

SPRINT PROGRESS
S0  <name>            [bar] NNN%  <icon> <status>
... one row per sprint ...

BLOCKERS & RISKS
<icon> <Tag>   — <one line>
...

RECENT DECISIONS
<date>  <decision> (<short why>)
...
```

## Common Mistakes
- Reporting sprint as "done" from state.md without checking `app/lib/` actually has the files — state.md can drift from reality.
- Editing/deleting past `decisions/ledger.md` entries — it's append-only, always.
- Confusing this with `zerostop-progress` (different project, different file map).
