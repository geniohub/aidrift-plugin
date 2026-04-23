---
name: commit
description: Drift-gated git commit — refuses on red scores unless forced, adds AiDrift provenance trailers
---

Run a drift-aware git commit. Steps:

Step 1 — Check drift state. Call MCP `aidrift_status` (or `drift status`). Record:
- `currentScore`, `trend`, `alert.active`, `alert.reasons`, `session.id`, `lastStableCheckpoint.id` (if any).

Step 2 — Decide whether to proceed:
- **Green / stable** (score >= 0.7, no active alert): proceed.
- **Amber / caution** (0.5 <= score < 0.7, or trend=drifting without alert): warn the user with a one-line summary of why it's amber, ask if they want to commit anyway. Do not proceed until they confirm.
- **Red / drift alert active** (score < 0.5, or `alert.active` true): refuse. Tell the user exactly what's flagged. Suggest `/aidrift:recenter` or `/aidrift:rollback`. Proceed only if the user types `--force` or explicitly says "commit anyway, I accept the risk".

Step 3 — Stage + commit. Follow the standard Claude Code git commit flow (git status, git diff, git log for style), but:
- Add these trailers to the commit message, right before any `Co-Authored-By` line:
  ```
  AiDrift-Session: <session.id>
  AiDrift-Score: <currentScore formatted to 2 decimals>
  AiDrift-Trend: <trend>
  ```
  And if `lastStableCheckpoint` is non-null:
  ```
  AiDrift-Checkpoint: <lastStableCheckpoint.id>
  ```
- Respect the repo's existing commit identity. If this is a public `geniohub/*` repo, use the `GenioHub <support@geniohub.com>` identity (already configured globally on the user's machine).

Step 4 — After the commit, create an AiDrift checkpoint anchored to this commit:
- Run `drift checkpoint create --summary "commit: <first line of commit msg>"`. This records the commit as a stable point so future rollbacks can target it.
- Do not push. Pushing is `/aidrift:push-gate`.

If drift status is unavailable (CLI not installed, not logged in, network error): skip the gate and commit normally, but add a one-line note to the user that the drift gate was bypassed because AiDrift wasn't reachable. Do not silently skip — users should know when the safety net is off.
