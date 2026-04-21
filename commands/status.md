---
description: Show the AiDrift score, alert state, and last stable checkpoint for the active session
---

Run `drift status` in the Bash tool and report back to the user.

Summarize:
- The current drift score and which alert band it falls into (stable / caution / drift).
- The short-term trend if `drift status` shows one.
- The last stable checkpoint, if any — so the user knows a safe revert point.
- Any active alerts or recommendations printed by the CLI.

If `drift status` errors because the user is not logged in, tell them to run `drift auth login` and stop — do not try to call any other CLI subcommand on their behalf.

If the CLI is not installed (`drift: command not found`), point the user at https://drift.geniohub.com for install instructions.
