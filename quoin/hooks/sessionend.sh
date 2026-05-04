#!/bin/sh
# sessionend.sh — SessionEnd hook for quoin workflow isolation
# Deployed to ~/.claude/hooks/ by bash install.sh
# Registered for: SessionEnd (confirmed by T-00 spike — event name verified against Anthropic docs).
#
# S-4 responsibility: EOD nudge at session end.
#   - Reads most-recently-modified sessions/*.md file (mtime within 8 hours)
#   - If end_of_day_due: yes → emits one systemMessage nudge
#   - Does NOT invoke /end_of_day — nudge only
#
# Output channel: systemMessage (SessionEnd does NOT support additionalContext — T-00 confirmed)
# SessionEnd runs asynchronously; exit code is ignored. Fail-OPEN by design.
#
# Fail-OPEN: any error → exit 0, no output.

. "$(dirname "$0")/_lib.sh" && read_constants

# STEP -1: Capture stdin (even if unused — consistency with other hooks)
STDIN=$(cat)

# STEP 1: Parse cwd from stdin
cwd=$(printf '%s' "$STDIN" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -z "$cwd" ] && cwd="$PWD"

SESSIONS_DIR="${cwd}/.workflow_artifacts/memory/sessions"

# STEP 2: If sessions/ does not exist → exit 0 silently
[ -d "$SESSIONS_DIR" ] || exit 0

# STEP 3: Find most recently modified session file within the last 8 hours
# 8 hours = 28800 seconds; use -mtime -1 (24h window) + mtime sort for portability
# Then apply a POSIX-compatible age check using file mtime vs current time
NOW=$(date +%s)
EIGHT_HOURS=28800

RECENT_FILE=""
RECENT_MTIME=0

# Use a temp file to collect find results (POSIX-safe: avoids < <(...) bash-ism)
_SE_TMPFILE=$(mktemp 2>/dev/null) || _SE_TMPFILE="${TMPDIR:-/tmp}/quoin-s4-se-tmp-$$"
find "$SESSIONS_DIR" -maxdepth 1 -name '*.md' -mtime -1 2>/dev/null > "$_SE_TMPFILE"

while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Get file mtime in epoch seconds using a POSIX-portable approach
  # Try: python3 (available on macOS + Linux); fallback: stat (BSD form works on darwin)
  fmtime=$(python3 -c "import os,sys; print(int(os.path.getmtime(sys.argv[1])))" "$f" 2>/dev/null) \
    || fmtime=$(stat -f %m "$f" 2>/dev/null) \
    || fmtime=0
  age=$(( NOW - fmtime ))
  if [ "$age" -le "$EIGHT_HOURS" ] && [ "$fmtime" -gt "$RECENT_MTIME" ]; then
    RECENT_MTIME="$fmtime"
    RECENT_FILE="$f"
  fi
done < "$_SE_TMPFILE"
rm -f "$_SE_TMPFILE" 2>/dev/null || true

# STEP 4: If no recent file found → exit 0
[ -z "$RECENT_FILE" ] && exit 0

# STEP 5: Check end_of_day_due field
grep -q 'end_of_day_due: yes' "$RECENT_FILE" 2>/dev/null || exit 0

# STEP 6: Extract task name for the nudge message
task_name=$(basename "$RECENT_FILE" .md | sed 's/^[0-9]*-[0-9]*-[0-9]*-//')

# STEP 7: Emit nudge via systemMessage
# SessionEnd output channel is systemMessage (not additionalContext — confirmed by T-00 spike).
printf '{"systemMessage": "[quoin-S-4] Session ending with unfinished task: %s — run /end_of_day before your next session."}\n' \
  "$task_name"

exit 0
