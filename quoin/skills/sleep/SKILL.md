---
name: sleep
description: "Memory promote/forget — moves insights from daily scratchpad to long-term memory and soft-forgets stale artifacts. STUB: this skill ships in S-2 as a pidfile lifecycle stub only. Full /sleep body (memory promote/forget) ships in architecture stage 3."
model: haiku
---

# Sleep

**STUB — S-2 ships only the §0c pidfile lifecycle block. Full /sleep body (memory promote/forget) is architecture stage 3 scope.**

## §0c Pidfile lifecycle (FIRST STEP)

At entry — immediately after any future §0 dispatch block resolves (S-3 will add §0 dispatch above this block):

```
. ~/.claude/scripts/pidfile_helpers.sh && pidfile_acquire sleep
```

If the script is missing or fails (e.g., fresh install): emit one-line warning `[quoin-S-2: pidfile helpers unavailable; proceeding without lifecycle protection]` and continue without abort (fail-OPEN).

At exit — call from every completion path AND every error/abort path:
```
pidfile_release sleep
```

Use a trap when the skill body involves bash-driven subagents:
```
trap 'pidfile_release sleep' EXIT
```

Purpose: lets `precompact.sh` hook know a `/sleep` session is active when S-3 ships.

**S-3 extension note:** architecture stage 3 will EXTEND this stub by adding the §0 Model dispatch preamble ABOVE this §0c block, plus the full /sleep skill body below. The §0c block placement rule (last-§0-class-block) will continue to hold — §0c becomes last after §0 is added. The T-19 drift-test handles this correctly with `variant=stub` in S-2, transitioning to `variant=canonical` or similar when S-3 lands.
