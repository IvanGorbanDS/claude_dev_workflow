# S-4 SessionEnd Feasibility Spike

**Date:** 2026-05-04
**Task:** workflow-isolation-and-hooks / stage-4 / T-00

## Objective

Verify (a) the correct harness event name for session-end, (b) whether `additionalContext`
is a supported output channel for that event, and (c) whether the payload includes a `cwd` field.

## Source

Anthropic Claude Code hooks documentation:
- https://docs.anthropic.com/en/docs/claude-code/hooks (301 redirects to)
- https://code.claude.com/docs/en/hooks (canonical as of 2026-05-04)

## Findings

### Event name

**`SessionEnd`** is the confirmed correct event name.
It is listed in the harness documentation under "Session Lifecycle Events".

### Output channels for SessionEnd

SessionEnd supports: `systemMessage`, `continue`, `stopReason`

**`additionalContext` is NOT listed for SessionEnd.**
This differs from SessionStart, which supports `additionalContext`.

The nudge output channel for sessionend.sh MUST use `systemMessage` (not `additionalContext`).

### Payload fields for SessionEnd

Fields confirmed: `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `end_reason`

**`cwd` IS present in the SessionEnd payload.** ✅

The `$PWD` fallback in sessionend.sh will not normally be needed since `cwd` is in the payload.

### Blocking behavior

SessionEnd **cannot block** — it runs asynchronously. Exit code is ignored.
This is acceptable for our nudge use case (purely observational).

## CASE determination

**CASE A:** `SessionEnd` is a real event.

However, the plan's CASE A assumed `additionalContext` is supported. The docs show only
`systemMessage` for SessionEnd (not `additionalContext`). This is effectively:

**CASE A-modified:** SessionEnd is real, `cwd` is in payload, but output channel is
`systemMessage` (not `additionalContext`). The sessionend.sh implementation MUST use
`systemMessage` format instead of the `hookSpecificOutput.additionalContext` format used
by sessionstart.sh.

### Output format differences

SessionStart uses:
```json
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "..."}}
```

SessionEnd uses (confirmed channel):
```json
{"systemMessage": "..."}
```

Both are non-blocking informational outputs. The `systemMessage` channel injects text
into the next system prompt turn.

## Implications for T-01..T-04

- T-01 (sessionstart.sh): no change — uses `additionalContext` which IS supported on SessionStart ✅
- T-02 (sessionend.sh): change `printf` to emit `{"systemMessage": "..."}` instead of
  `{"hookSpecificOutput": {..., "additionalContext": "..."}}` format
- T-03 (install.sh): no change — registers SessionEnd event ✅
- T-04 (CLAUDE.md): update SessionEnd row note to say `systemMessage` channel ✅

## Manual smoke

Manual smoke: PENDING — T-09 requires a live Claude Code session; automated tests (T-06) cover the logic. Run by opening a new session with `end_of_day_due: yes` set in a session file and observing the banner before running /end_of_task.
