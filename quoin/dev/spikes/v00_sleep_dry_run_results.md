# /sleep --dry-run Spike Results
Date: 2026-05-04

## Scan sources
- Real daily/: .workflow_artifacts/memory/daily/
- Fixture corpus: quoin/dev/tests/fixtures/sleep/

## Results
- Total entries scanned: 5
- Proposed promotes: 1
- Proposed forgets: 0
- Middle band: 4

## Rate Assessment

- Promote accepted: 1 (after dedup against lessons-learned)
- Note: dedup rejection rate requires a no-dedup comparison run (manual step)

- Forget candidates: 0 (manual override-rate review needed)
- Note: full override-rate check requires manual session-file cross-reference

## Restore Round-Trip Check
- Forget candidates checked for restore anchor: 0
- No forget candidates available for restore check (0 forget-bucket entries in this run).

## Detailed Decisions

### Real daily/ corpus (2 files, 2 entries)
```
MIDDLE-BAND (2):
  1. [P=0, F=0] ### Insight 7: Same-session /review bias ...
  2. [P=0, F=0] ## Session-age guard correctly fires on this 7h chat session
```

### Fixture corpus (3 entries)
```
PROMOTE (1):
  1. [P=6, F=0] ### Insight 1: hook timeout calibration

MIDDLE-BAND (2):
  1. [P=5, F=5] ### Insight 1: one-shot config issue
  2. [P=5, F=5] ### Insight 2: temp workaround for missing library
```

Notes:
- The fixture promote (hook timeout calibration) fires on user_marked_yes (5) + structural_fit (1) = 6.
- The middle-band fixture entries score equally on promote and forget (both user_marked_yes/no + structural signals) — expected behavior for middle_band/ fixture.
- Real daily entries score P=0, F=0 (no tags, no structural keywords matched) — middle band as expected.
- 0 forgets: real entries are not stale (mtime recent); no Promote?: no tags in real files.

## Verdict: DATA RECORDED

Corpus size (5 entries) meets minimum threshold (>= 5).
Full rate-threshold pass criteria (promote-rejected <= 50%, forget-override <= 25%)
require manual review. Bucket distribution recorded for calibration.

### Manual review checklist
- [ ] Review PROMOTES list for noise/false-positives
- [ ] Review FORGETS list for entries still referenced in recent sessions
- [ ] Confirm restore anchor parseable for all forget candidates
- [ ] Adjust weights in quoin/CLAUDE.md if rates exceed thresholds
