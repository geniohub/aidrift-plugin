---
name: sessions
description: List recent AiDrift sessions across workspaces — scores, trends, and status at a glance
---

Run `drift session list` in the Bash tool.

After running, present the list as a compact table-style readout:
- Session ID (short form, first 8 chars).
- Workspace (basename only).
- Task description (truncated to ~50 chars).
- Current score and trend arrow (↑ improving / → stable / ↓ drifting).
- Whether the session is still open.

Sort most-recent first, which is already the CLI default.

End with a one-liner: "use `/aidrift:status` for details on any one, or `drift auth login` if you want to switch profiles."

If auth fails, tell the user to run `drift auth login` and stop.
