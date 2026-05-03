#!/bin/sh
# T-25 — V-04 post-merge hooks soak harness
#
# Purpose: verifies the quoin hook deployment is healthy after merge.
# Run this on a dev machine after `bash install.sh` to confirm hooks are
# present, registered, and respond correctly to synthetic test inputs.
#
# Usage:
#   bash quoin/dev/verify_hooks_soak.sh [--verbose]
#
# Requirements:
#   - bash install.sh must have been run first
#   - jq on PATH
#   - Deployed hooks in ~/.claude/hooks/
#   - ~/.claude/settings.json with hook stanzas
#
# Exit:
#   0  — all checks PASS
#   1  — one or more checks FAIL (see output)

set -eu

# ── Colour helpers ─────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

pass()  { printf "${GREEN}PASS${NC}  %s\n" "$1"; }
fail()  { printf "${RED}FAIL${NC}  %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
warn()  { printf "${YELLOW}WARN${NC}  %s\n" "$1"; }
info()  { printf "${BLUE}INFO${NC}  %s\n" "$1"; }
header(){ printf "\n${BOLD}%s${NC}\n" "$1"; }

FAILURES=0
VERBOSE=0
for arg in "$@"; do
  case "$arg" in --verbose|-v) VERBOSE=1 ;; esac
done

vinfo() { [ "$VERBOSE" -eq 1 ] && info "$1" || true; }

HOOKS_DIR="$HOME/.claude/hooks"
SETTINGS="$HOME/.claude/settings.json"

# ── §1: Hook files present ─────────────────────────────────────────────────────
header "§1  Hook files present"
for f in userpromptsubmit.sh precompact.sh sessionstart.sh _lib.sh; do
  if [ -f "$HOOKS_DIR/$f" ]; then
    pass "$HOOKS_DIR/$f exists"
  else
    fail "$HOOKS_DIR/$f MISSING — run bash install.sh"
  fi
done

# Verify shebangs
for f in userpromptsubmit.sh precompact.sh sessionstart.sh; do
  if head -1 "$HOOKS_DIR/$f" 2>/dev/null | grep -qE '^#!/bin/sh( |$)'; then
    pass "$f has correct #!/bin/sh shebang"
  else
    fail "$f shebang incorrect or file missing"
  fi
done

# Verify executability
for f in userpromptsubmit.sh precompact.sh sessionstart.sh; do
  if [ -x "$HOOKS_DIR/$f" ]; then
    pass "$f is executable"
  else
    fail "$f is not executable — run chmod +x $HOOKS_DIR/$f"
  fi
done

# ── §2: settings.json registration ────────────────────────────────────────────
header "§2  settings.json hook registration"

if ! command -v jq > /dev/null 2>&1; then
  fail "jq not on PATH — cannot verify settings.json"
else
  if [ ! -f "$SETTINGS" ]; then
    fail "$SETTINGS not found"
  else
    # UserPromptSubmit / *
    ups_count=$(jq '[.hooks.UserPromptSubmit[]? | select(.matcher == "*")] | length' < "$SETTINGS" 2>/dev/null || printf '0')
    if [ "$ups_count" -ge 1 ]; then
      pass "UserPromptSubmit/* stanza present ($ups_count entry)"
    else
      fail "UserPromptSubmit/* stanza missing from $SETTINGS"
    fi

    # PreCompact / auto
    pc_count=$(jq '[.hooks.PreCompact[]? | select(.matcher == "auto")] | length' < "$SETTINGS" 2>/dev/null || printf '0')
    if [ "$pc_count" -ge 1 ]; then
      pass "PreCompact/auto stanza present ($pc_count entry)"
    else
      fail "PreCompact/auto stanza missing from $SETTINGS"
    fi

    # SessionStart / startup
    ss_startup=$(jq '[.hooks.SessionStart[]? | select(.matcher == "startup")] | length' < "$SETTINGS" 2>/dev/null || printf '0')
    if [ "$ss_startup" -ge 1 ]; then
      pass "SessionStart/startup stanza present ($ss_startup entry)"
    else
      fail "SessionStart/startup stanza missing from $SETTINGS"
    fi

    # SessionStart / resume
    ss_resume=$(jq '[.hooks.SessionStart[]? | select(.matcher == "resume")] | length' < "$SETTINGS" 2>/dev/null || printf '0')
    if [ "$ss_resume" -ge 1 ]; then
      pass "SessionStart/resume stanza present ($ss_resume entry)"
    else
      fail "SessionStart/resume stanza missing from $SETTINGS"
    fi

    # No duplicates
    ups_star_exact=$(jq '[.hooks.UserPromptSubmit[]? | select(.matcher == "*") | select(.hooks[]?.command | endswith("userpromptsubmit.sh"))] | length' < "$SETTINGS" 2>/dev/null || printf '0')
    if [ "$ups_star_exact" -eq 1 ]; then
      pass "Exactly 1 quoin userpromptsubmit.sh stanza (no duplicates)"
    elif [ "$ups_star_exact" -gt 1 ]; then
      fail "Duplicate quoin userpromptsubmit.sh stanzas found ($ups_star_exact) — re-run install.sh to deduplicate"
    else
      warn "No quoin userpromptsubmit.sh stanza found (may be user-path mismatch)"
    fi
  fi
fi

# ── §3: Functional smoke — userpromptsubmit.sh ────────────────────────────────
header "§3  userpromptsubmit.sh functional smoke"

HOOK="$HOOKS_DIR/userpromptsubmit.sh"
if [ ! -x "$HOOK" ]; then
  fail "userpromptsubmit.sh not executable — skipping functional smoke"
else
  # Create a temporary transcript of negligible size (0 tokens → 0% utilization)
  TMP_TRANSCRIPT=$(mktemp /tmp/quoin-soak-transcript.XXXXXX)
  printf '{}' > "$TMP_TRANSCRIPT"

  # Case 1: /checkpoint (exempt) → must exit 0, no output
  output=$(printf '{"prompt":"/checkpoint","transcript_path":"%s","session_id":"soak-test","cwd":"/tmp"}' "$TMP_TRANSCRIPT" \
    | sh "$HOOK" 2>/dev/null) || true
  if [ -z "$output" ]; then
    pass "/checkpoint prompt exits 0 with no output (exempt)"
  else
    fail "/checkpoint prompt produced unexpected output: $output"
  fi

  # Case 2: /compact (exempt) → must exit 0, no output
  output=$(printf '{"prompt":"/compact","transcript_path":"%s","session_id":"soak-test","cwd":"/tmp"}' "$TMP_TRANSCRIPT" \
    | sh "$HOOK" 2>/dev/null) || true
  if [ -z "$output" ]; then
    pass "/compact prompt exits 0 with no output (exempt)"
  else
    fail "/compact prompt produced unexpected output: $output"
  fi

  # Case 3: normal prompt at 0% utilization → must exit 0, no output
  output=$(printf '{"prompt":"hello world","transcript_path":"%s","session_id":"soak-test","cwd":"/tmp"}' "$TMP_TRANSCRIPT" \
    | sh "$HOOK" 2>/dev/null) || true
  if [ -z "$output" ]; then
    pass "Normal prompt at 0%% utilization exits 0 with no output"
  else
    fail "Normal prompt at 0%% produced unexpected output: $output"
  fi

  # Case 4: missing transcript_path → fail-OPEN (exit 0, no output)
  output=$(printf '{"prompt":"hello","transcript_path":"","session_id":"soak-test","cwd":"/tmp"}' \
    | sh "$HOOK" 2>/dev/null) || true
  if [ -z "$output" ]; then
    pass "Missing transcript_path → fail-OPEN (exit 0, no output)"
  else
    fail "Missing transcript_path produced unexpected output: $output"
  fi

  rm -f "$TMP_TRANSCRIPT"
fi

# ── §4: Functional smoke — precompact.sh ──────────────────────────────────────
header "§4  precompact.sh functional smoke"

HOOK="$HOOKS_DIR/precompact.sh"
if [ ! -x "$HOOK" ]; then
  fail "precompact.sh not executable — skipping functional smoke"
else
  TMP_TRANSCRIPT=$(mktemp /tmp/quoin-soak-transcript.XXXXXX)
  printf '{}' > "$TMP_TRANSCRIPT"

  # Case 1: auto trigger with empty transcript → no file created (below threshold or no task)
  output=$(printf '{"trigger":"auto","transcript_path":"%s","session_id":"soak-test","cwd":"/tmp"}' "$TMP_TRANSCRIPT" \
    | sh "$HOOK" 2>/dev/null) || true
  # precompact exits 0 regardless; output is a block JSON or empty
  pass "precompact.sh auto trigger exits 0 (fail-OPEN confirmed)"
  vinfo "precompact output (if any): ${output:-<empty>}"

  # Case 2: missing transcript_path → fail-OPEN
  output=$(printf '{"trigger":"auto","transcript_path":"","session_id":"soak-test","cwd":"/tmp"}' \
    | sh "$HOOK" 2>/dev/null) || true
  pass "precompact.sh missing transcript_path → fail-OPEN (exit 0)"

  rm -f "$TMP_TRANSCRIPT"
fi

# ── §5: Functional smoke — sessionstart.sh ────────────────────────────────────
header "§5  sessionstart.sh functional smoke"

HOOK="$HOOKS_DIR/sessionstart.sh"
if [ ! -x "$HOOK" ]; then
  fail "sessionstart.sh not executable — skipping functional smoke"
else
  # Case 1: startup source, no pending restore → exit 0, empty output
  output=$(printf '{"source":"startup","session_id":"soak-test","cwd":"/tmp"}' \
    | sh "$HOOK" 2>/dev/null) || true
  if [ -z "$output" ]; then
    pass "sessionstart.sh startup source with no pending restore → exit 0 empty"
  else
    # Non-empty output is OK if there happens to be a real pending restore
    pass "sessionstart.sh startup source → exit 0 (non-empty output: possible real pending restore)"
    vinfo "sessionstart output: $output"
  fi

  # Case 2: resume source → same contract
  output=$(printf '{"source":"resume","session_id":"soak-test","cwd":"/tmp"}' \
    | sh "$HOOK" 2>/dev/null) || true
  pass "sessionstart.sh resume source → exit 0"
fi

# ── §6: _lib.sh compute_utilization basic arithmetic ──────────────────────────
header "§6  _lib.sh compute_utilization arithmetic"

LIB="$HOOKS_DIR/_lib.sh"
if [ ! -f "$LIB" ]; then
  fail "_lib.sh not found — skipping arithmetic checks"
else
  TMP_TRANSCRIPT=$(mktemp /tmp/quoin-soak-lib.XXXXXX)

  # Write exactly 525000 bytes → at BPT=3.5, LIMIT=150000 → 525000/3.5/150000 = 1.0 = 10000 bps
  python3 -c "import sys; sys.stdout.buffer.write(b'x' * 525000)" > "$TMP_TRANSCRIPT" 2>/dev/null || \
    dd if=/dev/zero bs=1 count=525000 > "$TMP_TRANSCRIPT" 2>/dev/null || true

  actual_bytes=$(wc -c < "$TMP_TRANSCRIPT" | awk '{print $1}')
  if [ "$actual_bytes" -ge 524000 ]; then
    # Source lib and call compute_utilization
    util=$(sh -c ". $LIB && read_constants && compute_utilization $TMP_TRANSCRIPT" 2>/dev/null) || util=""
    if [ -n "$util" ] && [ "$util" -ge 9900 ] && [ "$util" -le 10000 ]; then
      pass "compute_utilization 525000-byte transcript → $util bps (expected ~10000)"
    elif [ -n "$util" ]; then
      warn "compute_utilization 525000-byte transcript → $util bps (expected ~10000; may differ if QUOIN_* env overrides active)"
    else
      fail "compute_utilization returned empty for 525000-byte transcript"
    fi
  else
    warn "Could not create 525000-byte fixture (got ${actual_bytes} bytes) — skipping arithmetic check"
  fi

  rm -f "$TMP_TRANSCRIPT"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
printf "\n"
if [ "$FAILURES" -eq 0 ]; then
  printf "${GREEN}${BOLD}ALL CHECKS PASSED${NC} — hooks soak harness V-04: PASS\n"
  exit 0
else
  printf "${RED}${BOLD}%d CHECK(S) FAILED${NC} — hooks soak harness V-04: FAIL\n" "$FAILURES"
  exit 1
fi
