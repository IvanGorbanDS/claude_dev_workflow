#!/bin/sh
# sessionstart.sh — SessionStart hook for quoin workflow isolation
# Deployed to ~/.claude/hooks/ by bash install.sh
# Registered for BOTH matchers: startup and resume.
#
# S-2 responsibility: pending-restore banner emission.
#   - Sweeps stale pending-prompt-*.txt and pending-restore-*.txt files
#   - Surfaces pending-restore banner if a sentinel is found for this session
#     (or mtime-most-recent if no current-session match)
#
# Fail-OPEN: any error → exit 0, no output.
# Shebang assertion: head -1 ... | grep -qE '^#!/bin/sh( |$)'
# No-args form RECOMMENDED for fail-OPEN hooks.

# Source shared helper library
. "$(dirname "$0")/_lib.sh" && read_constants

# STEP -1: Capture stdin before any parsing (stdin can only be read once)
STDIN=$(cat)

# STEP 1: Parse source and session_id
src=$(printf '%s' "$STDIN" | jq -r '.source // empty' 2>/dev/null) || exit 0
session_id=$(printf '%s' "$STDIN" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$STDIN" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -z "$cwd" ] && cwd="$PWD"

MEMORY_DIR="${cwd}/.workflow_artifacts/memory"

# STEP 2: Sweep stale sentinel files
# Delete pending-prompt-*.txt and pending-restore-*.txt older than STALE_DAYS days
# STALE_DAYS sourced from read_constants() (default 7, override via QUOIN_STALE_SENTINEL_DAYS)
find "$MEMORY_DIR" -maxdepth 1 -name 'pending-prompt-*.txt' -mtime +"$STALE_DAYS" -delete 2>/dev/null || true
find "$MEMORY_DIR" -maxdepth 1 -name 'pending-restore-*.txt' -mtime +"$STALE_DAYS" -delete 2>/dev/null || true

# STEP 3: Look for current-session pending-restore sentinel
pending_restore=""
session_id_match="current-session"

if [ -n "$session_id" ] && [ -f "${MEMORY_DIR}/pending-restore-${session_id}.txt" ]; then
  pending_restore="${MEMORY_DIR}/pending-restore-${session_id}.txt"
  session_id_match="current-session"
fi

# STEP 4: Fallback to mtime-most-recent if no current-session match
# (UUID-shaped session_ids have no time-ordering; lex order is meaningless)
if [ -z "$pending_restore" ]; then
  most_recent=$(ls -t "${MEMORY_DIR}"/pending-restore-*.txt 2>/dev/null | head -1)
  if [ -n "$most_recent" ] && [ -f "$most_recent" ]; then
    pending_restore="$most_recent"
    session_id_match="mismatch-warning: surfaced from different session (mtime-most-recent fallback)"
  fi
fi

# STEP 5: If no sentinel found → exit 0 transparently
if [ -z "$pending_restore" ]; then
  exit 0
fi

# STEP 6: Read sentinel content (the checkpoint file path)
sentinel_content=$(cat "$pending_restore" 2>/dev/null) || exit 0
[ -z "$sentinel_content" ] && exit 0

# Emit banner JSON
printf '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "Pending restore detected. A /checkpoint --restore is recommended (checkpoint: %s — session-id match: %s)"}}\n' \
  "$sentinel_content" "$session_id_match"

# === S-1 pollution-score writer (stub — populated by S-1) ===
# (intentionally empty; S-1 implementation extends this block)

# === S-4 missing-EOD banner (stub — populated by S-4) ===
# (intentionally empty; S-4 implementation extends this block)
