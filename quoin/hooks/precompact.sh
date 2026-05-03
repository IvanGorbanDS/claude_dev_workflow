#!/bin/sh
# precompact.sh — PreCompact hook for quoin workflow isolation
# Deployed to ~/.claude/hooks/ by bash install.sh
#
# Contract: fires on PreCompact event (auto compaction only — manual /compact
# is passed through). Saves session state as a last-resort fallback, writes
# a pending-restore sentinel, then blocks the compaction.
# Fail-OPEN: any error → exit 0, no output (compaction proceeds unblocked).
#
# Shebang assertion: head -1 ... | grep -qE '^#!/bin/sh( |$)'
# No-args form RECOMMENDED for fail-OPEN hooks (set -e would break fail-OPEN).

# Source shared helper library
. "$(dirname "$0")/_lib.sh" && read_constants

# STEP -1: Capture stdin before any parsing (stdin can only be read once)
STDIN=$(cat)

# STEP 1: Parse trigger field
# If jq is absent, safe_jq_or_passthrough returns non-zero → fail-OPEN
trigger=$(printf '%s' "$STDIN" | jq -r '.trigger // empty' 2>/dev/null) || exit 0

# Manual /compact: pass through immediately — do not block user-initiated compaction
if [ "$trigger" = "manual" ]; then
  exit 0
fi

# Override: user opted in to allow compact even during auto trigger
if [ "${CLAUDE_ALLOW_COMPACT:-0}" = "1" ]; then
  exit 0
fi

# Parse remaining fields
session_id=$(printf '%s' "$STDIN" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$STDIN" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -z "$cwd" ] && cwd="$PWD"
transcript_path=$(printf '%s' "$STDIN" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0

# Override: .allow-compact marker file in cwd
if [ -f "${cwd}/.allow-compact" ]; then
  exit 0
fi

# Require session_id for pending-restore discriminant (CRIT-3 fix)
# Without session_id the sentinel cannot be matched in sessionstart / /checkpoint --restore
if [ -z "$session_id" ]; then
  printf '[quoin-precompact] WARNING: session_id absent from stdin; cannot write session-scoped sentinel; proceeding fail-OPEN\n' >&2
  exit 0
fi

# STEP 2: Save checkpoint state (paths-not-content rule)
CHECKPOINT_DIR="${cwd}/.workflow_artifacts/memory/checkpoints"
mkdir -p "$CHECKPOINT_DIR" 2>/dev/null || {
  printf '[quoin-precompact] WARNING: cannot create checkpoint dir; falling back fail-OPEN\n' >&2
  exit 0
}

checkpoint_date=$(date -u +%Y-%m-%d 2>/dev/null) || checkpoint_date="unknown-date"

# Determine active task name from session-state filenames (best-effort)
session_state_dir="${cwd}/.workflow_artifacts/memory/sessions"
active_task="unknown-task"
if [ -d "$session_state_dir" ]; then
  # Most recently modified session state file (ls -t) — mtime-most-recent
  latest_session=$(ls -t "$session_state_dir"/*.md 2>/dev/null | head -1)
  if [ -n "$latest_session" ]; then
    # Extract task name from filename pattern: YYYY-MM-DD-<task-name>.md
    session_base=$(basename "$latest_session" .md)
    # Strip leading date prefix (YYYY-MM-DD-)
    active_task=$(printf '%s' "$session_base" | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-//')
  fi
fi

# Collect active pidfiles (for escalation info)
pidfile_info="none"
if ls "$session_state_dir"/*.pidfile.lock > /dev/null 2>&1; then
  pidfile_info=$(ls "$session_state_dir"/*.pidfile.lock 2>/dev/null | xargs -I{} basename {} 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$pidfile_info" ]; then
    pidfile_info="none"
  fi
fi

# Determine current git branch (best-effort)
current_branch="unknown"
if command -v git > /dev/null 2>&1; then
  branch_out=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null) && current_branch="$branch_out"
fi

# Find most recent plan and architecture files
current_plan_path="(none found)"
architecture_path="(none found)"
if [ -d "${cwd}/.workflow_artifacts" ]; then
  found_plan=$(find "${cwd}/.workflow_artifacts" -name "current-plan.md" 2>/dev/null | head -1)
  [ -n "$found_plan" ] && current_plan_path="$found_plan"
  found_arch=$(find "${cwd}/.workflow_artifacts" -name "architecture.md" 2>/dev/null | head -1)
  [ -n "$found_arch" ] && architecture_path="$found_arch"
fi

checkpoint_file="${CHECKPOINT_DIR}/${checkpoint_date}-${active_task}-precompact.md"

# Write checkpoint (paths-not-content — never carry file contents)
cat > "$checkpoint_file" 2>/dev/null << CPEOF
## Status
precompact-hook save (auto-compaction intercepted)

## Current stage
unknown — read session-state files for details

## Active task
${active_task}

## Branch
${current_branch}

## Session ID
${session_id}

## Trigger
auto (compaction was blocked; run /checkpoint --restore in a fresh session)

## Active skills (pidfiles)
${pidfile_info}

## In-flight artifacts
- current-plan.md: ${current_plan_path}
- architecture.md: ${architecture_path}
- transcript: ${transcript_path}

## Restore hint
Run /checkpoint --restore in a fresh session to resume.
CPEOF

# Check if write succeeded
if [ ! -f "$checkpoint_file" ]; then
  printf '[quoin-precompact] WARNING: checkpoint write failed; proceeding fail-OPEN\n' >&2
  exit 0
fi

# Warn if no active pidfiles (compaction escalation less reliable)
if [ "$pidfile_info" = "none" ]; then
  printf '[quoin-precompact] WARNING: no active pidfiles found; compaction block may be unreliable (start skills that acquire pidfiles via §0c to improve reliability)\n' >&2
fi

# STEP 3: Write pending-restore sentinel (CRIT-3 fix — session-id discriminant)
MEMORY_DIR="${cwd}/.workflow_artifacts/memory"
pending_restore_file="${MEMORY_DIR}/pending-restore-${session_id}.txt"
mkdir -p "$MEMORY_DIR" 2>/dev/null || true
printf '%s\n' "$checkpoint_file" > "$pending_restore_file" 2>/dev/null || {
  printf '[quoin-precompact] WARNING: cannot write pending-restore sentinel; sessionstart hook cannot surface restore banner\n' >&2
  # Still block — checkpoint was written, just sentinel is missing
}

# STEP 4: Emit block JSON
printf '{"decision": "block", "reason": "auto-compaction intercepted; session state saved to %s; run /checkpoint then /checkpoint --restore in a fresh session"}\n' \
  "$(basename "$checkpoint_file")"
