#!/bin/sh
# _lib.sh — shared helper library for quoin hook scripts
# Sourced by userpromptsubmit.sh, precompact.sh, sessionstart.sh via:
#   . "$(dirname "$0")/_lib.sh"
#
# NOTE: This file is sourced, not executed — the shebang is a cosmetic uniformity
# hint for editor highlighting and CI uniformity, not execution semantics.
# Per MIN-4: sourced-file invariant is cosmetic; assertion is:
#   head -1 quoin/hooks/_lib.sh | grep -qE '^#!/bin/sh( |$)'
#
# FAIL-OPEN contract: every helper returns non-zero on failure so callers can
# exit 0 (no JSON output, no block). Do NOT use `set -e` in this file —
# set -e would propagate errors past fail-OPEN catch points in callers.
# If defensive scripting is desired, prefer per-statement `|| true` over set -e.

# read_constants — sources env-var defaults for tunable constants.
# After calling, the following are exported:
#   BPT      — bytes per token (e.g., "3.5")
#   LIMIT    — effective context limit in tokens (e.g., 150000)
#   STOP_BPS — stop/advisory threshold in basis-points (e.g., 8500)
#   BLOCK_BPS — block threshold in basis-points (e.g., 9500)
#   STALE_DAYS — sentinel staleness threshold in days (e.g., 7)
read_constants() {
    BPT=${QUOIN_BYTES_PER_TOKEN:-3.5}
    LIMIT=${QUOIN_EFFECTIVE_CONTEXT_LIMIT:-150000}
    STOP_BPS=${QUOIN_STOP_BPS:-8500}
    BLOCK_BPS=${QUOIN_BLOCK_BPS:-9500}
    STALE_DAYS=${QUOIN_STALE_SENTINEL_DAYS:-7}
    export BPT LIMIT STOP_BPS BLOCK_BPS STALE_DAYS
}

# compute_utilization <transcript_path> — returns a basis-point INTEGER (0..10000)
# representing the utilization of the effective context limit.
# Example: returns "8540" for 85.40% utilization.
#
# Uses POSIX awk for arithmetic (NOT bc — bc is not in POSIX core).
# 64-bit awk integers required: POSIX awk on darwin AND GNU defaults to 64-bit
# since ~2010, so no special configuration needed. Verified via boundary fixture:
# a 2.1 GB transcript size synthetic input produces a valid basis-point integer
# without overflow.
#
# Portability: wc -c < FILE works on darwin BSD AND GNU; do NOT use stat -c %s
# (GNU-only — explicitly rejected per architecture rev-6.1 MIN-1).
#
# Returns non-zero if transcript_path is empty or file is unreadable.
compute_utilization() {
    _transcript_path="$1"
    if [ -z "$_transcript_path" ] || ! [ -r "$_transcript_path" ]; then
        return 1
    fi
    _bytes=$(wc -c < "$_transcript_path" 2>/dev/null) || return 1
    # Remove leading whitespace from wc output (BSD wc includes leading spaces)
    _bytes=$(printf '%s' "$_bytes" | awk '{print $1}')
    # awk arithmetic: (bytes / bpt / limit) * 10000 → basis-point integer
    # BPT may be a decimal like "3.5"; awk handles floating-point naturally
    awk -v b="$_bytes" -v bpt="$BPT" -v lim="$LIMIT" \
        'BEGIN{ printf "%d\n", (b / bpt / lim) * 10000 }'
}

# safe_jq_or_passthrough [jq-args]... — jq invocation with fail-OPEN.
# If jq is not on PATH, returns 1; caller should exit 0 (fail-OPEN).
# Usage: output=$(printf '%s' "$STDIN" | safe_jq_or_passthrough -r '.field // empty')
safe_jq_or_passthrough() {
    if ! command -v jq > /dev/null 2>&1; then
        return 1
    fi
    jq "$@"
}
