---
name: reject
description: Mark the current (or specified) AiDrift turn as rejected — records a negative drift signal the scorer learns from
---

Run `drift turn reject` in the Bash tool.

Argument handling:
- If the user named a turn ID, pass `--turn <id>`. Otherwise omit it — the CLI defaults to the latest turn.
- If the user gave a reason ("wrong file", "broke tests", "off-scope"), pass it with `--note "<text>"`. Truncate to 200 chars. The note is especially valuable for reject — it's the training signal.

After running, report in one line which turn was rejected.

Then: ask if the user wants to `/aidrift:rollback` to the last stable checkpoint, or `/aidrift:recenter` to redirect the session. Don't do either automatically.

If the CLI prints an auth error, tell the user to run `drift auth login` and stop.
If `drift: command not found`, point them at https://drift.geniohub.com for install instructions.
