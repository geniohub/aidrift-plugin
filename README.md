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

| Command | What it does |
|---|---|
| `/aidrift:status` | Shows the current session's drift score, trend, active alert, and last stable checkpoint. |

### Hooks (run automatically, no user action)

| Event | Behavior |
|---|---|
| `UserPromptSubmit` | Ensures an AiDrift session exists for the current workspace, captures your prompt as the pending turn's input. |
| `PostToolUse` (Write / Edit / MultiEdit / Bash / NotebookEdit) | Appends a short tool-activity line to the pending turn. |
| `Stop` | Flushes the captured turn (`drift turn add`) once Claude finishes responding. |

All hooks are **non-blocking** — if `drift` isn't on PATH, isn't authed, or errors out, the hook silently skips and your Claude Code session continues uninterrupted. Debug log at `${CLAUDE_PLUGIN_DATA}/plugin.log`.

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

Plugin version lives in three places that must all move together on every release: `.claude-plugin/plugin.json`, `package.json`, and the marketplace entry in [`aidrift-marketplace`](https://github.com/geniohub/aidrift-marketplace). The `dist/` folder is gitignored in the AiDrift monorepo but is committed to the marketplace repo — it's the distributable artifact users actually install.

## Links

- Website: https://drift.geniohub.com
- Source: https://github.com/nephantes/AiDrift (under `packages/claude-code-plugin/`)
- Marketplace: https://github.com/geniohub/aidrift-marketplace
- VSCode extension (complementary): [GenioHub.aidrift](https://marketplace.visualstudio.com/items?itemName=GenioHub.aidrift)
