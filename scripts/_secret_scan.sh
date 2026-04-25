#!/usr/bin/env bash
# Client-side secret scanner.
#
# Reads text from stdin, prints redacted text to stdout, and (optionally)
# appends one JSON line per finding to the file path passed as $1.
#
# Patterns are deliberately high-confidence formats only — false positives
# corrupt user prompts in transit, so we err on the side of missing exotic
# token shapes rather than redacting legitimate text.
#
# Exits 0 always; never breaks the hook that called it.

set -u

findings_file="${1:-/dev/null}"

# Read all of stdin into a variable. Hook payloads are bounded (prompt
# truncated to 200 chars in on-user-prompt; tool summaries to 160; turn
# response to 4000), so this stays well under any practical heap risk.
input="$(cat || true)"
[[ -z "$input" ]] && exit 0

# pattern_name|extended-regex
# Order matters when patterns overlap: anthropic-key must run before
# openai-key (both start with `sk-`); the redacted marker no longer
# matches the broader pattern.
patterns=(
  "aws-access-key|AKIA[0-9A-Z]{16}"
  "aws-session-key|ASIA[0-9A-Z]{16}"
  "github-pat|gh[opsur]_[A-Za-z0-9]{36,}"
  "anthropic-key|sk-ant-[A-Za-z0-9_-]{20,}"
  "openai-key|sk-[A-Za-z0-9]{32,}"
  "slack-token|xox[bopsar]-[A-Za-z0-9-]{10,}"
  "stripe-secret|sk_live_[A-Za-z0-9]{24,}"
  "stripe-publishable|pk_live_[A-Za-z0-9]{24,}"
  "google-api-key|AIza[0-9A-Za-z_-]{35}"
  "private-key-header|-----BEGIN [A-Z ]*PRIVATE KEY-----"
  "jwt|eyJ[A-Za-z0-9_-]{8,}\\.eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}"
)

redacted="$input"
for entry in "${patterns[@]}"; do
  name="${entry%%|*}"
  regex="${entry#*|}"
  # `grep -oE` finds every match; `sort -u` dedups so we only emit one
  # finding per distinct value within this scan call.
  matches="$(printf '%s' "$redacted" | grep -oE "$regex" 2>/dev/null | sort -u || true)"
  [[ -z "$matches" ]] && continue
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    # Preview is the redacted form only — never the value. Pattern label
    # + first 4 + last 4 chars to help the user identify which key
    # leaked without exposing it. Skip the tail for very short matches.
    if [[ ${#match} -gt 12 ]]; then
      preview="${match:0:4}…${match: -4}"
    else
      preview="<${#match} chars>"
    fi
    # Bash literal substitution. Match strings are alphanumerics + `-` /
    # `_` / `.` / `+` / `=` / spaces (PEM header) — none are bash glob
    # metacharacters, so `${var//literal/repl}` is safe here.
    redacted="${redacted//$match/[REDACTED:$name]}"
    if command -v jq >/dev/null 2>&1; then
      jq -cn --arg p "$name" --arg pr "$preview" \
        '{pattern: $p, preview: $pr}' >> "$findings_file" 2>/dev/null || true
    else
      printf '{"pattern":"%s","preview":"%s"}\n' "$name" "$preview" \
        >> "$findings_file" 2>/dev/null || true
    fi
  done <<< "$matches"
done

printf '%s' "$redacted"
exit 0
