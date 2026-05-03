#!/bin/sh
# userpromptsubmit.sh — UserPromptSubmit hook for quoin workflow isolation
# Deployed to ~/.claude/hooks/ by bash install.sh
#
# Contract: reads transcript_path, prompt, session_id, cwd from stdin JSON.
# Checks context utilization; emits advisory at STOP_BPS or block at BLOCK_BPS.
# Fail-OPEN: any error → exit 0, no output.
#
# Shebang assertion: head -1 ... | grep -qE '^#!/bin/sh( |$)'
# No-args form RECOMMENDED for fail-OPEN hooks (set -e would break fail-OPEN).

# Source shared helper library
. "$(dirname "$0")/_lib.sh" && read_constants

# STEP -1: Capture stdin before any parsing (stdin can only be read once)
STDIN=$(cat)

# STEP 0: Recovery-command exemption
# Extract prompt field (POSIX-portable; avoid echo's non-portable behavior)
prompt=$(printf '%s' "$STDIN" | jq -r '.prompt // empty' 2>/dev/null) || exit 0

# Strip ALL leading whitespace (including newlines, carriage returns, tabs)
# then extract first whitespace-delimited token (the command token).
# NOTE: sed '^' matches line-by-line; a leading newline creates an empty first
# line that `^[[:space:]]+` cannot strip. tr converts newlines/CRs to spaces
# first so the whole prompt is a single-line string before sed+awk processing.
cmd=$(printf '%s' "$prompt" | tr '\n\r' '  ' | sed -E 's/^[[:space:]]+//' | awk '{print $1}')

# Extract second token for /checkpoint --purge discrimination
arg2=$(printf '%s' "$prompt" | tr '\n\r' '  ' | sed -E 's/^[[:space:]]+//' | awk '{print $2}')

# Exact-token match — exempt-list per quoin/CLAUDE.md ### Hooks deployed by quoin
case "$cmd" in
  /compact|/clear|/help)
    exit 0
    ;;
  /checkpoint)
    case "$arg2" in
      --purge)
        # NOT exempt — destructive subcommand falls through to threshold logic
        # (Q-01 RESOLVED option (b): /checkpoint --purge blocked at >=95% utilization)
        ;;
      *)
        # All other /checkpoint subcommands exempt (no-arg, --restore, future args)
        exit 0
        ;;
    esac
    ;;
esac

# STEP 1: Read transcript path
transcript_path=$(printf '%s' "$STDIN" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0
[ -z "$transcript_path" ] && exit 0

# STEP 2: Compute utilization (returns basis-point integer 0..10000)
util=$(compute_utilization "$transcript_path") || exit 0
[ -z "$util" ] && exit 0

# STEP 3: Branch on utilization
if [ "$util" -lt "$STOP_BPS" ]; then
  # Branch (1): below advisory threshold — transparent passthrough
  exit 0
elif [ "$util" -ge "$STOP_BPS" ] && [ "$util" -lt "$BLOCK_BPS" ]; then
  # Branch (2): advisory range (STOP_BPS..BLOCK_BPS-1) — non-blocking advisory
  pct_int=$((util / 100))
  pct_dec=$(printf '%02d' $((util % 100)))
  printf '{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "context at %d.%s%% — consider running /checkpoint and starting a fresh session"}}\n' \
    "$pct_int" "$pct_dec"
  exit 0
else
  # Branch (3): block range (>= BLOCK_BPS)
  # Error-ordering invariant: block JSON emitted ONLY AFTER pending-prompt file is written.
  # If any step fails, exit 0 (fail-OPEN — do NOT lose the user's prompt).

  # STEP A: Re-parse session_id (may already have prompt from STEP 0)
  session_id=$(printf '%s' "$STDIN" | jq -r '.session_id // empty' 2>/dev/null) || exit 0

  # STEP B-validate: session_id must be non-empty (discriminant collapses without it)
  [ -z "$session_id" ] && exit 0

  # STEP B: Compute pending-prompt path
  cwd=$(printf '%s' "$STDIN" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -z "$cwd" ] && cwd="$PWD"
  pending_prompt_file="${cwd}/.workflow_artifacts/memory/pending-prompt-${session_id}.txt"

  # Ensure directory exists
  mkdir -p "${cwd}/.workflow_artifacts/memory" 2>/dev/null || exit 0

  # STEP C: Write pending-prompt file
  printf '%s' "$prompt" > "$pending_prompt_file" 2>/dev/null || exit 0

  # STEP D: Emit block JSON (only reaches here if STEP C succeeded)
  pct_int=$((util / 100))
  pct_dec=$(printf '%02d' $((util % 100)))
  printf '{"decision": "block", "reason": "context at %d.%s%% — your prompt was saved to pending-prompt-%s.txt; run /checkpoint then /checkpoint --restore in a fresh session"}\n' \
    "$pct_int" "$pct_dec" "$session_id"
  exit 0
fi
