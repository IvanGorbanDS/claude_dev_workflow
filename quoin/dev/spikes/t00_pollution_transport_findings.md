# T-00 Transport Feasibility Spike — Findings

## Verdict: Plan B (userpromptsubmit.sh)

## Evidence

The SessionStart hook payload does NOT include `transcript_path`.

Proof: `test_sessionstart_pending_restore.sh::make_stdin` constructs the test
payload as `{"source":"...","session_id":"...","cwd":"..."}` — no `transcript_path` field.
This matches the Claude Code SessionStart event spec: SessionStart provides session metadata
only (source, session_id, cwd). The `transcript_path` field is provided only by
UserPromptSubmit and PreCompact events, which have an active session with a transcript.

## Decision

T-01 targets `userpromptsubmit.sh` (Plan B), not `sessionstart.sh` (Plan A).

The pollution-score writer is inserted as STEP 0.5 — AFTER STEP -1 (stdin capture)
and BEFORE STEP 0 (recovery-command exemption). This fires on every user prompt,
regardless of command type or utilization level.

Tradeoff accepted: score is computed at last-prompt-submit time rather than session-start
time. This is acceptable — pollution dispatch fires one prompt "late" but never misses
an actually-polluted session.

## T-01 insertion point

```
STEP -1: Capture stdin (STDIN=$(cat))
[NEW] STEP 0.5: Pollution-score writer (runs on EVERY prompt submit)
STEP 0: Recovery-command exemption
STEP 1: Read transcript path
...
```

The STEP 0.5 block reads `transcript_path` from `$STDIN` (same field already parsed
in STEP 1), calls `compute_pollution_score`, and writes to session-state primary
or `pollution-score-latest.txt` fallback. Entire block is fail-OPEN.
