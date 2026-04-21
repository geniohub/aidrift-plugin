#!/usr/bin/env bash
# PostToolUse hook: record mutating tool invocations into the pending-turn log.
# Matchers in hooks.json narrow this to Write|Edit|MultiEdit|Bash|NotebookEdit.
#
# stdin JSON: { session_id, cwd, tool_name, tool_input, tool_output, ... }

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

aidrift_guard

payload="$(cat)"
claude_sid="$(printf '%s' "$payload" | jq -r '.session_id // empty')"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"

if [[ -z "$claude_sid" || -z "$tool" ]]; then
  exit 0
fi

state_dir="$(aidrift_state_dir "$claude_sid")"

# Only record if a turn is in flight. If no pending_prompt, the user-prompt hook
# didn't fire (e.g. drift wasn't authed at prompt time) — skip silently.
[[ -f "${state_dir}/pending_prompt" ]] || exit 0

# One-line summary per tool. Shape depends on the tool.
summary=""
case "$tool" in
  Write|Edit|MultiEdit)
    file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"
    summary="${tool}: ${file:-<unknown>}"
    ;;
  NotebookEdit)
    file="$(printf '%s' "$payload" | jq -r '.tool_input.notebook_path // empty')"
    summary="NotebookEdit: ${file:-<unknown>}"
    ;;
  Bash)
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
    summary="Bash: $(aidrift_truncate "$cmd" 160)"
    ;;
  *)
    summary="$tool"
    ;;
esac

printf '%s\n' "$summary" >> "${state_dir}/pending_tools"
aidrift_log "tool claude=$claude_sid $summary"
exit 0
