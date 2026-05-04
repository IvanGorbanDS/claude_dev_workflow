# T-02 — install.sh Hooks-Deploy Idempotency Spike: Results

**Status:** PASS
**Date:** 2026-05-04
**Runner:** idempotency_spike.sh

## Scenarios tested

| Scenario | Sub-check | Result | Status |
|----------|-----------|--------|--------|
| A-clean-settings | iter2-10 | byte-stable | PASS |
| B-user-defined-hook | iter1 | 4 stanzas | PASS |
| B-user-defined-hook | iter2-10 | byte-stable | PASS |
| B-user-defined-hook | user-hook-preserved | yes | PASS |
| C-stale-quoin-entry | iter1 | 4 stanzas | PASS |
| C-stale-quoin-entry | iter2-10 | byte-stable | PASS |
| C-stale-quoin-entry | no-duplicates | 1 stanza | PASS |
| D-no-hooks-block | iter1 | 4 stanzas | PASS |
| D-no-hooks-block | iter2-10 | byte-stable | PASS |

## Test matrix

| Scenario | Description |
|----------|-------------|
| A-clean-settings | Clean settings.json with only permissions block |
| B-user-defined-hook | Pre-existing user-defined SessionStart hook (different command path) |
| C-stale-quoin-entry | Stale prior-quoin entry under old command path |
| D-no-hooks-block | Settings.json with no hooks block at all |

## Key properties verified

- **10-iteration byte-stability:** 10 sequential runs of install_hooks() produce identical settings.json (jq-sorted hash comparison)
- **User-hook preservation:** Pre-existing user hooks under different command paths are preserved through merge
- **Deduplication:** Stale quoin entries at old paths are replaced, not duplicated
- **Empty settings:** Install creates correct structure from scratch

## Idempotency conclusion

install_hooks() is IDEMPOTENT — running it multiple times produces byte-stable settings.json across all tested starting states.

## Notes

- The spike tests the core jq merge logic extracted from install.sh, not install.sh end-to-end
- T-20 (test_install_hooks_deploy.py) provides the end-to-end hermetic CI test
- This spike is a one-shot manual verification; T-20 is the repeatable CI gate
