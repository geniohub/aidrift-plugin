#!/usr/bin/env bash
# PreToolUse hook (Bash matcher): drift + secret gate before `git commit`.
#
# Wired separately from the Write/Edit scope-lock hook so the matchers stay
# narrow — Bash payloads carry an arbitrary command string and we filter
# down to `git commit` invocations here. Anything else exits 0 immediately
# and adds no measurable latency to the user's tool call.
#
# Mode via AIDRIFT_COMMIT_GATE (default "warn"):
#   warn   — print findings to stderr, allow the commit (exit 0)
#   block  — print findings, exit 2 to abort the commit
#   off    — no-op
#
# Decision (gate fires when ANY trigger is true, per
# docs/GIT_PROVENANCE_PLAN.md §Phase 7):
#   - secretFindings on `git diff --cached` > 0
#   - sessionMap.scopeDistance > 3   (focals wandering off the anchor)
#   - sessionMap.focalShift   > 0.6  (early/late focal sets diverged)
#   - alert.active == true           (server already flagged drift)
#
# stdin JSON: { session_id, cwd, tool_name="Bash", tool_input.command, ... }

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

mode="${AIDRIFT_COMMIT_GATE:-warn}"
[[ "$mode" == "off" ]] && exit 0

# jq is the only hard requirement — drift CLI is best-effort below.
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"

[[ "$tool" == "Bash" && -n "$cwd" && -n "$cmd" ]] || exit 0

# Filter to `git commit` invocations. Split on shell separators (`;`, `&&`,
# `||`, `|`, newlines) and inspect each segment so a chained command like
# `git status && git commit -m …` still trips the gate. Trim leading
# whitespace on each segment before matching.
matched=0
# `printf '%s\n'` ensures the last segment ends with a newline so `read`
# returns 0 on it; without that, a one-segment command (`git commit -m …`
# with no chaining) was silently dropped by the loop.
while IFS= read -r seg || [[ -n "$seg" ]]; do
  seg="${seg#"${seg%%[![:space:]]*}"}"
  [[ -z "$seg" ]] && continue
  # `git commit` exact, or followed by a space (flag/arg). `git commit-tree`
  # and other plumbing must not match — the trailing space requirement
  # handles that.
  if [[ "$seg" == "git commit" || "$seg" == "git commit "* ]]; then
    matched=1; break
  fi
  # `git -C <path> commit [...]`.
  if [[ "$seg" =~ ^git[[:space:]]+-C[[:space:]]+[^[:space:]]+[[:space:]]+commit([[:space:]]|$) ]]; then
    matched=1; break
  fi
done < <(printf '%s\n' "$cmd" | tr ';|&\n' '\n')
[[ "$matched" -eq 1 ]] || exit 0

# Skip `--help` / `-h` — those don't create commits.
case "$cmd" in
  *"git commit --help"*|*"git commit -h"*) exit 0 ;;
esac

git_cmd=(git -C "$cwd")

# Quick exit when nothing is staged: the commit itself will fail and
# there's nothing to scan. `git diff --cached --quiet` exits 0 when no
# staged changes, 1 when there are.
if "${git_cmd[@]}" diff --cached --quiet 2>/dev/null; then
  exit 0
fi

# 1. Secret scan over the staged diff. Limit to added lines (`+` prefix in
#    unified diff) — removed lines can't leak forward. Strip the leading
#    `+` so the regex set in _secret_scan.sh matches the raw token.
findings_tmp="$(mktemp -t aidrift-commit-gate.XXXXXX 2>/dev/null)" || exit 0
trap 'rm -f "$findings_tmp"' EXIT

secret_count=0
secret_summary=""
diff="$("${git_cmd[@]}" diff --cached --no-color --unified=0 2>/dev/null || true)"
if [[ -n "$diff" ]]; then
  added="$(printf '%s\n' "$diff" | awk '/^\+[^+]/ { sub(/^\+/, ""); print }')"
  if [[ -n "$added" ]]; then
    printf '%s' "$added" | "${SCRIPT_DIR}/_secret_scan.sh" "$findings_tmp" staged-diff >/dev/null 2>/dev/null
    if [[ -s "$findings_tmp" ]]; then
      secret_count="$(wc -l < "$findings_tmp" | tr -d ' ')"
      secret_summary="$(awk -F'"' '/"pattern"/ { for(i=1;i<=NF;i++) if($i=="pattern") print $(i+2) }' "$findings_tmp" | sort | uniq -c | awk '{ printf "%s×%s ", $2, $1 }')"
    fi
  fi
fi

# 2. Drift status — best-effort. Older `drift` CLIs print human-readable
#    text and have no `--json` flag; in that case `jq -e .` fails and we
#    leave the drift half of the gate quiet (secret half still authoritative).
scope_distance="null"
focal_shift="null"
trend=""
alert_active="false"
status_json=""
if command -v drift >/dev/null 2>&1; then
  status_json="$(drift status --json 2>/dev/null || true)"
fi
if printf '%s' "$status_json" | jq -e . >/dev/null 2>&1; then
  scope_distance="$(printf '%s' "$status_json" | jq -r '.sessionMap.scopeDistance // "null"')"
  focal_shift="$(printf '%s' "$status_json" | jq -r '.sessionMap.focalShift // "null"')"
  trend="$(printf '%s' "$status_json" | jq -r '.trend // empty')"
  alert_active="$(printf '%s' "$status_json" | jq -r '.alert.active // false')"
fi

# 3. Decide.
reasons=()
if [[ "$secret_count" -gt 0 ]]; then
  plural=""
  [[ "$secret_count" -gt 1 ]] && plural="s"
  reasons+=("secret${plural} in staged diff [${secret_summary% }] — ${secret_count} finding${plural}")
fi
if [[ "$scope_distance" != "null" ]] && awk -v v="$scope_distance" 'BEGIN { exit !(v+0 > 3) }'; then
  reasons+=("scopeDistance=${scope_distance} (>3 — focal points are wandering off the task anchor)")
fi
if [[ "$focal_shift" != "null" ]] && awk -v v="$focal_shift" 'BEGIN { exit !(v+0 > 0.6) }'; then
  reasons+=("focalShift=${focal_shift} (>0.6 — top focal points changed sharply across the session)")
fi
if [[ "$alert_active" == "true" ]]; then
  trend_tail=""
  [[ -n "$trend" ]] && trend_tail=", trend=${trend}"
  reasons+=("session drift alert is active${trend_tail}")
fi

[[ ${#reasons[@]} -eq 0 ]] && exit 0

# Recent-commits hint. Prefer the un-pushed range (commits that haven't
# escaped yet — most actionable), fall back to the last 5 commits when no
# upstream is configured.
recent=""
if upstream="$("${git_cmd[@]}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  recent="$("${git_cmd[@]}" log --format='%h %s' --max-count=5 "${upstream}..HEAD" 2>/dev/null || true)"
fi
if [[ -z "$recent" ]]; then
  recent="$("${git_cmd[@]}" log --format='%h %s' --max-count=5 2>/dev/null || true)"
fi

# Format and emit. One reason per line so the output stays scannable in a
# tool_result block; the override hint goes last.
header="AiDrift commit gate (${mode}): ${#reasons[@]} reason(s)"
msg="$header"
for r in "${reasons[@]}"; do
  msg="${msg}"$'\n'"  · ${r}"
done
if [[ -n "$recent" ]]; then
  msg="${msg}"$'\n'"recent commits on this branch:"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    msg="${msg}"$'\n'"  - ${line}"
  done <<< "$recent"
fi
msg="${msg}"$'\n'"Override: AIDRIFT_COMMIT_GATE=warn (allow once) | =off (disable). Recommended next step: /aidrift:recenter, /aidrift:rollback, or unstage the leak."

aidrift_log "commit-gate fire mode=$mode reasons=${#reasons[@]} secrets=$secret_count scope=$scope_distance focal=$focal_shift alert=$alert_active"

printf '%s\n' "$msg" >&2

if [[ "$mode" == "block" ]]; then
  exit 2
fi
exit 0
