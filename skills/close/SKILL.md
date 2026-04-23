---
name: close
description: Clean end-of-session wrap — final checkpoint, summary report, and a handoff note the next session can pick up
---

Close the current AiDrift session cleanly. This does not kill the Claude Code conversation — it wraps up the drift-tracking side with a stable anchor and a handoff brief.

Step 1 — Snapshot state:
- Call MCP `aidrift_status` or run `drift status`. Capture score, trend, alerts, session ID, last checkpoint.
- Run `drift turn list | tail -10` to see recent turns.
- Run `git status -s` and `git log --oneline -10` if in a git repo.

Step 2 — If the session is in a good place (green or stable-amber), create a final checkpoint:
- `drift checkpoint create --summary "session close: <short summary of what was accomplished>"`
- If not in a good place, tell the user so — and suggest `/aidrift:rollback` or `/aidrift:recenter` **before** closing.

Step 3 — Generate a handoff note. Save it to `.aidrift/handoff.md` in the workspace (create `.aidrift/` if needed) with this structure:

```
# AiDrift Handoff — <ISO date>

**Session**: <session.id>
**Final score**: <score>  •  **Trend**: <trend>  •  **Alert**: <active reason or "none">
**Last stable checkpoint**: <id> — <summary>

## Accomplished this session
- <bullet 1>
- <bullet 2>
- ...

## In-flight / not finished
- <bullet, if any>

## Risks / drift signals to watch next time
- <bullet, if any>

## Git state at close
- Branch: <branch>
- HEAD: <sha> <subject>
- Dirty files: <list, or "clean">
```

The bullets come from your analysis of the turn list and git log, not invented. Be honest about what's done vs. in-flight.

Step 4 — Run `drift report` and show the user the key metrics inline.

Step 5 — Optionally, if the user asks to commit and push the handoff: follow `/aidrift:commit` then `/aidrift:push-gate`. Do not do this automatically — the handoff is often worth keeping local.

The session is not formally "closed" on the backend — AiDrift sessions stay open until explicitly ended. This skill prepares for a clean transition; the next prompt in a fresh Claude Code conversation will pick up via session-ensure.
