---
name: accept
description: Mark the current (or specified) AiDrift turn as accepted — records a positive drift signal
---

Run `drift turn accept` in the Bash tool.

Argument handling:
- If the user named a turn ID, pass `--turn <id>`. Otherwise omit it — the CLI defaults to the latest turn.
- If the user gave a rationale ("because the tests pass", "because this is what I wanted"), pass it with `--note "<text>"`. Truncate to 200 chars.

After running, report in one line:
- Which turn was marked (`accepted turn <id>`).
- Suggest `/aidrift:status` if the user wants to see the updated score.

If the CLI prints an auth error, tell the user to run `drift auth login` and stop — do not retry.
If `drift: command not found`, point them at https://drift.geniohub.com for install instructions.
