---
task: stage-4-smoke
date: 2026-04-25
status: pre-flight-complete
---

## Pre-flight checks (completed this session)

- [x] `bash dev-workflow/install.sh` — 21 skills deployed; `~/.claude/scripts/with_env.sh` present
- [x] `pytest scripts/tests/ -q` — 88 passed, 2 skipped (Stage 2/3/4 full suite)
- [x] T-19 all 6 grep checks satisfied (8-skill detection-rule 1/1, summarize_for_human 0, .original.md 0, git log --oneline 0)
- [x] All 14 Stage 4 commits on `feat/v3-stage-4`

## Live smoke: PENDING (requires fresh session)

The live acceptance smoke (steps 3-8 in T-18 procedure) must run in a fresh Claude Code session per the plan's fresh-context rule ("do NOT share the implementer session — fresh-session bias rule per parent Stage 3 insight 7").

### Procedure (for the fresh session)

1. Open a fresh Claude session in this workspace
2. `/architect "stage 4 smoke — exercise all Class A v3 writes; no production change"` against `.workflow_artifacts/v3-stage-4-smoke/`
   - Verify: `architecture.md` v3 valid (validator pass + `## For human` block via Haiku with with_env.sh)
   - Verify: Checkpoint A gate displays architecture summary; audit log `gate-architect-{date}.md` v3-format
3. `/thorough_plan medium: stage 4 smoke trivial change`
   - Verify: plan converges in ≤2 rounds
   - Verify: `current-plan.md` v3 valid AND has `## Convergence Summary` heading (T-03 fix)
   - Verify: `critic-response-1.md` v3 valid (heading-line verdict, table scorecard, terse-list issues)
   - Verify: Checkpoint B gate audit log v3-format
4. `/implement` (no-op task — write a 1-line scratch.py)
   - Verify: session state at `sessions/{today}-v3-stage-4-smoke.md` v3-format (all 5 required sections + `## Cost`)
   - Verify: Checkpoint C gate audit log v3-format
5. `/review`
   - Verify: `review-1.md` v3 valid (Class B Haiku summary block)
   - Verify: session-state write v3-format (5 required sections + `## Cost`)
   - Verify: Checkpoint D gate audit log v3-format
6. Compute: Class A writes total / fallbacks → success rate ≥95%
7. Update this file with results and commit

## Success criteria
- All v3-format checks pass at each step
- ≥95% structural validation success rate (≤2 v2 fallbacks out of ~12-15 writes)
- t18-smoke-result.md updated with per-step verdicts and committed
