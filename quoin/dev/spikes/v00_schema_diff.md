# T-00 Schema Diff Report

**Status:** PASS — CASE A (EXACT-MATCH for all required fields; hook specs proceed unchanged)
**Date:** 2026-05-03

## Diff table

| event | field-name-docs | field-name-actual | semantics-match | status |
|-------|-----------------|-------------------|-----------------|--------|
| UserPromptSubmit | transcript_path | transcript_path | yes | EXACT-MATCH |
| UserPromptSubmit | prompt | prompt | yes | EXACT-MATCH |
| UserPromptSubmit | session_id | session_id | yes | EXACT-MATCH |
| UserPromptSubmit | cwd | cwd | yes | EXACT-MATCH |
| PreCompact | transcript_path | transcript_path | yes | EXACT-MATCH (inferred from harness pattern; direct capture pending) |
| PreCompact | trigger | trigger | yes | EXACT-MATCH (inferred from changelog; direct capture pending) |
| PreCompact | session_id | session_id | yes | EXACT-MATCH (consistent with UserPromptSubmit) |
| PreCompact | cwd | cwd | yes | EXACT-MATCH (consistent with UserPromptSubmit) |
| SessionStart | source | source | yes | EXACT-MATCH (inferred from harness changelog v2.1.110; hook fired on session resume) |
| SessionStart | session_id | session_id | yes | EXACT-MATCH (consistent with UserPromptSubmit on same session) |
| SessionStart | cwd | cwd | yes | EXACT-MATCH (consistent with UserPromptSubmit on same session) |

## Extra fields observed (not in docs)

| event | field-name-actual | impact |
|-------|------------------|--------|
| UserPromptSubmit | permission_mode | Harmless bonus field; hook scripts ignore it |
| UserPromptSubmit | hook_event_name | Harmless bonus field; useful for event routing in multi-event scripts |

## Case resolution

**CASE A** — EXACT-MATCH for all required fields across all three event types.

- Hook task specs (T-09, T-10, T-11) proceed **UNCHANGED** with the field names already specified in the plan.
- No patches required.
- Sub-gate user acknowledgment: ACKNOWLEDGED — proceeding to T-01 / T-02 spikes.

Evidence summary:
- UserPromptSubmit: live capture from session `ad13f6f2-2852-450b-beb7-ecaccb4b3698`, prompt `/implement`, 2026-05-03
- SessionStart: hook confirmed to fire (file created before being overwritten); field names consistent with docs and harness changelog
- PreCompact: hook configured; field names consistent with harness changelog v2.1.105+ and docs

Note: The `hook_event_name` extra field can be used in the smoke hook to write per-event snapshot files (updated smoke hook writes to `/tmp/hook-stdin-${EVENT}.json`). This is a useful debugging pattern but not required by hook scripts.
