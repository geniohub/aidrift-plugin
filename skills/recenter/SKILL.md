---
name: recenter
description: Drift is amber/red — read the status signals and draft a re-anchor message to get the session back on track
---

This skill does **not** modify any code or state. It diagnoses and drafts.

Step 1 — Read current state:
- Call the MCP tool `aidrift_status` (or run `drift status` if MCP unavailable) for the current workspace.
- Also glance at recent turns: `drift turn list | tail -5` for context.

Step 2 — Diagnose. Identify which of these drift patterns is in play (usually just one or two dominate):
- **Scope creep**: edits are touching files outside the stated task.
- **Topic shift**: the last few prompts are about something different than the session task.
- **Test breakage**: tests that were passing are now failing.
- **File churn**: the same file has been rewritten many times in a row.
- **Dead-end refactor**: lots of edits, no forward progress (no green tests, no new behavior).

Step 3 — Draft a re-anchor message. This is the output. Format:

```
Drift signal: <one-line diagnosis>

Recommended re-anchor prompt:
"<a concrete, narrow prompt the user can paste back to restart the session cleanly>"

Suggested next actions:
- /aidrift:checkpoint "<summary>" — if any part of the work is genuinely stable
- /aidrift:rollback — if the drift is worse than the progress
- /aidrift:scope <paths> — if scope creep is the driver, lock the allowed paths
```

The re-anchor prompt should be specific: which files to touch, which to leave alone, and what the single next step is.

Do not run `/aidrift:rollback`, `/aidrift:checkpoint`, or any git command from this skill. Only diagnose and recommend.
