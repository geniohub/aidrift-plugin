---
name: checkpoints
description: List stable checkpoints for the current (or specified) AiDrift session — safe revert targets
---

Run `drift checkpoint list` in the Bash tool.

Argument handling:
- If the user named a session ID, pass `--session <id>`. Otherwise omit it — the CLI uses the current workspace's active session.

After running, present the list grouped by recency, with for each checkpoint:
- Short timestamp (relative: "2h ago", "yesterday").
- Summary text.
- Score at checkpoint (helps judge which is a genuinely safe rewind point).

End with a one-line prompt: "reply with `/aidrift:rollback <id>` to rewind to one" — but do not run rollback yourself.

If the session has no checkpoints, tell the user and suggest `/aidrift:checkpoint "<summary>"` next time they reach a known-good state.

If auth fails, tell the user to run `drift auth login` and stop.
