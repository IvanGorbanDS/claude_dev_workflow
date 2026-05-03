# T-01 — V-03 Byte-Count Calibration Spike: Results

**Status:** PASSED
**Date:** 2026-05-03
**Procedure:** See `v03_bytecount_calibration.md`

## Decision

Based on live measurement across 3 session profiles:

- **Primary primitive:** byte-count (`wc -c`)
- **BYTES_PER_TOKEN_CONSTANT:** `8.0`
- **EFFECTIVE_CONTEXT_LIMIT:** `150000`

These are the defaults baked into `quoin/hooks/_lib.sh` via `read_constants()`. The values are tunable per-session via environment variable overrides (`QUOIN_BYTES_PER_TOKEN`, `QUOIN_EFFECTIVE_CONTEXT_LIMIT`).

## Rationale

1. **BPT=8.0:** JSONL transcripts contain massive JSON overhead per message (metadata, usage objects, role markers, timestamps, tool call/result payloads) that inflates bytes-per-token well beyond the 3.5 literature value for plain text. Live measurement showed BPT=3.5 predicted 21,898 bps at the compaction trigger — 2.3x overshoot. Back-solving from session 2's trigger at 1,149,615 bytes gives BPT≈7.66; rounding to 8.0 yields 9,580 bps at trigger — correctly in the block zone (>9500).
2. **LIMIT=150000:** Claude Code sessions auto-compact around 130K-170K tokens. 150K as denominator remains appropriate — the BPT correction absorbs the byte-count inflation.

## Live measurement results

### Session 1: English-heavy (no compaction triggered)

| turn | bytes | predicted_bps (BPT=8.0, LIMIT=150K) | notes |
|------|-------|--------------------------------------|-------|
| 1 | 290,039 | 2,417 | below advisory |
| 2 | 618,548 | 5,155 | below advisory |
| 3 | 1,003,217 | 8,360 | advisory zone (>8500 not reached) — session ended |

### Session 2: Code-heavy (compaction triggered)

| turn | bytes | predicted_bps (BPT=8.0, LIMIT=150K) | notes |
|------|-------|--------------------------------------|-------|
| 1 | 412,541 | 3,438 | below advisory |
| TRIGGER | 1,149,615 | **9,580** | **compaction fired** |
| post-compact | 1,213,744 | 10,115 | post-compaction (includes compacted + new) |
| final | 1,241,170 | 10,343 | session finished |

### Session 3: Mixed (no compaction triggered)

| turn | bytes | predicted_bps (BPT=8.0, LIMIT=150K) | notes |
|------|-------|--------------------------------------|-------|
| 1 | 130,889 | 1,091 | below advisory |
| 2 | 164,892 | 1,374 | below advisory |
| 3 | 271,217 | 2,260 | below advisory — session ended |

## Pass/fail evaluation

| (BPT, LIMIT) | session-1 (no trigger) | session-2 @trigger | session-3 (no trigger) | pass? |
|---|---|---|---|---|
| (3.5, 150000) | 19,108 (would false-block) | 21,898 (2.3x overshoot) | 5,166 | **FAIL** |
| (8.0, 150000) | 8,360 (correct: no trigger) | **9,580** (in block zone) | 2,260 (correct: no trigger) | **PASS** |

**BPT=8.0, LIMIT=150,000 passes:**
- Session 2: 9,580 bps at compaction trigger — within the block zone (>9,500) ✓
- Session 1: 8,360 bps with no compaction — correctly below block threshold ✓
- Session 3: 2,260 bps with no compaction — correctly below advisory threshold ✓

## Final decision

```yaml
v03_status: passed
primary_primitive: byte_count
BYTES_PER_TOKEN_CONSTANT: 8.0
EFFECTIVE_CONTEXT_LIMIT: 150000
env_var_bpt: QUOIN_BYTES_PER_TOKEN
env_var_limit: QUOIN_EFFECTIVE_CONTEXT_LIMIT
fallback_available: cumulative_usage_jsonl
calibration_date: 2026-05-03
calibration_sessions: 3
compaction_events_observed: 1
```

## Notes

- The 8.0 BPT reflects JSONL-specific overhead, not plain-text tokenization. If the harness ever changes transcript format, BPT will need recalibration.
- Only 1 of 3 sessions hit compaction. The V-04 soak harness (T-25) will collect more data points post-merge to validate the constant under broader usage patterns.
- Session 1 reached 8,360 bps (advisory zone) but didn't trigger compaction — this is consistent with the harness firing around 9,500+ bps.
