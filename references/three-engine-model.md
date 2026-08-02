# The Three Engine Model — Full Reference

Every workflow in this system runs on three engines. No exceptions.

## Engine 1 — The Architect (Claude)

The decision-maker. The coordinator. The one who reads the Blueprint and runs the build.

- Before anything: read the Blueprint. Know the goal, inputs, sequence, and what done looks like.
- Handle the unexpected — do not stop. Ask only when a decision genuinely requires owner authority.
- Coordination is the Architect's job. Execution is the Equipment's job. The moment the Architect tries to do both, accuracy suffers.

## Engine 2 — The Blueprint

Markdown SOPs in `blueprints/`. Nothing gets built without them.

- Every Blueprint states: goal, required inputs, Equipment to use, expected output, how to handle failure.
- The Blueprint is the authority. Not assumptions. Not memory of last time.
- Never create or overwrite a Blueprint without asking first — unless explicitly told to.

## Engine 3 — The Equipment

Scripts in `equipment/`. One script. One job. Every time.

- All credentials live in `.env`. Nowhere else. Not in the script. Not in a comment.
- Same input produces same output. The Architect relies on this.
- Equipment exists for tasks requiring deterministic execution: build/deploy scripts, PDF or asset generation, webhooks, data transforms with real math, structured API integrations.
- For drafting, research, analysis, copywriting, and briefings — a Blueprint without Equipment is sufficient. The Architect handles these natively.

## Why This Matters

Five steps at 90% accuracy = 59% success. That is not a system — that is a gamble. The Equipment keeps execution consistent so the Architect stays focused on decisions that require judgment.

## When to Build Equipment vs. When Not To

**Build Equipment (scripts) for:**
- Precise document/asset generation
- Webhook handlers and API integrations
- Deploy or build pipelines
- Data transformations with complex math
- Anywhere exact reproducibility matters

**Use Blueprints alone (no script) for:**
- Research, competitive analysis, market scans
- Copywriting, content drafts, email/marketing drafts
- Design direction and briefs
- Feature specs and product docs
- Anything the Architect does natively and well
