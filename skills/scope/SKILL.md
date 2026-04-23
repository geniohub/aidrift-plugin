---
name: scope
description: Declare which paths Claude is allowed to touch this session — writes .aidrift/scope, enforced by the PreToolUse hook
---

Manage the session's scope lock, stored in `<workspace>/.aidrift/scope`. The PreToolUse hook reads this file and warns (or blocks) when Claude tries to edit files outside it.

### Subcommands

Parse the user's intent into one of these modes. If ambiguous, ask.

**set** — replace the scope with a new pattern list.
- User gave patterns (space or newline separated): `src/auth/** packages/core/src/auth/**`.
- Write them to `<cwd>/.aidrift/scope`, one per line, overwriting any existing file.
- Create the `.aidrift/` directory if needed.
- Confirm: "scope locked to N patterns", list them.

**add** — append patterns to existing scope.
- Read existing file, append user's new patterns, dedupe, write back.

**clear** — remove the scope lock.
- Delete `<cwd>/.aidrift/scope` (not the whole `.aidrift/` dir — other tools use it).
- Confirm: "scope cleared — all paths allowed".

**show** — print the current scope.
- `cat <cwd>/.aidrift/scope` (or say "no scope lock set" if absent).

**deny** — add an explicit-deny pattern.
- Prefix user's pattern with `!` and append.
- Example: user says "never touch node_modules" → append `!node_modules/**`.

### Pattern syntax

Document in the confirmation output, first-time only per session:

- `src/auth/**` — anything under src/auth/
- `packages/*/src/**` — any package's src tree
- `src/lib/auth.ts` — exact file
- `!secrets/**` — deny overrides allow
- `#` starts a comment
- Blank lines ignored

### Default `.gitignore` nudge

If `.aidrift/` is not in `.gitignore`, ask the user whether to add it. The scope file is usually personal to a session, not shared. Do not add it automatically.

### Never do

- Do not enforce scope from inside this skill. Enforcement is the PreToolUse hook's job.
- Do not silently overwrite an existing scope file on `set` without showing the user what was there.
