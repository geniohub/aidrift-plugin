---
name: checkpoint
description: Pin the current session state as a named stable checkpoint — a safe revert point you can return to later
---

Create a checkpoint by running `drift checkpoint create --summary "<summary>"` in the Bash tool. The CLI defaults to the active session and latest turn, so no session/turn args are needed in the common case.

Argument handling:
- Required: a human-readable summary. If the user gave one ("finished auth refactor", "tests green after migration"), use it. If they didn't, generate a 1-line summary from the recent conversation — what was just completed, what's now stable. Keep it under 120 chars.
- Pass `--session <id>` only if the user specified one.
- Pass `--turn <id>` only if the user specified one.

After running, confirm in one line with the checkpoint ID and summary.

Optional follow-up: if the repo is a git repo (`git rev-parse --git-dir` succeeds) and the working tree is clean (`git diff --quiet && git diff --cached --quiet`), mention the current HEAD SHA alongside — it's the natural revert target. Do **not** commit automatically.

If the CLI reports no active session, tell the user there's nothing to checkpoint yet — they need to prompt Claude at least once so the session-ensure hook runs.

If auth fails, tell the user to run `drift auth login` and stop.
