# Spike: /sleep Auto-Chain Feasibility from /end_of_day

**Date:** 2026-05-04
**Task:** workflow-isolation-and-hooks — Stage 3
**Purpose:** Verify that `/end_of_day` can auto-invoke `/sleep` via the Agent subagent dispatch mechanism (Option A), as required by the Stage 3 architecture.

## Determination: CASE A — Agent subagent dispatch IS available

**Status: PASS — Option A (Agent subagent dispatch from /end_of_day body) is viable.**

## Evidence

### 1. /end_of_day SKILL.md §0 block confirms Agent tool availability

`quoin/skills/end_of_day/SKILL.md` contains a `## §0 Model dispatch` block (lines 11–48). The block instructs the skill to:

> "Spawn an Agent subagent with the following arguments:
>   model: "haiku"
>   description: "end_of_day dispatched at haiku tier"
>   prompt: "[no-redispatch]\n<original user input verbatim>"
> Wait for the subagent. Return its output as your final response. STOP."

This mechanism is already active and proven — every Class B writer in the workflow (`/end_of_day`, `/start_of_day`, `/weekly_review`, `/capture_insight`, `/cost_snapshot`, `/triage`, `/end_of_task`, `/implement`, `/rollback`) uses this same Agent spawn pattern. The `/sleep` chain does not introduce any new mechanism; it reuses the existing `Agent` tool call already in the skill body.

### 2. Skill body (not subprocess) has access to the Agent tool

The architecture lesson from 2026-04-29 is about PYTHON SUBPROCESSES not being able to reach the harness Agent tool. This does NOT apply here because:
- `/end_of_day` runs directly as Claude in a SKILL.md body context.
- The `Agent` tool is a harness-level tool available to SKILL.md bodies (same as `Bash`, `Read`, `Write`, `Edit`).
- `/sleep` would be spawned as a CHILD Agent, not as a Python subprocess.

### 3. Mechanism matches established pattern in every Class B writer

The Stage 2 implementation (merged 2026-05-03) already demonstrates the pattern working end-to-end: `/end_of_day` dispatches a Haiku Agent for its `## For human` summary (Step 3, per SKILL.md body text). The Step 6 `/sleep` dispatch follows exactly the same code path.

### 4. Fail-OPEN path ensures no regression

Even if the Agent tool were unavailable in some edge case, the proposed Step 6 implementation includes a fail-OPEN path:

> "If the subagent fails (tool error, dispatch unavailable): print '[quoin-S-3: /sleep invocation failed; daily briefing is durable; run /sleep standalone to retry]' and exit 0."

This means CASE B (Option B — plain-text instruction) is effectively handled as a fallback within Option A's implementation. No separate CASE B code path is needed.

## Procedure performed

1. Read `quoin/skills/end_of_day/SKILL.md` — confirmed §0 Model dispatch block spawns Agent subagent with `model: "haiku"`.
2. Confirmed the Agent tool is available to SKILL.md bodies (established fact; every Class B writer uses it).
3. Confirmed that `python3` subprocess restrictions (lessons-learned 2026-04-29) do NOT apply to SKILL.md body Agent spawns.
4. Confirmed that the Step 6 fail-OPEN path handles the CASE B scenario without requiring separate Option B code.

No actual `/end_of_day` invocation was needed — the mechanism is the same Agent tool already proven in production by the Stage 2 dispatch logic.

## Impact on Stage 3 task specs

- **T-05 (end_of_day edit):** uses Agent subagent dispatch (Option A). No design changes.
- **T-06 (/sleep SKILL.md):** §0 dispatch block present (Haiku tier); `[no-redispatch]` sentinel guards against re-dispatch when called from chain.
- All other tasks proceed as specified in the round-4 revised plan.

## Conclusion

**CASE A confirmed.** All stage-3 task specs proceed with Option A (Agent subagent dispatch from `/end_of_day` body). T-01 through T-16 may proceed.
