# AiDrift Claude Code Plugin

Detect drift in your Claude Code sessions without leaving the terminal. Ships three things:

- **Slash commands** — query AiDrift from the prompt.
- **Hooks** — auto-record every user → assistant turn into AiDrift as you work.
- **MCP tools** — let Claude itself look up scores, past sessions, and checkpoints mid-task.

All of it is backed by the [AiDrift](https://drift.geniohub.com) API. You authenticate once with the `drift` CLI and the plugin reuses those credentials.

## Install

```
/plugin marketplace add geniohub/aidrift-marketplace
/plugin install aidrift@aidrift-marketplace
/reload-plugins
```

The `/reload-plugins` step (or starting a new Claude Code session) is what actually activates the plugin — skills and MCP tools don't show up until then.

Prerequisites:
- `drift` CLI on your PATH and signed in (`drift auth login`).
- `jq` installed (for the hook scripts).

## What you get

### Slash commands

Grouped by purpose. All commands are safe to invoke mid-session — they read state or surface recommendations, and only mutate repo/session state when the name implies it (and always ask before destructive git operations).

**Score & session state**

| Command | What it does |
|---|---|
| `/aidrift:status` | Current session's drift score, trend, active alert, last stable checkpoint. |
| `/aidrift:report` | Full session report with a one-line executive summary on top. |
| `/aidrift:sessions` | List recent sessions across workspaces. |
| `/aidrift:checkpoints` | List checkpoints for the current (or specified) session. |

**Turn feedback (trains the scorer)**

| Command | What it does |
|---|---|
| `/aidrift:accept [note]` | Mark the latest turn as accepted — positive signal. |
| `/aidrift:reject [note]` | Mark the latest turn as rejected — negative signal; the note is the training payload. |
| `/aidrift:exec <cmd>` | Run a build/test/lint/runtime command and auto-record pass/fail against the current turn. Gold-standard signal. |

**Stabilize & recover**

| Command | What it does |
|---|---|
| `/aidrift:checkpoint [summary]` | Pin the current state as a stable checkpoint. Auto-generates a summary from recent context if you don't provide one. |
| `/aidrift:recenter` | Drift is amber/red — diagnoses the signal and drafts a re-anchor prompt. Does not modify any state. |
| `/aidrift:rollback [checkpoint-id]` | Show you the best revert targets and the exact git commands — asks before running anything destructive. |

**Git-gated actions**

| Command | What it does |
|---|---|
| `/aidrift:commit` | Drift-aware commit. Refuses on red unless forced; adds `AiDrift-Session`/`Score`/`Trend`/`Checkpoint` trailers. |
| `/aidrift:push-gate` | Pre-push check. Blocks if the session is red or any pushable commit has a red trailer. |

**Scope enforcement**

| Command | What it does |
|---|---|
| `/aidrift:scope set <patterns>` | Declare allowed paths. Enforced by the PreToolUse hook. |
| `/aidrift:scope add <pattern>` | Append to the scope list. |
| `/aidrift:scope deny <pattern>` | Explicit-deny pattern (overrides allows). |
| `/aidrift:scope clear` | Remove the scope lock. |
| `/aidrift:scope show` | Print current scope. |

**Lifecycle**

| Command | What it does |
|---|---|
| `/aidrift:close` | Final checkpoint + report + writes a handoff note to `.aidrift/handoff.md` for the next session. |

### Hooks (run automatically, no user action)

| Event | Behavior |
|---|---|
| `UserPromptSubmit` | Ensures an AiDrift session exists for the current workspace, captures your prompt as the pending turn's input. |
| `PreToolUse` (Write / Edit / MultiEdit / NotebookEdit) | Enforces the scope lock from `<workspace>/.aidrift/scope`. Warn mode by default; set `AIDRIFT_SCOPE_ENFORCE=strict` to block. |
| `PostToolUse` (Write / Edit / MultiEdit / Bash / NotebookEdit) | Appends a short tool-activity line to the pending turn. |
| `Stop` | Flushes the captured turn (`drift turn add`) once Claude finishes responding. |

All hooks are **non-blocking by default** — if `drift` isn't on PATH, isn't authed, or errors out, the hook silently skips and your Claude Code session continues uninterrupted. The PreToolUse scope hook only blocks when `AIDRIFT_SCOPE_ENFORCE=strict` is set. Debug log at `${CLAUDE_PLUGIN_DATA}/plugin.log`.

### Scope file format (`<workspace>/.aidrift/scope`)

```
# Comments start with #
# Blank lines ignored

src/auth/**              # allow anything under src/auth/
packages/*/src/**        # any package's src tree
src/lib/auth.ts          # exact file
!src/auth/secret.ts      # explicit deny — overrides any allow
```

Manage via `/aidrift:scope` — you shouldn't need to hand-edit this file.

### MCP tools (Claude can call these itself)

| Tool | What it does |
|---|---|
| `aidrift_status` | Get score, trend, alert, and last stable checkpoint. Accepts `session_id` or `workspace_path`. |
| `aidrift_list_sessions` | List recent AiDrift sessions with score + trend. Filter by `workspace_path`. |
| `aidrift_search_sessions` | Full-text search across past sessions and turns — great for "how did I handle something like this before?" |
| `aidrift_create_checkpoint` | Pin the current session state as a named stable checkpoint for later reference or revert. |

Authentication for the MCP server reads `~/.drift/profiles.json` — same file the CLI uses. No separate login.

## Configuration

Environment variables (optional):

| Var | Effect |
|---|---|
| `AIDRIFT_API_URL` | Override API host (default `https://drift.geniohub.com/api`). |
| `AIDRIFT_PROFILE` | Use a non-default profile from `~/.drift/profiles.json`. |

## Versioning

Plugin version lives in two places that must move together on every release: `.claude-plugin/plugin.json` and `package.json`. The built `dist/index.js` is committed here — it's the installable MCP server artifact users actually run after `/plugin install`.

## Links

- Website: https://drift.geniohub.com
- Source: https://github.com/geniohub/aidrift-plugin
- Marketplace: https://github.com/geniohub/aidrift-marketplace
- Companion CLI: https://github.com/geniohub/aidrift-cli (`npm i -g @aidrift/cli`)
- VSCode extension (complementary): [GenioHub.aidrift](https://marketplace.visualstudio.com/items?itemName=GenioHub.aidrift) · source: https://github.com/geniohub/aidrift-vscode
