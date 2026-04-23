#!/usr/bin/env bash
# UserPromptSubmit hook: ensure a drift session exists for this workspace
# and capture the user's prompt as the pending turn's input.
#
# stdin JSON: { session_id, cwd, prompt, ... }

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

aidrift_guard

payload="$(cat)"
claude_sid="$(printf '%s' "$payload" | jq -r '.session_id // empty')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty')"

if [[ -z "$claude_sid" || -z "$cwd" ]]; then
  aidrift_log "user-prompt: missing session_id or cwd"
  exit 0
fi

# First prompt of a session becomes the drift task description.
task="$(aidrift_truncate "$prompt" 200)"

drift_id="$(aidrift_ensure_drift_session "$cwd" "$task")"
if [[ -z "$drift_id" ]]; then
  exit 0
fi

state_dir="$(aidrift_state_dir "$claude_sid")"
printf '%s' "$drift_id" > "${state_dir}/drift_id"
printf '%s' "$prompt" > "${state_dir}/pending_prompt"
# Reset tools log for the new turn.
: > "${state_dir}/pending_tools"

# Capture git state at turn-start time for provenance. Stored here, attached
# to `drift turn add` by the Stop hook. Silent if cwd isn't a git repo.
rm -f "${state_dir}/pending_git_start"
if git_sha="$(git -C "$cwd" rev-parse HEAD 2>/dev/null)"; then
  git_branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || printf HEAD)"
  git_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")"
  if [[ -z "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]]; then
    git_clean="true"
  else
    git_clean="false"
  fi
  jq -cn \
    --arg sha "$git_sha" \
    --arg branch "$git_branch" \
    --arg root "$git_root" \
    --argjson clean "$git_clean" \
    '{sha: $sha, branch: $branch, root: $root, clean: $clean}' \
    > "${state_dir}/pending_git_start" 2>/dev/null || true
fi

aidrift_log "user-prompt ok claude=$claude_sid drift=$drift_id prompt_len=${#prompt}"
exit 0
