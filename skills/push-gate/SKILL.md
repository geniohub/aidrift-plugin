---
name: push-gate
description: Pre-push drift check — blocks the push if the session is red, shows which commits would ship with drift warnings
---

Gate a git push on AiDrift state. Steps:

Step 1 — Check drift state. Call MCP `aidrift_status` (or `drift status`).

Step 2 — Inspect the pushable range:
- Run `git fetch <remote>` (default `origin`) with a short timeout.
- Run `git log --format='%H %s' @{u}..HEAD` to list local commits that would ship. If upstream is unset, use `git log --format='%H %s' HEAD ^origin/HEAD`, or fall back to "all commits on this branch."
- For each commit, look for AiDrift trailers (`git log --format='%B' -1 <sha> | grep '^AiDrift-'`). Commits without trailers were made outside the drift gate — flag them but don't block on that alone.

Step 3 — Decide:
- **Green / stable session + no red trailer in range**: proceed. Run `git push` and report.
- **Amber session**: warn and require confirmation.
- **Red session OR any commit in range has `AiDrift-Score` below 0.5**: refuse. Print the offending commits and suggest `/aidrift:recenter`, `/aidrift:rollback`, or `git reset --soft` to redo them with a healthier score. Only proceed if the user types `--force` or explicitly says "push anyway, I accept the risk".

Step 4 — Execute:
- Never use `--no-verify` unless the user explicitly asked.
- Never force-push to `main` or `master`. If the user wants a force-push to a feature branch, print the command and ask for confirmation before running it.
- After pushing, report the remote ref and suggest `/aidrift:report` for a post-push summary.

If drift status is unavailable: fall back to a plain push, but tell the user the drift gate was bypassed so they know.
