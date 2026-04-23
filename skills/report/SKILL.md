---
name: report
description: Generate an AiDrift session report — summary of score, trend, turns, checkpoints, and alerts
---

Run `drift report` in the Bash tool. Use `--json` only if the user asks for structured output; otherwise use the plain text form which is already human-readable.

After running, pass the report through mostly verbatim, but lead with a one-line executive summary:
- Overall verdict: stable / caution / drift.
- The single most important signal driving the verdict.
- Whether there's a safe checkpoint to revert to.

If the CLI errors because no session exists, tell the user to start one by prompting Claude normally, or run `drift session start`. Do not create a session for them here.

If the CLI errors on auth, tell them to run `drift auth login` and stop.
