# T-01 — V-03 Byte-Count Calibration Spike: Procedure Spec

**Status:** PROCEDURE SPEC (awaiting live-session measurement runs)
**Date:** 2026-05-03
**Blocks:** T-09 hook implementation (constants must be pinned before userpromptsubmit.sh)

## Purpose

Calibrate the byte-count-based context utilization estimate in `userpromptsubmit.sh`. The hook uses the formula:

```
utilization_bps = (wc -c transcript / BPT / LIMIT) * 10000
```

Where:
- `BPT` = `BYTES_PER_TOKEN_CONSTANT` (default 3.5)
- `LIMIT` = `EFFECTIVE_CONTEXT_LIMIT` (default 150_000)

The spike measures actual transcript byte counts at compaction-fire moments across three session profiles, then verifies the chosen `(BPT, LIMIT)` pair predicts the trigger within ±10%.

## Measurement procedure

### Session setup

For each of three content profiles, start a fresh Claude Code session:
1. **English-heavy** — paste long architecture/lesson-learned prose
2. **Code-heavy** — paste source code dumps (Python/shell files)
3. **Mixed** — real workflow content with mermaid + JSON (e.g., current-plan.md segments)

### Data collection per session

For each prompt turn, immediately after Claude responds, record:
```
wc -c < $(ls -t ~/.claude/projects/<project-hash>/*.jsonl | head -1)
```

The project-hash is the project path with `/` replaced by `-`:
```
~/.claude/projects/-Users-ivgo-Library-CloudStorage-GoogleDrive-ivan-gorban-gmail-com-My-Drive-Storage-Claude-workflow/
```

Continue until the harness fires auto-compaction (or until the context warning appears at ~95%).

**At the trigger moment**, record:
- Final byte count = `100%-mark`
- Cumulative token count from JSONL: sum of `usage.input_tokens + usage.output_tokens` across all assistant messages

### Predicted-vs-actual comparison

For each session, test candidate constants:

| BPT | LIMIT | formula | predicted_bps_at_trigger |
|-----|-------|---------|------------------------|
| 3.0 | 140000 | `bytes / 3.0 / 140000 * 10000` | ? |
| 3.0 | 150000 | `bytes / 3.0 / 150000 * 10000` | ? |
| 3.0 | 160000 | `bytes / 3.0 / 160000 * 10000` | ? |
| 3.5 | 140000 | `bytes / 3.5 / 140000 * 10000` | ? |
| 3.5 | 150000 | `bytes / 3.5 / 150000 * 10000` | ? |
| 3.5 | 160000 | `bytes / 3.5 / 160000 * 10000` | ? |
| 4.0 | 140000 | `bytes / 4.0 / 140000 * 10000` | ? |
| 4.0 | 150000 | `bytes / 4.0 / 150000 * 10000` | ? |
| 4.0 | 160000 | `bytes / 4.0 / 160000 * 10000` | ? |

**Pass criterion:** chosen `(BPT, LIMIT)` predicts trigger within ±10% across ALL three sessions (i.e., predicted utilization is between 9000..10000 bps when the actual trigger fires at 9500+ bps).

### Fallback path

If no `(BPT, LIMIT)` pair passes ±10% across all sessions, switch to the cumulative-usage primitive:
- Walk JSONL on every fire: `python3 -c "import json,sys; total=sum(m.get('usage',{}).get('input_tokens',0)+m.get('usage',{}).get('output_tokens',0) for l in open(sys.argv[1]) for m in [json.loads(l)] if m.get('type')=='assistant'); print(total)" <transcript.jsonl>`
- Divide by `EFFECTIVE_CONTEXT_LIMIT`
- Document the choice in v03_results.md

## Output

Results are written to `quoin/dev/spikes/v03_results.md` per the T-01 spec.

## Pre-existing evidence

Claude Sonnet 4.5/4.6 effective context limit is documented as 200K tokens in the API, but Claude Code sessions auto-compact earlier — observed at ~85-95% of the active context window. The harness appears to set an active window around 150K-180K tokens based on empirical observation. BPT=3.5 is the literature consensus for English prose; code-heavy content tends toward BPT=2.5-3.0 (more single-character tokens). Mixed content 3.5 is a reasonable middle ground.

**Working hypothesis:** `(BPT=3.5, LIMIT=150000)` predicts the trigger within ±10% for mixed/English content; code-heavy sessions may require BPT=3.0 or fallback to cumulative-usage.
