#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
#  Quoin Installer — User-level setup (run once per machine)
#
#  - Copies all skills to ~/.claude/skills/
#  - Writes workflow rules to ~/.claude/CLAUDE.md
#
#  After this, use /init_workflow inside any project to scaffold
#  the project-level memory structure and permissions.
#
#  Usage:
#    bash install.sh
# ═══════════════════════════════════════════════════════════════

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
success() { echo -e "${GREEN}✓${NC}  $1"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $1"; }
error()   { echo -e "${RED}✗${NC}  $1"; }
header()  { echo -e "\n${BOLD}$1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Argument parsing ──
DEV_MODE=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dev) DEV_MODE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) echo "Usage: bash install.sh [--dev] [--dry-run]"; exit 0 ;;
    *) warn "Unknown arg: $arg (ignored)" ;;
  esac
done

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Quoin Installer              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""
info "Source: $SCRIPT_DIR"
echo ""

# ── Step 1: Check prerequisites ──
header "Step 1: Checking prerequisites..."

MISSING=()

if ! command -v claude &>/dev/null; then
  MISSING+=("claude (Claude Code CLI)")
fi

if ! command -v git &>/dev/null; then
  MISSING+=("git")
fi

if ! command -v gh &>/dev/null; then
  warn "gh (GitHub CLI) not found — /end_of_task push will still work, but PR creation won't."
fi

if ! command -v npx &>/dev/null; then
  warn "npx not found — cost tracking in /end_of_task requires npx (install Node.js from https://nodejs.org)."
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  error "Missing required tools:"
  for tool in "${MISSING[@]}"; do
    echo "       - $tool"
  done
  echo ""
  echo "Install them and re-run this script."
  exit 1
fi

success "Prerequisites OK"

# ── Step 2a: Regenerate subagent preambles ──
header "Step 2a: Regenerating subagent preambles..."
python3 "$SCRIPT_DIR/scripts/build_preambles.py" || { error "build_preambles.py failed"; exit 1; }
success "Regenerated 7 subagent preambles in $SCRIPT_DIR/skills/*/preamble.md"

# ── Step 2: Copy skills to ~/.claude/skills/ ──
header "Step 2: Copying skills to ~/.claude/skills/..."

USER_SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$USER_SKILLS_DIR"

SKILL_COUNT=0
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  if [ -d "$skill_dir" ]; then
    skill_name=$(basename "$skill_dir")
    mkdir -p "$USER_SKILLS_DIR/$skill_name"
    cp "$skill_dir/SKILL.md" "$USER_SKILLS_DIR/$skill_name/SKILL.md"
    if [ -f "$skill_dir/preamble.md" ]; then cp "$skill_dir/preamble.md" "$USER_SKILLS_DIR/$skill_name/preamble.md"; fi
    SKILL_COUNT=$((SKILL_COUNT + 1))
  fi
done

success "Copied $SKILL_COUNT skills to ~/.claude/skills/"

# ── Step 2b: Copy terse-rubric and v3 reference files to ~/.claude/memory/ and v3 scripts to ~/.claude/scripts/ ──
header "Step 2b: Copying memory references and v3 scripts to ~/.claude/..."

USER_MEMORY_DIR="$HOME/.claude/memory"
USER_SCRIPTS_DIR="$HOME/.claude/scripts"

# v2 terse-rubric (pre-existing — keep this block content-identical)
RUBRIC_SRC="$SCRIPT_DIR/memory/terse-rubric.md"
RUBRIC_DST="$USER_MEMORY_DIR/terse-rubric.md"

if [ ! -f "$RUBRIC_SRC" ]; then
  error "Expected rubric at $RUBRIC_SRC but not found — aborting"
  exit 1
fi

mkdir -p "$USER_MEMORY_DIR"
cp "$RUBRIC_SRC" "$RUBRIC_DST"
success "Copied terse-rubric.md to ~/.claude/memory/"

# v3 reference files (NEW — mirror the rubric pattern exactly)
for ref_file in format-kit.md glossary.md format-kit.sections.json summary-prompt.md format-kit-pitfalls.md sleep-signals.yaml; do
  REF_SRC="$SCRIPT_DIR/memory/$ref_file"
  REF_DST="$USER_MEMORY_DIR/$ref_file"
  if [ ! -f "$REF_SRC" ]; then
    error "Expected $ref_file at $REF_SRC but not found — aborting"
    exit 1
  fi
  cp "$REF_SRC" "$REF_DST"
  success "Copied $ref_file to ~/.claude/memory/"
done

# QUICKSTART.md — deployed to ~/.claude/ root (NOT under memory/ — top-level command reference)
QUICKSTART_SRC="$SCRIPT_DIR/QUICKSTART.md"
QUICKSTART_DST="$HOME/.claude/QUICKSTART.md"

if [ ! -f "$QUICKSTART_SRC" ]; then
  error "Expected QUICKSTART.md at $QUICKSTART_SRC but not found — aborting"
  exit 1
fi

mkdir -p "$HOME/.claude"
cp "$QUICKSTART_SRC" "$QUICKSTART_DST"
success "QUICKSTART deployed to ~/.claude/QUICKSTART.md"

# v3 scripts (NEW — separate destination directory ~/.claude/scripts/)
mkdir -p "$USER_SCRIPTS_DIR"
for script_file in validate_artifact.py path_resolve.py cost_from_jsonl.py classify_critic_issues.py build_preambles.py session_age_guard.py pidfile_helpers.sh sleep_score.py analyze_cost_ledger.py; do
  SCRIPT_SRC="$SCRIPT_DIR/scripts/$script_file"
  SCRIPT_DST="$USER_SCRIPTS_DIR/$script_file"
  if [ ! -f "$SCRIPT_SRC" ]; then
    error "Expected $script_file at $SCRIPT_SRC but not found — aborting"
    exit 1
  fi
  cp "$SCRIPT_SRC" "$SCRIPT_DST"
  chmod +x "$SCRIPT_DST"
  success "Copied $script_file to ~/.claude/scripts/"
done

# Stage 5 cleanup: remove already-deployed obsolete scripts from prior installs.
# cp deploys but does not delete; explicit rm closes the gap.
for obsolete in summarize_for_human.py with_env.sh audit_corpus_coverage.py; do
  if [ -f "$USER_SCRIPTS_DIR/$obsolete" ]; then
    rm -f "$USER_SCRIPTS_DIR/$obsolete"
    success "Removed obsolete $obsolete from $USER_SCRIPTS_DIR/ (Stage 5 cleanup)"
  fi
done
# Optional: remove the corresponding deployed test harness if it exists.
for obsolete_test in test_summarize_for_human.py test_with_env_sh.py; do
  if [ -f "$USER_SCRIPTS_DIR/tests/$obsolete_test" ]; then
    rm -f "$USER_SCRIPTS_DIR/tests/$obsolete_test"
    success "Removed obsolete $obsolete_test (Stage 5 cleanup)"
  fi
done

if ! python3 -c 'import yaml' 2>/dev/null; then
  warn "Python package 'pyyaml' is not installed — validate_artifact.py V-01 frontmatter check will fail at runtime."
  warn "  Install with: pip install pyyaml"
fi

# ── Step 2c: Install dev Python dependencies (--dev only) ──
if [ "$DEV_MODE" -eq 1 ]; then
  header "Step 2c: Installing dev Python dependencies..."
  if command -v pip3 >/dev/null; then
    pip3 install --user --upgrade pyyaml pytest \
      || warn "pip install failed; install pyyaml + pytest manually for dev tests"
    success "Dev deps installed (pyyaml, pytest)"
  else
    warn "pip3 not found — install pyyaml + pytest manually for dev tests"
  fi
fi

# ── Step 2d: Deploy hooks to ~/.claude/hooks/ and merge settings.json ──
header "Step 2d: Deploying hooks..."

install_hooks() {
  local SETTINGS_FILE="$HOME/.claude/settings.json"
  local HOOKS_SRC_DIR="$SCRIPT_DIR/hooks"
  local HOOKS_DST_DIR="$HOME/.claude/hooks"

  # Dry-run mode: use a temp copy for all operations; never touch live files
  local DRY_RUN_TMP=""
  if [ "$DRY_RUN" -eq 1 ]; then
    DRY_RUN_TMP=$(mktemp -d)
    local WORK_SETTINGS="$DRY_RUN_TMP/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
      cp "$SETTINGS_FILE" "$WORK_SETTINGS"
    else
      printf '{}' > "$WORK_SETTINGS"
    fi
  fi

  # Step 0: jq check
  if ! command -v jq > /dev/null 2>&1; then
    local TODO_FILE
    if [ "$DRY_RUN" -eq 1 ]; then
      TODO_FILE="$DRY_RUN_TMP/HOOK_MERGE_TODO.md"
    else
      TODO_FILE="$HOME/.claude/HOOK_MERGE_TODO.md"
    fi
    cat > "$TODO_FILE" << 'TODOEOF'
# Hook Merge TODO — quoin install.sh

jq was not found on PATH at install time. The following five stanzas must be
merged manually into ~/.claude/settings.json under the "hooks" key:

## UserPromptSubmit (matcher: *)
```json
{
  "matcher": "*",
  "hooks": [{"type": "command", "command": "~/.claude/hooks/userpromptsubmit.sh", "timeout": 5}]
}
```

## PreCompact (matcher: auto)
```json
{
  "matcher": "auto",
  "hooks": [{"type": "command", "command": "~/.claude/hooks/precompact.sh", "timeout": 10}]
}
```

## SessionStart (matcher: startup)
```json
{
  "matcher": "startup",
  "hooks": [{"type": "command", "command": "~/.claude/hooks/sessionstart.sh", "timeout": 5}]
}
```

## SessionStart (matcher: resume)
```json
{
  "matcher": "resume",
  "hooks": [{"type": "command", "command": "~/.claude/hooks/sessionstart.sh", "timeout": 5}]
}
```

## SessionEnd (matcher: *)
```json
{
  "matcher": "*",
  "hooks": [{"type": "command", "command": "~/.claude/hooks/sessionend.sh", "timeout": 5}]
}
```

After merging, verify with: jq '.hooks' ~/.claude/settings.json
TODOEOF
    warn "jq not found on PATH; settings.json merge skipped (see $(basename "$TODO_FILE")) AND runtime hooks (userpromptsubmit / precompact / sessionstart) will fail-OPEN silently — install jq for full protection."
    if [ "$DRY_RUN" -eq 1 ]; then
      info "Dry-run: HOOK_MERGE_TODO.md would be written to: $TODO_FILE"
    fi
    return 0
  fi

  # Step 1: Project-local settings.json detection
  local PROJ_LOCAL_SETTINGS="$(pwd)/.claude/settings.json"
  if [ -f "$PROJ_LOCAL_SETTINGS" ]; then
    warn "[quoin install] WARNING: project-local .claude/settings.json detected — quoin hooks deploy to user-level ~/.claude/settings.json and may be overridden if project-local settings register hooks at the same event level. See quoin/CLAUDE.md ### Hooks deployed by quoin for details."
  fi

  # Step 2 (skip in dry-run): Backup live settings.json
  if [ "$DRY_RUN" -ne 1 ] && [ -f "$SETTINGS_FILE" ]; then
    local BAK_FILE="${SETTINGS_FILE}.bak-$(date -u +%Y%m%dT%H%M%SZ)"
    cp "$SETTINGS_FILE" "$BAK_FILE"
    info "Backed up settings.json to $(basename "$BAK_FILE")"
  fi

  # Step 3 (skip in dry-run): Copy hook scripts
  if [ "$DRY_RUN" -ne 1 ]; then
    mkdir -p "$HOOKS_DST_DIR"
    for hook_file in "$HOOKS_SRC_DIR"/*.sh "$HOOKS_SRC_DIR/_lib.sh"; do
      [ -f "$hook_file" ] || continue
      local hook_name
      hook_name=$(basename "$hook_file")
      cp "$hook_file" "$HOOKS_DST_DIR/$hook_name"
      chmod +x "$HOOKS_DST_DIR/$hook_name"
      success "Deployed hook: $hook_name"
    done
  fi

  # Step 4: Determine settings.json to operate on
  local WORK_FILE
  if [ "$DRY_RUN" -eq 1 ]; then
    WORK_FILE="$DRY_RUN_TMP/settings.json"
  else
    WORK_FILE="$SETTINGS_FILE"
    # Create minimal settings.json if it doesn't exist
    if [ ! -f "$WORK_FILE" ]; then
      printf '{}' > "$WORK_FILE"
    fi
  fi
  local HOOKS_DST_REAL="$HOME/.claude/hooks"

  # Step 5: Merge hook stanzas via pinned jq queries
  # Uniqueness key: (matcher, script-filename) — removes stale quoin entries at old paths,
  # preserves user-defined hooks whose command path ends with a different script filename.
  # Strategy: for each quoin script, filter out entries for the same matcher whose hook
  # command endswith the quoin script filename (handles path changes across installs),
  # then append the canonical entry. User hooks with different filenames are preserved.
  local NEW_FILE="${WORK_FILE}.new"

  # UserPromptSubmit / *
  jq --arg cmd "$HOOKS_DST_REAL/userpromptsubmit.sh" --arg matcher "*" --arg scriptname "userpromptsubmit.sh" \
    '.hooks.UserPromptSubmit = ([(.hooks.UserPromptSubmit // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}])' \
    "$WORK_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$WORK_FILE"

  # PreCompact / auto
  jq --arg cmd "$HOOKS_DST_REAL/precompact.sh" --arg matcher "auto" --arg scriptname "precompact.sh" \
    '.hooks.PreCompact = ([(.hooks.PreCompact // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 10}]}])' \
    "$WORK_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$WORK_FILE"

  # SessionStart / startup
  jq --arg cmd "$HOOKS_DST_REAL/sessionstart.sh" --arg matcher "startup" --arg scriptname "sessionstart.sh" \
    '.hooks.SessionStart = ([(.hooks.SessionStart // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}])' \
    "$WORK_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$WORK_FILE"

  # SessionStart / resume
  jq --arg cmd "$HOOKS_DST_REAL/sessionstart.sh" --arg matcher "resume" --arg scriptname "sessionstart.sh" \
    '.hooks.SessionStart = ([(.hooks.SessionStart // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}])' \
    "$WORK_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$WORK_FILE"

  # SessionEnd / * (event name confirmed by T-00 spike — "SessionEnd" is correct per Anthropic docs)
  jq --arg cmd "$HOOKS_DST_REAL/sessionend.sh" --arg matcher "*" --arg scriptname "sessionend.sh" \
    '.hooks.SessionEnd = ([(.hooks.SessionEnd // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}])' \
    "$WORK_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$WORK_FILE"

  # Step 6: Validate result
  if ! jq empty < "$WORK_FILE" 2>/dev/null; then
    if [ "$DRY_RUN" -ne 1 ] && [ -f "${SETTINGS_FILE}.bak-"* ] 2>/dev/null; then
      local BAK
      BAK=$(ls -t "${SETTINGS_FILE}.bak-"* 2>/dev/null | head -1)
      if [ -n "$BAK" ]; then
        cp "$BAK" "$SETTINGS_FILE"
        error "settings.json parse failed after merge — restored from backup. Check $BAK."
      fi
    fi
    error "settings.json merge produced invalid JSON."
    return 1
  fi

  # Step 7: Dry-run output vs live write
  if [ "$DRY_RUN" -eq 1 ]; then
    info "Dry-run: merged settings.json (not written to disk):"
    cat "$WORK_FILE"
    rm -rf "$DRY_RUN_TMP"
  else
    success "Hook stanzas merged into ~/.claude/settings.json (5 tuples)"
  fi
}

install_hooks
success "Step 2d complete"

# ── Step 3: Write workflow rules to ~/.claude/CLAUDE.md ──
header "Step 3: Writing workflow rules to ~/.claude/CLAUDE.md..."

USER_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
MARKER_START="# === DEV WORKFLOW START ==="
MARKER_END="# === DEV WORKFLOW END ==="

if [ -f "$USER_CLAUDE_MD" ] && grep -q "$MARKER_START" "$USER_CLAUDE_MD"; then
  python3 - "$USER_CLAUDE_MD" "$SCRIPT_DIR/CLAUDE.md" << 'PYEOF'
import sys, re
user_path, source_path = sys.argv[1], sys.argv[2]
with open(user_path) as f: content = f.read()
with open(source_path) as f: new_rules = f.read()
marker_start = "# === DEV WORKFLOW START ==="
marker_end = "# === DEV WORKFLOW END ==="
new_section = f"{marker_start}\n{new_rules}\n{marker_end}"
updated = re.sub(
    rf"{re.escape(marker_start)}.*?{re.escape(marker_end)}",
    new_section, content, flags=re.DOTALL)
with open(user_path, 'w') as f: f.write(updated)
PYEOF
  success "Updated quoin section in ~/.claude/CLAUDE.md"
else
  {
    echo ""
    echo "$MARKER_START"
    cat "$SCRIPT_DIR/CLAUDE.md"
    echo ""
    echo "$MARKER_END"
  } >> "$USER_CLAUDE_MD"
  success "Appended quoin rules to ~/.claude/CLAUDE.md"
fi

# ── Step 3b: Write sleep dry-run marker (idempotent — never resets the clock) ──
# NOTE: after editing quoin/CLAUDE.md with sleep phase value + importance signals,
# run bash install.sh BEFORE the first /sleep session (per S-3 T-01 order constraint)
if [ "$DRY_RUN" -ne 1 ]; then
  SLEEP_MARKER="$HOME/.claude/memory/sleep_dryrun_start.txt"
  mkdir -p "$HOME/.claude/memory"
  if [ ! -f "$SLEEP_MARKER" ]; then
    date -u +%Y-%m-%d > "$SLEEP_MARKER"
    success "Wrote sleep dry-run start marker: $SLEEP_MARKER"
  else
    info "Sleep dry-run marker already exists ($SLEEP_MARKER) — date unchanged (clock not reset)."
  fi
fi

# ── Done ──
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   User-level install complete!        ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}$SKILL_COUNT skills${NC} installed in ~/.claude/skills/"
echo -e "  ${GREEN}Workflow rules${NC} written to ~/.claude/CLAUDE.md"
echo -e "  ${GREEN}Terse rubric${NC} copied to ~/.claude/memory/terse-rubric.md"
echo -e "  ${GREEN}v3 reference files${NC} copied to ~/.claude/memory/ (format-kit.md, glossary.md, format-kit.sections.json, summary-prompt.md, format-kit-pitfalls.md)"
echo -e "  ${GREEN}v3 scripts${NC} copied to ~/.claude/scripts/ (validate_artifact.py, path_resolve.py, cost_from_jsonl.py, classify_critic_issues.py, build_preambles.py, analyze_cost_ledger.py)"
echo -e "  ${GREEN}QUICKSTART deployed to ~/.claude/QUICKSTART.md${NC}"
echo ""
echo -e "  ${BLUE}Tip:${NC} re-run bash install.sh to refresh skills, CLAUDE.md, and the rubric together."
echo -e "  ${BLUE}Dev tip:${NC} run bash install.sh --dev to also install pyyaml + pytest for running quoin/dev/tests/."
echo ""
echo -e "  ${BOLD}Next: scaffold a project${NC}"
echo ""
echo -e "  1. ${BLUE}cd /path/to/your/project${NC}"
echo -e "  2. ${BLUE}claude${NC}"
echo -e "  3. Type ${YELLOW}/init_workflow${NC}"
echo ""
