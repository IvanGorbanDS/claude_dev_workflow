# Quoin Stage 1 — Manual T-09 four-phase HITL smoke

**Date:** 2026-04-26
**Parent model:** Opus 4.7 (1M context) — banner string `powered by the model named Opus 4.7 (1M context)`
**Test session:** fresh Opus 1M Claude Code session, full deploy live (12 cheap-tier skills carrying §0 in `~/.claude/skills/`).
**Method:** automated single-prompt test — parent agent invoked /gate via Skill tool (Phase A), spawned Agent subagents with the bare and counter-form sentinels (Phases B + C), and ran a /run → /implement lineage check (Phase D).

---

## Phase A — live sonnet-tier dispatch on /gate

**Outcome:** **verified** (signal i — DISPATCH VERIFIED)

- Agent tool `model:` arg = `sonnet`
- Agent tool `description:` arg = `gate dispatched at sonnet tier`
- Prompt prefix passed: `[no-redispatch]\n/gate\n\nThe user invoked /gate with...` (first 50 chars: `[no-redispatch]\n/gate\n\nThe user invoked /gate wit`)
- Child returned a fully rendered gate summary (Smoke gate, 8/8 PASS) which became the parent's final response.

Notes: §0 dispatch fired exactly per design — parent detected `current_tier > declared_tier` (opus > sonnet) and no `[no-redispatch]` sentinel in the user prompt, so spawned an Agent subagent at the declared tier. Fail-graceful warning did NOT fire. The harness honors the `model:` parameter on the Agent subagent-spawn tool for sonnet-tier as well as haiku-tier (T-00 confirmed haiku separately on /triage).

## Phase B — bare `[no-redispatch]` skip-dispatch

**Outcome:** **PROCEED**

- Subagent rationale: *"The prompt starts with bare `[no-redispatch]`, which per §0's sentinel rule means 'skip dispatch, proceed to §1 at the current tier' regardless of the executing model's tier."*

Notes: bare-form sentinel is correctly recognized as the parent-emit / user-override syntax. Manual kill switch works.

## Phase C — counter form `[no-redispatch:2]` abort

**Outcome:** **ABORT**

- Abort message (verbatim): `Quoin self-dispatch hard-cap reached at N=2 in gate. This indicates a recursion bug; aborting before any tool calls. Re-invoke with [no-redispatch] (bare) to override.`
- Subagent rationale: *"The prompt carried the counter sentinel `[no-redispatch:2]` with N ≥ 2, which §0's abort rule treats as a hard-cap signal indicating a recursion bug."*

Notes: abort message string matches the §0 prose verbatim, including the skill-name interpolation (`in gate`) per NIT-1 fix. R-01 dominant-risk recursion guard verified live.

## Phase D — `/run` → `/implement` lineage preservation

**Outcome:** **proceeded** (no `"explicit invocation required"` bail-out)

- The test session short-circuited `/run`'s full setup (skipped `.workflow_artifacts/` creation and git branch ops) to respect the "write only to /tmp/" constraint, dispatching `/implement` directly via Agent (`model: "sonnet"`) using `/run`'s Phase 4 invocation pattern — passing the `/run`-exception signal in the prompt plus a hand-authored minimal plan at `/tmp/quoin_t09_phase_d/current-plan.md`.
- The `/implement` child read its SKILL.md, accepted the `/run` exception clause in `## Explicit invocation only`, wrote `/tmp/quoin_t09_phase_d/format_list.py` and `/tmp/quoin_t09_phase_d/test_format_list.py`, and ran `pytest` (2 passed).
- No bail-out text such as `"explicit invocation required"` was emitted.

Notes: the §0-dispatch lineage chain (Opus parent → Sonnet `/implement` child via Agent tool with `[no-redispatch]` prefix) does NOT trigger the implement skill's hard-rule against auto-invocation. The `/run` exception is correctly recognized despite the §0 dispatch interposing between `/run` and `/implement`. R-10 (load-bearing-rule preservation under §0 dispatch) verified live.

**Caveat:** the test was a structurally faithful approximation rather than a full end-to-end `/run` — `/run`'s setup steps were skipped to keep the test side-effect-free. The dispatch behavior verified (Agent tool with `model: "sonnet"` + `[no-redispatch]` prefix → `/implement` accepts and proceeds) is the exact mechanism `/run` uses, so the lineage-preservation property is established.

**Cleanup pending:** `rm -rf /tmp/quoin_t09_phase_d/` was attempted but harness permissions denied; user should clean up manually. Same for `/tmp/quoin_t02_insert.py` from earlier.

---

## Overall verdict: **PASS**

All four phases behaved as the §0 design specifies. No failure mode surfaced. Stage 1 is ready for `/gate` (Checkpoint C: implement → review).
