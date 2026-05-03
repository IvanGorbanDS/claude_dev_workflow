# T-01 — V-03 Byte-Count Calibration Spike: Results

**Status:** AWAITING LIVE MEASUREMENT
**Date:** 2026-05-03
**Procedure:** See `v03_bytecount_calibration.md`

## Decision (PROVISIONAL — pending live measurement)

Based on pre-existing evidence and literature consensus:

- **Primary primitive:** byte-count (`wc -c`)
- **BYTES_PER_TOKEN_CONSTANT:** `3.5`
- **EFFECTIVE_CONTEXT_LIMIT:** `150000`

These are the defaults baked into `quoin/hooks/_lib.sh` via `read_constants()`. The values are tunable per-session via environment variable overrides (`QUOIN_BYTES_PER_TOKEN`, `QUOIN_EFFECTIVE_CONTEXT_LIMIT`).

## Rationale for provisional values

1. **BPT=3.5:** Published consensus for English prose + code mixed content. GPT/Claude tokenizers average 3-4 bytes per token; 3.5 is the midpoint and matches practical observation.
2. **LIMIT=150000:** Claude Code sessions (Sonnet 4.5/4.6) observe compaction firing between 130K-170K tokens in practice. 150K as denominator means `bps=9500` fires at `150000 * 3.5 * 0.95 ≈ 498750 bytes ≈ 487 KB` — a reasonable triggering point for a multi-hour workflow session.

## Live measurement results (TO BE FILLED IN)

### Session 1: English-heavy

| turn | bytes | predicted_bps (BPT=3.5, LIMIT=150K) | notes |
|------|-------|--------------------------------------|-------|
| ... | ... | ... | ... |
| TRIGGER | ? | ? | compaction fired |

### Session 2: Code-heavy

| turn | bytes | predicted_bps (BPT=3.5, LIMIT=150K) | notes |
|------|-------|--------------------------------------|-------|
| ... | ... | ... | ... |
| TRIGGER | ? | ? | compaction fired |

### Session 3: Mixed

| turn | bytes | predicted_bps (BPT=3.5, LIMIT=150K) | notes |
|------|-------|--------------------------------------|-------|
| ... | ... | ... | ... |
| TRIGGER | ? | ? | compaction fired |

## Pass/fail evaluation

| (BPT, LIMIT) | session-1 predicted@trigger | session-2 predicted@trigger | session-3 predicted@trigger | pass? |
|---|---|---|---|---|
| (3.5, 150000) | ? | ? | ? | PENDING |

## Final decision

```yaml
v03_status: pending_live_measurement
primary_primitive: byte_count
BYTES_PER_TOKEN_CONSTANT: 3.5
EFFECTIVE_CONTEXT_LIMIT: 150000
env_var_bpt: QUOIN_BYTES_PER_TOKEN
env_var_limit: QUOIN_EFFECTIVE_CONTEXT_LIMIT
fallback_available: cumulative_usage_jsonl
```

## Fallback path (if byte-count fails ±10%)

If `(BPT=3.5, LIMIT=150000)` fails the ±10% criterion for any session, the userpromptsubmit hook switches to the cumulative-usage primitive:

```sh
# Cumulative-usage fallback in _lib.sh compute_utilization()
# Walk JSONL: sum usage.input_tokens + usage.output_tokens across all assistant messages
total_tokens=$(python3 -c "
import json, sys
total = 0
for line in open(sys.argv[1]):
    try:
        m = json.loads(line)
        if m.get('type') == 'assistant':
            u = m.get('usage', {})
            total += u.get('input_tokens', 0) + u.get('output_tokens', 0)
    except: pass
print(total)
" "$transcript_path" 2>/dev/null) || return 1
awk -v t="$total_tokens" -v lim="$LIMIT" \
    'BEGIN{ printf "%d\n", (t / lim) * 10000 }'
```

Document the choice in this file (update `v03_status` to `passed` or `fell_back_to_cumulative_usage`).

## Notes on BLOCKS-MERGE status

T-01 BLOCKS MERGE per architecture rev-6.1. The provisional values (BPT=3.5, LIMIT=150000) are already baked into the shipped hook scripts, so implementation can proceed. The live measurement must be run before the PR is merged to verify the provisional values are within ±10% OR to trigger the fallback path update. This file serves as the acceptance record — update `v03_status` to `passed` before merge.
