#!/usr/bin/env bash
# Shared helpers for AiDrift plugin hooks.
# Hooks must never break the user's Claude Code session — all failures log and exit 0.

set -u

AIDRIFT_DATA="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/aidrift}"
AIDRIFT_LOG="${AIDRIFT_DATA}/plugin.log"

aidrift_log() {
  mkdir -p "$AIDRIFT_DATA" 2>/dev/null || return 0
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$AIDRIFT_LOG" 2>/dev/null || true
}

# Exit 0 silently if required tools are missing.
aidrift_guard() {
  command -v drift >/dev/null 2>&1 || { aidrift_log "skip: drift not on PATH"; exit 0; }
  command -v jq    >/dev/null 2>&1 || { aidrift_log "skip: jq not on PATH"; exit 0; }
}

# State dir for pending turn data, scoped per Claude session id.
aidrift_state_dir() {
  local claude_sid="$1"
  local dir="${AIDRIFT_DATA}/sessions/${claude_sid}"
  mkdir -p "$dir" 2>/dev/null
  printf '%s' "$dir"
}

# Get or create the drift session for a workspace. Uses `session ensure --json`
# which is idempotent and reuses the workspace's current open session.
# Args: cwd, task_text
# Prints drift session uuid, or empty string on failure.
aidrift_ensure_drift_session() {
  local cwd="$1"
  local task="${2:-}"
  local args=(session ensure --provider claude-code --workspace "$cwd" --json)
  [[ -n "$task" ]] && args+=(--task "$task")

  local json
  json="$(drift "${args[@]}" 2>/dev/null || true)"
  if [[ -z "$json" ]]; then
    aidrift_log "session ensure failed (no output) cwd=$cwd"
    return 0
  fi

  local id
  id="$(printf '%s' "$json" | jq -r '.id // empty' 2>/dev/null)"
  if [[ -z "$id" ]]; then
    aidrift_log "session ensure: could not parse id from: $json"
    return 0
  fi
  printf '%s' "$id"
}

# Truncate a string to N chars, appending ellipsis if trimmed.
aidrift_truncate() {
  local s="$1"
  local n="${2:-2000}"
  if [[ ${#s} -le $n ]]; then
    printf '%s' "$s"
  else
    printf '%s…' "${s:0:$n}"
  fi
}
