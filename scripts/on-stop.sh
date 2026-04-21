#!/usr/bin/env bash
# Stop hook: flush the pending turn (prompt + tool summary) into AiDrift
# via `drift turn add`, then clear the pending state for this Claude session.
#
# stdin JSON: { session_id, cwd, ... }

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

aidrift_guard

payload="$(cat)"
claude_sid="$(printf '%s' "$payload" | jq -r '.session_id // empty')"
[[ -n "$claude_sid" ]] || exit 0

state_dir="$(aidrift_state_dir "$claude_sid")"
drift_id_file="${state_dir}/drift_id"
prompt_file="${state_dir}/pending_prompt"
tools_file="${state_dir}/pending_tools"

# Nothing to flush if the user-prompt hook never captured this turn.
[[ -s "$drift_id_file" && -s "$prompt_file" ]] || exit 0

drift_id="$(cat "$drift_id_file")"
prompt="$(cat "$prompt_file")"

if [[ -s "$tools_file" ]]; then
  tool_count="$(wc -l < "$tools_file" | tr -d ' ')"
  tool_list="$(cat "$tools_file")"
  response="$(printf 'tools used (%s):\n%s' "$tool_count" "$tool_list")"
else
  response="(no mutating tools used)"
fi

response="$(aidrift_truncate "$response" 4000)"

if drift turn add \
    --session "$drift_id" \
    --prompt "$prompt" \
    --response "$response" >/dev/null 2>&1; then
  aidrift_log "turn add ok claude=$claude_sid drift=$drift_id"
else
  aidrift_log "turn add failed claude=$claude_sid drift=$drift_id"
fi

# Clear per-turn state so the next UserPromptSubmit starts fresh.
rm -f "$prompt_file" "$tools_file"
exit 0
