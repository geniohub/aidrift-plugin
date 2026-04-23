---
name: rollback
description: Rewind to the last stable checkpoint — shows you what would be discarded and asks before running destructive git commands
---

This skill helps the user rewind to a stable point. It **never runs destructive git operations without explicit user confirmation**.

Step 1 — Identify the target checkpoint:
- If the user named a checkpoint ID, use it. Run `drift checkpoint list` and find the match.
- Otherwise call `aidrift_status` (or `drift status`) and use `lastStableCheckpoint`.
- If neither yields a checkpoint, tell the user there's nothing to rewind to and stop.

Step 2 — Figure out what rewinding means. AiDrift checkpoints do not yet record git SHAs (that lands with the Git Provenance ledger). So rewind strategy depends on what's available:

- If the workspace is a git repo: run `git log --oneline -20` and `git status -s`. Correlate by timestamp — `checkpoint.createdAt` vs. commit timestamps. Show the user the 3 most likely revert targets with short SHAs, commit messages, and timestamps.
- If not a git repo, or if correlation is ambiguous: just print the checkpoint summary and say "no git provenance yet — revert manually or wait for the SessionCommit ledger."

Step 3 — Ask, don't act. Draft the exact git command the user would need to run (one of):
- `git reset --hard <sha>` — if they want to discard all changes since
- `git revert <sha>..HEAD` — if they want to preserve history
- `git stash && git checkout <sha>` — if they want to peek without losing current work

Present all three options with a one-line tradeoff each. **Do not execute any of them.** Wait for the user to pick.

If the user then picks one and says "go", run it and confirm. But if the tree has uncommitted changes, force a `git stash push -u -m "pre-rollback <checkpoint-id>"` first and tell them the stash label.

If auth fails, tell the user to run `drift auth login` and stop.
