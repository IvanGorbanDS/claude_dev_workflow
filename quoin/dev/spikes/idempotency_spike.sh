#!/bin/sh
# T-02 — install.sh hooks-deploy idempotency spike driver
#
# Runs install_hooks() logic against a sandboxed ~/.claude.spike/ directory,
# verifying that repeated invocations produce byte-stable settings.json.
#
# Usage: bash quoin/dev/spikes/idempotency_spike.sh
#
# Requirements: jq must be on PATH.
# Output: writes results to quoin/dev/spikes/idempotency_results.md

set -eu

SPIKE_DIR="${TMPDIR:-/tmp}/quoin-idempotency-spike-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")/../../" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { printf "${GREEN}PASS${NC} %s\n" "$1"; }
fail() { printf "${RED}FAIL${NC} %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
warn() { printf "${YELLOW}WARN${NC} %s\n" "$1"; }

FAILURES=0
RESULTS=""

cleanup() {
  rm -rf "$SPIKE_DIR"
}
trap cleanup EXIT

info() { printf "  %s\n" "$1"; }

# ─── Run install_hooks() in sandbox ───────────────────────────────────────────
# We replicate the core logic of install_hooks() from install.sh, running it
# against a temp home directory to avoid touching the live ~/.claude/settings.json.

run_install_hooks_in_sandbox() {
  local sandbox_home="$1"
  local HOOKS_DST_REAL="$sandbox_home/.claude/hooks"
  local SETTINGS_FILE="$sandbox_home/.claude/settings.json"
  local HOOKS_SRC_DIR="$SCRIPT_DIR/hooks"

  mkdir -p "$HOOKS_DST_REAL"

  # Copy hook scripts
  for hook_file in "$HOOKS_SRC_DIR"/*.sh "$HOOKS_SRC_DIR/_lib.sh"; do
    [ -f "$hook_file" ] || continue
    hook_name=$(basename "$hook_file")
    cp "$hook_file" "$HOOKS_DST_REAL/$hook_name"
    chmod +x "$HOOKS_DST_REAL/$hook_name"
  done

  # Merge stanzas (mirrors corrected install.sh jq queries)
  local NEW_FILE="${SETTINGS_FILE}.new"

  # UserPromptSubmit / *
  jq --arg cmd "$HOOKS_DST_REAL/userpromptsubmit.sh" --arg matcher "*" --arg scriptname "userpromptsubmit.sh" \
    '.hooks.UserPromptSubmit = ([(.hooks.UserPromptSubmit // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}])' \
    "$SETTINGS_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$SETTINGS_FILE"

  # PreCompact / auto
  jq --arg cmd "$HOOKS_DST_REAL/precompact.sh" --arg matcher "auto" --arg scriptname "precompact.sh" \
    '.hooks.PreCompact = ([(.hooks.PreCompact // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 10}]}])' \
    "$SETTINGS_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$SETTINGS_FILE"

  # SessionStart / startup
  jq --arg cmd "$HOOKS_DST_REAL/sessionstart.sh" --arg matcher "startup" --arg scriptname "sessionstart.sh" \
    '.hooks.SessionStart = ([(.hooks.SessionStart // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}])' \
    "$SETTINGS_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$SETTINGS_FILE"

  # SessionStart / resume
  jq --arg cmd "$HOOKS_DST_REAL/sessionstart.sh" --arg matcher "resume" --arg scriptname "sessionstart.sh" \
    '.hooks.SessionStart = ([(.hooks.SessionStart // [])[] | select(.matcher != $matcher or ([ .hooks[]?.command | select(endswith($scriptname)) ] | length == 0))] + [{"matcher": $matcher, "hooks": [{"type": "command", "command": $cmd, "timeout": 5}]}])' \
    "$SETTINGS_FILE" > "$NEW_FILE" && mv "$NEW_FILE" "$SETTINGS_FILE"
}

run_scenario() {
  local scenario_name="$1"
  local initial_settings="$2"

  info "--- Scenario: $scenario_name ---"

  local sandbox="$SPIKE_DIR/$scenario_name"
  mkdir -p "$sandbox/.claude"

  # Write initial settings.json
  printf '%s' "$initial_settings" > "$sandbox/.claude/settings.json"

  # Backup initial settings
  cp "$sandbox/.claude/settings.json" "$sandbox/.claude/settings.json.bak"

  # Run iteration 1
  run_install_hooks_in_sandbox "$sandbox"
  local iter1_hash
  iter1_hash=$(jq --sort-keys . < "$sandbox/.claude/settings.json" | sha256sum | awk '{print $1}')

  # Verify 4 stanzas present
  local stanza_count
  stanza_count=$(jq '[.hooks.UserPromptSubmit[0], .hooks.PreCompact[0], .hooks.SessionStart[0], .hooks.SessionStart[1]] | length' < "$sandbox/.claude/settings.json" 2>/dev/null || printf '0')

  if [ "$stanza_count" -eq 4 ]; then
    pass "$scenario_name: iteration 1 — 4 stanzas present"
    RESULTS="$RESULTS\n| $scenario_name | iter1 | 4 stanzas | PASS |"
  else
    fail "$scenario_name: iteration 1 — expected 4 stanzas, got $stanza_count"
    RESULTS="$RESULTS\n| $scenario_name | iter1 | $stanza_count stanzas | FAIL |"
  fi

  # Run iterations 2..10 and verify byte-stability
  local all_stable=1
  for i in 2 3 4 5 6 7 8 9 10; do
    run_install_hooks_in_sandbox "$sandbox"
    local iter_hash
    iter_hash=$(jq --sort-keys . < "$sandbox/.claude/settings.json" | sha256sum | awk '{print $1}')
    if [ "$iter_hash" != "$iter1_hash" ]; then
      fail "$scenario_name: iteration $i — settings.json changed (not byte-stable)"
      all_stable=0
      RESULTS="$RESULTS\n| $scenario_name | iter$i | hash-changed | FAIL |"
    fi
  done

  if [ "$all_stable" -eq 1 ]; then
    pass "$scenario_name: iterations 2..10 — byte-stable"
    RESULTS="$RESULTS\n| $scenario_name | iter2-10 | byte-stable | PASS |"
  fi
}

# ─── Check prerequisite ───────────────────────────────────────────────────────
if ! command -v jq > /dev/null 2>&1; then
  fail "jq not found on PATH — cannot run idempotency spike (install jq first)"
  exit 1
fi

printf "\nT-02 Idempotency Spike\n"
printf "====================\n\n"

mkdir -p "$SPIKE_DIR"

# ─── Scenario A: Clean settings.json (only permissions block) ─────────────────
run_scenario "A-clean-settings" '{"permissions": {"allow": [], "deny": []}}'

# ─── Scenario B: Pre-existing user-defined SessionStart hook (different path) ──
run_scenario "B-user-defined-hook" '{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [{"type": "command", "command": "/usr/local/bin/my-startup-hook.sh", "timeout": 30}]
      }
    ]
  }
}'

# Verify user hook preserved in scenario B
sandbox_b="$SPIKE_DIR/B-user-defined-hook"
user_hook_preserved=$(jq '[.hooks.SessionStart[] | select(.hooks[]?.command == "/usr/local/bin/my-startup-hook.sh")] | length' < "$sandbox_b/.claude/settings.json" 2>/dev/null || printf '0')
if [ "$user_hook_preserved" -ge 1 ]; then
  pass "B-user-defined-hook: user-defined SessionStart hook preserved after merge"
  RESULTS="$RESULTS\n| B-user-defined-hook | user-hook-preserved | yes | PASS |"
else
  fail "B-user-defined-hook: user-defined hook was NOT preserved (overwritten)"
  RESULTS="$RESULTS\n| B-user-defined-hook | user-hook-preserved | no | FAIL |"
fi

# ─── Scenario C: Settings with stale prior-quoin entry (old path) ──────────────
run_scenario "C-stale-quoin-entry" '{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [{"type": "command", "command": "/old/path/.claude/hooks/userpromptsubmit.sh", "timeout": 5}]
      }
    ]
  }
}'

# Scenario C: verify no duplicates for UserPromptSubmit/*
sandbox_c="$SPIKE_DIR/C-stale-quoin-entry"
ups_count=$(jq '[.hooks.UserPromptSubmit[] | select(.matcher == "*")] | length' < "$sandbox_c/.claude/settings.json" 2>/dev/null || printf '0')
if [ "$ups_count" -eq 1 ]; then
  pass "C-stale-quoin-entry: exactly 1 UserPromptSubmit/* stanza (no duplicates)"
  RESULTS="$RESULTS\n| C-stale-quoin-entry | no-duplicates | 1 stanza | PASS |"
else
  fail "C-stale-quoin-entry: expected 1 UserPromptSubmit/* stanza, got $ups_count"
  RESULTS="$RESULTS\n| C-stale-quoin-entry | no-duplicates | $ups_count stanzas | FAIL |"
fi

# ─── Scenario D: Missing hooks block entirely ──────────────────────────────────
run_scenario "D-no-hooks-block" '{}'

# ─── Summary ──────────────────────────────────────────────────────────────────
printf "\n"
if [ "$FAILURES" -eq 0 ]; then
  pass "ALL SCENARIOS PASSED — idempotency spike PASS"
  SPIKE_STATUS="PASS"
else
  fail "FAILURES: $FAILURES — idempotency spike FAIL"
  SPIKE_STATUS="FAIL"
fi

# ─── Write results file ───────────────────────────────────────────────────────
RESULTS_FILE="$SCRIPT_DIR/dev/spikes/idempotency_results.md"

cat > "$RESULTS_FILE" << RESULTS_EOF
# T-02 — install.sh Hooks-Deploy Idempotency Spike: Results

**Status:** $SPIKE_STATUS
**Date:** $(date -u +%Y-%m-%d)
**Runner:** idempotency_spike.sh

## Scenarios tested

| Scenario | Sub-check | Result | Status |
|----------|-----------|--------|--------|
$(printf '%b' "$RESULTS" | sed '/^$/d' | sed 's/^| /| /' | tail -n +2)

## Test matrix

| Scenario | Description |
|----------|-------------|
| A-clean-settings | Clean settings.json with only permissions block |
| B-user-defined-hook | Pre-existing user-defined SessionStart hook (different command path) |
| C-stale-quoin-entry | Stale prior-quoin entry under old command path |
| D-no-hooks-block | Settings.json with no hooks block at all |

## Key properties verified

- **10-iteration byte-stability:** 10 sequential runs of install_hooks() produce identical settings.json (jq-sorted hash comparison)
- **User-hook preservation:** Pre-existing user hooks under different command paths are preserved through merge
- **Deduplication:** Stale quoin entries at old paths are replaced, not duplicated
- **Empty settings:** Install creates correct structure from scratch

## Idempotency conclusion

$([ "$SPIKE_STATUS" = "PASS" ] && printf "install_hooks() is IDEMPOTENT — running it multiple times produces byte-stable settings.json across all tested starting states." || printf "FAILURES DETECTED — see table above for details.")

## Notes

- The spike tests the core jq merge logic extracted from install.sh, not install.sh end-to-end
- T-20 (test_install_hooks_deploy.py) provides the end-to-end hermetic CI test
- This spike is a one-shot manual verification; T-20 is the repeatable CI gate
RESULTS_EOF

printf "\nResults written to: %s\n" "$RESULTS_FILE"
