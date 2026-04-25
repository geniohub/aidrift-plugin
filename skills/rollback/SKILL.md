---
name: rollback
description: Rewind to the last stable checkpoint — shows the six-predicate safety preview and asks before running destructive git commands
---

This skill helps the user rewind to a stable point. It **never runs destructive git operations without explicit user confirmation**.

Step 1 — Identify the target SHA.
- If the user named a SHA or short SHA, use it.
- Otherwise call `aidrift_status` (or `drift status`) and read `lastStableCheckpoint.gitSha`. The Git Provenance ledger now stamps every checkpoint with the HEAD SHA at checkpoint time, so this is the SHA-linked path.
- If `lastStableCheckpoint` is null, tell the user there's nothing to rewind to and stop.
- If `lastStableCheckpoint.gitSha` is null (legacy checkpoint, pre-Git-Provenance), fall back to the timestamp-correlation flow at the bottom of this file.

Step 2 — Run the six-predicate safety preflight against the target SHA. Each line below is a single shell command; record the result for each predicate.

| # | Predicate | Command | Pass when |
|---|---|---|---|
| 1 | Working tree clean | `git status --porcelain` | output is empty |
| 2 | Target SHA exists in repo | `git cat-file -e <sha>` | exit 0 |
| 3 | No unpushed commits between HEAD and target | `git rev-list <sha>..HEAD --not @{upstream} 2>/dev/null \| wc -l` | result is `0` |
| 4 | No pushed commits between HEAD and target | `git rev-list <sha>..@{upstream} 2>/dev/null \| wc -l` (if @{upstream} exists) | result is `0` |
| 5 | No leaked secrets at or before target | (server signal — `aidrift_status.secretFindings`, ships with Phase 3 of Git Provenance) | empty / not yet shipped |
| 6 | Target's scope distance ≤ current | compare `aidrift_status.sessionMap.scopeDistance` (current) vs. the score at the checkpoint | target ≤ current |

Step 3 — Show the user a one-screen safety summary:

```
target: <short-sha> "<commit subject>" (<branch>)  scope=<x.xx>
preflight:
  ✓ working tree clean         (or ✘ stash needed)
  ✓ sha exists in repo
  ✓ no unpushed commits between (or ⚠ N unpushed)
  ✓ no pushed commits between   (or ⚠ N pushed — would need force-push)
  · leaks at target: not checked (Phase 3)
  ✓ scope improves: 0.42 → 0.18
fits one-click revert: YES / NO
```

When `fits` is YES, all six predicates pass; the user can safely `git reset --hard <sha>`.

Step 4 — Pick the right command based on which predicate failed. Present **only** the relevant option(s); don't dump every variant:

- **Working tree dirty** → prefix any choice with `git stash push -u -m "pre-rollback <sha>"`. Tell the user the stash label so they can `git stash pop` later.
- **Pushed commits between HEAD and target (predicate 4 failed)** → recommend `git revert <sha>..HEAD` (preserves history). Warn that `git reset --hard` would require a force-push.
- **Otherwise** → `git reset --hard <sha>` is the cleanest path.

Always include `git stash && git checkout <sha>` as a "peek without losing work" fallback if the user is unsure.

Step 5 — Ask, don't act. **Do not execute the command.** Wait for the user to type "go" / "do it" / similar before running it.

If the user confirms, run the chosen command (with the stash prefix if predicate 1 failed) and confirm by re-running `git log --oneline -3` so the user sees the new HEAD.

After a successful rollback, run `drift checkpoint create --summary "post-rollback to <short-sha>"` so the new state is itself a stable point.

If auth fails at any step, tell the user to run `drift auth login` and stop.

---

### Fallback: legacy (pre-Git-Provenance) checkpoints with no `gitSha`

When `lastStableCheckpoint.gitSha` is null:

- Run `drift checkpoint list` and `git log --oneline -20`. Correlate by timestamp — `checkpoint.createdAt` vs. commit author time. Show the user the 3 most likely revert targets with short SHAs, commit messages, and timestamps.
- If correlation is ambiguous, just print the checkpoint summary and tell the user "this checkpoint predates the Git Provenance ledger — pick a SHA manually from `git log` or pass `/aidrift:rollback <sha>` directly."
- Skip predicates 5 + 6 (server-derived) but still run 1–4 locally.
