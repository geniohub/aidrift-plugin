#!/usr/bin/env bash
# PreToolUse hook: enforce the session scope lock.
#
# Reads <cwd>/.aidrift/scope — a list of gitignore-style patterns, one per line.
# Lines starting with '!' are denies. Lines starting with '#' are comments.
# If the file is absent, no enforcement happens (silent exit 0).
#
# Modes (AIDRIFT_SCOPE_ENFORCE env var, defaults to "warn"):
#   warn    — print a warning to stderr, allow the edit (exit 0).
#   strict  — block the edit (exit 2, stderr becomes tool_result seen by Claude).
#
# stdin JSON: { session_id, cwd, tool_name, tool_input, ... }
# Matchers in hooks.json narrow this to Write|Edit|MultiEdit|NotebookEdit.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "${SCRIPT_DIR}/_lib.sh"

# jq is the only hard requirement — drift CLI not needed for scope enforcement.
command -v jq >/dev/null 2>&1 || exit 0

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"

[[ -n "$tool" && -n "$cwd" ]] || exit 0

scope_file="${cwd}/.aidrift/scope"
[[ -f "$scope_file" ]] || exit 0

# Extract the target path(s) for the tool. Bail silently if we can't find one.
targets=()
case "$tool" in
  Write|Edit)
    f="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"
    [[ -n "$f" ]] && targets+=("$f")
    ;;
  MultiEdit)
    # MultiEdit has a top-level file_path
    f="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"
    [[ -n "$f" ]] && targets+=("$f")
    ;;
  NotebookEdit)
    f="$(printf '%s' "$payload" | jq -r '.tool_input.notebook_path // empty')"
    [[ -n "$f" ]] && targets+=("$f")
    ;;
  *)
    exit 0
    ;;
esac

[[ ${#targets[@]} -gt 0 ]] || exit 0

# Make the path relative to cwd for pattern matching.
make_relative() {
  local abs="$1"
  # Strip cwd prefix + leading slash if present.
  if [[ "$abs" == "$cwd"/* ]]; then
    printf '%s' "${abs#$cwd/}"
  elif [[ "$abs" == /* ]]; then
    # Outside cwd entirely — always considered out of scope.
    printf '%s' "$abs"
  else
    # Already relative.
    printf '%s' "$abs"
  fi
}

# Glob → regex conversion supporting `**`, `*`, `?` and literal `.`.
# Deny patterns (leading `!`) handled by caller.
glob_to_regex() {
  local pat="$1"
  # Escape regex metachars except globs we handle.
  # 1. Escape dots.
  pat="${pat//./\\.}"
  # 2. `**` → placeholder so single `*` replacement doesn't eat it.
  pat="${pat//\*\*/__DOUBLESTAR__}"
  # 3. Single `*` → `[^/]*`.
  pat="${pat//\*/[^/]*}"
  # 4. Restore `**` as `.*`.
  pat="${pat//__DOUBLESTAR__/.*}"
  # 5. `?` → single non-slash char.
  pat="${pat//\?/[^/]}"
  printf '^%s$' "$pat"
}

check_path() {
  local rel="$1"
  local allow_matched=0
  local deny_matched=0
  local line pattern regex is_deny

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blanks and comments.
    [[ -z "$line" || "$line" == \#* ]] && continue
    # Trim trailing whitespace.
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    is_deny=0
    pattern="$line"
    if [[ "$pattern" == !* ]]; then
      is_deny=1
      pattern="${pattern:1}"
    fi

    regex="$(glob_to_regex "$pattern")"
    if [[ "$rel" =~ $regex ]]; then
      if (( is_deny )); then
        deny_matched=1
      else
        allow_matched=1
      fi
    fi
  done < "$scope_file"

  if (( deny_matched )); then return 2; fi  # explicit deny
  if (( allow_matched )); then return 0; fi  # allowed
  return 1  # no allow pattern matched
}

mode="${AIDRIFT_SCOPE_ENFORCE:-warn}"
violations=()

for target in "${targets[@]}"; do
  rel="$(make_relative "$target")"
  check_path "$rel"
  case $? in
    0) ;; # allowed
    1) violations+=("out of scope: $rel") ;;
    2) violations+=("explicit deny: $rel") ;;
  esac
done

[[ ${#violations[@]} -eq 0 ]] && exit 0

msg="AiDrift scope lock (${scope_file#$cwd/}):"
for v in "${violations[@]}"; do
  msg="${msg}"$'\n'"  - ${v}"
done
msg="${msg}"$'\n'"Run /aidrift:scope show, /aidrift:scope add <pattern>, or unset AIDRIFT_SCOPE_ENFORCE=strict."

aidrift_log "scope violation tool=$tool mode=$mode targets=${targets[*]}"

if [[ "$mode" == "strict" ]]; then
  printf '%s\n' "$msg" >&2
  exit 2
fi

# warn mode
printf '%s\n' "$msg" >&2
exit 0
