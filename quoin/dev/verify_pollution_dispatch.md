# Quoin S-1 Production Smoke — Pollution Dispatch Verification

Manual HITL checklist for verifying §0' pollution dispatch in production.
Mirror of `verify_subagent_dispatch.md` but for the S-1 pollution mechanism.

Fill in **Result** and **Notes** columns as you run each scenario.
Threshold default: 5000. Score written by `userpromptsubmit.sh` STEP 0.5 (Plan B).

## Verification scenarios

### Scenario 1: Fresh session (control — §0' must NOT fire)

**Setup:** Open a brand-new Claude Code session (no prior conversation history).
**Action:** Invoke `/plan <any task description>`.
**Expected:** §0' does NOT fire. Skill runs in main session without spawning a subagent.
**How to verify:** No `[no-redispatch]` prefix visible in session; no subagent spawn message.
Score in session-state (if any) should be ~0 (fresh session, tiny transcript).

| Step | Check | Result | Notes |
|------|-------|--------|-------|
| 1a | `/plan <task>` invoked in fresh session | | |
| 1b | No subagent spawned | | |
| 1c | pollution_score in session-state file is < 5000 (or absent) | | |

---

### Scenario 2: Polluted session (§0' must fire)

**Setup:** Run 20+ tool-heavy operations in a session (read files, run bash, multiple
agent dispatches) to accumulate a large transcript. Alternatively: invoke at least
one prior planning or architect cycle in this session.
**Action:** After heavy work, invoke `/plan <task>` or `/architect <task>`.
**Expected:** §0' fires. A subagent is spawned carrying the dispatch contract.
**How to verify:** Skill emits message about dispatching; subagent runs independently.

| Step | Check | Result | Notes |
|------|-------|--------|-------|
| 2a | Heavy work done (20+ tool calls OR large transcript) | | |
| 2b | Invoke `/plan <task>` | | |
| 2c | §0' fires — subagent spawned with `[no-redispatch]` prefix | | |
| 2d | Subagent runs and returns result | | |
| 2e | pollution_score in session-state is >= 5000 | | |

---

### Scenario 3: Override with [no-redispatch] sentinel

**Setup:** In a polluted session (as in Scenario 2).
**Action:** Invoke `[no-redispatch] /plan <task>`.
**Expected:** §0' does NOT fire. Skill runs in the polluted main session.
**How to verify:** No subagent spawned. Skill proceeds normally in main.

| Step | Check | Result | Notes |
|------|-------|--------|-------|
| 3a | Polluted session confirmed (score >= 5000) | | |
| 3b | `[no-redispatch] /plan <task>` invoked | | |
| 3c | §0' skipped — no subagent spawned | | |
| 3d | Skill proceeds in main session | | |

---

### Scenario 4: Refusal path (ambiguous invocation)

**Setup:** In a polluted session.
**Action:** Invoke `/plan` with no concrete task description (just "plan the thing").
**Expected:** §0' emits refusal warning `[quoin-S-1: cannot extract per-skill dispatch contract; running in main]` and proceeds in main.
**How to verify:** Warning visible in output; no subagent spawned; skill runs in main.

| Step | Check | Result | Notes |
|------|-------|--------|-------|
| 4a | Polluted session confirmed | | |
| 4b | `/plan` with no concrete description | | |
| 4c | Warning `[quoin-S-1: cannot extract per-skill dispatch contract; running in main]` visible | | |
| 4d | No subagent spawned | | |
| 4e | Skill proceeds in main | | |

---

### Scenario 5: Multi-skill spot-check

**Setup:** Polluted session as in Scenario 2.
**Action:** Invoke `/critic` and `/architect` separately.
**Expected:** §0' fires for both. Per-skill dispatch contracts are correct:
  - `/critic` dispatch prompt carries `Target: <path>`
  - `/architect` dispatch prompt carries architecture context paths

| Step | Check | Result | Notes |
|------|-------|--------|-------|
| 5a | `/critic` — §0' fires, subagent spawned | | |
| 5b | `/critic` dispatch prompt contains `Target:` | | |
| 5c | `/architect` — §0' fires, subagent spawned | | |
| 5d | `/architect` dispatch prompt contains `repos-inventory.md` | | |

---

## Summary

| Scenario | Pass/Fail | Notes |
|----------|-----------|-------|
| 1: Fresh session — §0' does NOT fire | | |
| 2: Polluted session — §0' fires | | |
| 3: [no-redispatch] override works | | |
| 4: Refusal path for ambiguous invocation | | |
| 5: Multi-skill spot-check | | |

**Overall verdict:** PASS / FAIL

**Tester:** _______________  **Date:** _______________

**Threshold used:** `QUOIN_POLLUTION_THRESHOLD` = _______ (default: 5000)
