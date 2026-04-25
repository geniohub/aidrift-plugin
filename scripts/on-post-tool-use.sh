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

# Redact secret patterns from the tool summary before it's persisted.
# Findings file is shared with on-user-prompt and read by on-stop.
if [[ "${AIDRIFT_SECRET_SCAN:-on}" != "off" ]]; then
  summary="$(printf '%s' "$summary" | "${SCRIPT_DIR}/_secret_scan.sh" "${state_dir}/secret_findings.jsonl")"
fi

printf '%s\n' "$summary" >> "${state_dir}/pending_tools"
aidrift_log "tool claude=$claude_sid $summary"

# Best-effort GitEvent recording for `git commit` / `git push` run via Bash.
# Makes Claude Code-driven commits visible to the server even when no VSCode
# watcher is active. Silent on any failure — never breaks the hook.
if [[ "$tool" == "Bash" ]]; then
  bash_cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
  drift_id=""
  [[ -s "${state_dir}/drift_id" ]] && drift_id="$(cat "${state_dir}/drift_id")"

  # Identify the event type from the command. Skip obvious no-ops.
  git_event_type=""
  # Trim leading whitespace; handle `cd X && git commit ...` by picking the
  # last git subcommand. Crude but catches the common shapes.
  last_git_cmd="$(printf '%s' "$bash_cmd" | awk '{ for (i=1;i<=NF;i++) if ($i=="git") { s=""; for (j=i; j<=NF; j++) s=s $j " "; print s } }' | tail -1)"
  if [[ "$last_git_cmd" == *"git commit"* && "$last_git_cmd" != *"--dry-run"* && "$last_git_cmd" != *" -n "* ]]; then
    git_event_type="commit"
  elif [[ "$last_git_cmd" == *"git push"* && "$last_git_cmd" != *"--dry-run"* ]]; then
    git_event_type="push"
  fi

  if [[ -n "$git_event_type" && -n "$drift_id" && -n "$cwd" ]]; then
    sha="$(git -C "$cwd" rev-parse HEAD 2>/dev/null || true)"
    branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    # Extract remote for push: `git push <remote>` — first non-flag token after push.
    remote=""
    if [[ "$git_event_type" == "push" ]]; then
      remote="$(printf '%s' "$last_git_cmd" | awk '{
        for (i=1; i<=NF; i++) if ($i=="push") {
          for (j=i+1; j<=NF; j++) {
            if ($j ~ /^-/) continue
            print $j
            exit
          }
        }
      }')"
    fi

    args=(git-event record --session "$drift_id" --type "$git_event_type" --ai)
    [[ -n "$sha" ]] && args+=(--sha "$sha")
    [[ -n "$branch" ]] && args+=(--branch "$branch")
    [[ -n "$remote" ]] && args+=(--remote "$remote")
    # The subject auto-reads inside the CLI when sha is known for commit type.

    if drift "${args[@]}" >/dev/null 2>&1; then
      aidrift_log "git-event $git_event_type sha=${sha:0:7} drift=$drift_id"
    else
      aidrift_log "git-event $git_event_type FAILED drift=$drift_id"
    fi
  fi
fi

exit 0
