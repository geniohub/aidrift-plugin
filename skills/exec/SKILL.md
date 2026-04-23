---
name: exec
description: Run a build/test/lint/runtime command and auto-record pass/fail against the current turn — gold-standard drift signal
---

Run `drift turn exec-run` in the Bash tool. The CLI both executes the command and records its pass/fail status against the current turn, feeding the scorer.

Required: the user must provide a command to run (e.g. `npm test`, `pytest`, `cargo build`). If they didn't, ask for one and stop — don't guess.

Argument handling:
- Pass the command after `--` so flags inside it aren't consumed by the CLI:
  `drift turn exec-run --stage <stage> -- <cmd...>`
- Infer `--stage` from the command when obvious:
  - `test`: pytest / jest / vitest / go test / cargo test / npm test / npm run test*
  - `build`: tsc / cargo build / go build / npm run build / make
  - `lint`: eslint / ruff / flake8 / clippy / npm run lint
  - `runtime`: anything else the user calls "run" or "start"
  If unclear, ask the user which stage (one word) and stop.
- Pass `--turn <id>` only if the user named one. Otherwise let the CLI auto-pick the latest turn.

After running, summarize:
- Exit status (pass/fail).
- The first few lines of output if it failed — don't dump the whole log.
- Recommend `/aidrift:status` to see how the score moved.

If the CLI reports no active session, tell the user to start one by prompting Claude normally (the UserPromptSubmit hook creates sessions automatically), or run `drift session start`. Do not create a session for them here.
