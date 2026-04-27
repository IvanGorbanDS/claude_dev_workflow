---
task: quoin-foundation
phase: architect
date: 2026-04-25
model: claude-opus-4-7
class: B
---
## For human

**Current status:** Workflow has six structural defects causing cost overruns and data collisions; a six-stage fix is proposed, each independently shippable.

**Biggest open risk:** Self-dispatch recursion (stage 1) could burn tokens infinitely if the sentinel guard fails; mitigated by a counter-based abort on second dispatch attempt.

**What's needed to make progress:** User review and approval of this architecture document; then sequential implementation of stages 1–6, with stage 1 (self-dispatch preamble) unblocking the others.

**What comes next:** After gate checkpoint, user runs `/thorough_plan large: stage-1 of quoin-foundation` to plan the self-dispatch preamble work; stages 2–3 can parallelize; stage 4 depends on stage 3; stage 5 depends on stage 1; stage 6 (rebrand) runs last after all others merge.

## Context

Workflow has accumulated six structural defects in active use. Lesson 2026-04-22 already paid ~$140 for one task largely b/c of cost-tracking gaps and recursive Opus critic. Lesson 2026-04-25 already paid for a `set -u` rc-sourcing hang in the Haiku summarizer. The defects compound: each one shows up across multiple skills, and several mask each other (cost ledger reports 0 sessions when ccusage is missing → user can't tell if the model-inheritance bug is also wasting money).

Six concrete user-reported issues:
1. Cheap-tier skills (gate/end_of_day/cost_snapshot/...) inherit the parent session's model. When the user is on Opus 1M, every `/gate` invocation runs on Opus 1M despite `model: sonnet` frontmatter.
2. `/architect` produces `architecture.md` with no critic step; only `/gate` reviews it. Other planning skills get `/critic` for free via `/thorough_plan`.
3. `ccusage` may be missing on the user's machine; cost reporting silently degrades to "no cost ledger" rather than computing dollars from local JSONL files.
4. Multi-stage tasks share one task folder, so `current-plan.md` and `critic-response-N.md` get overwritten across stages (this lesson is logged but never codified).
5. The `## For human` block requires `ANTHROPIC_API_KEY` and the `with_env.sh` shell wrapper because `summarize_for_human.py` calls the Anthropic SDK directly. Native Claude Code auth is not used.
6. Repo branding is "claude_dev_workflow"; user wants "Quoin". `init_workflow` Step 7 also writes `QUICKSTART.md` into a project-level `dev-workflow/` directory whose only purpose is holding that one file.

Constraints:
- Workflow must remain self-bootstrapping (every skill reads its own state from disk; no cross-session memory).
- No new external runtime dependencies (Claude Code CLI, git, Python 3 stdlib + pyyaml + anthropic-as-optional are the existing surface).
- `~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.claude/memory/`, `~/.claude/scripts/` deployed by `install.sh` remain the authoritative copy at runtime.
- v3 artifact-format-architecture invariants (V-01..V-07) must keep passing.
- Existing in-flight task folders (artifact-format-architecture, caveman-token-optimization, v3-stage-3-smoke, v3-stage-4-smoke) are mid-execution and must not be migrated retroactively.

Non-functional requirements:
- Cost discipline: model-dispatch fix should reduce typical session cost on Opus 1M by ~5-10x for cheap-tier work.
- Backward compatibility: an existing user pulling these changes and running `bash quoin/install.sh` (post-rename) should converge to the new state w/o manual migration.
- Determinism: cost fallback must not call any LLM (per lesson 2026-04-23 on LLM-replay non-determinism).

## Current state

Skills live as Markdown files w/ YAML frontmatter under `dev-workflow/skills/<name>/SKILL.md`. `install.sh` copies them to `~/.claude/skills/<name>/SKILL.md`. Scripts under `dev-workflow/scripts/` are copied to `~/.claude/scripts/`. Reference files under `dev-workflow/memory/` (terse-rubric, format-kit, glossary, format-kit.sections.json) are copied to `~/.claude/memory/`.

When user types `/gate`, Claude Code loads `~/.claude/skills/gate/SKILL.md` and executes its instructions in the current session. The `model: sonnet` frontmatter is metadata; it does not switch the session's model. Same pattern for `/end_of_day` (haiku), `/start_of_day` (haiku), `/triage` (haiku), `/capture_insight` (haiku), `/cost_snapshot` (haiku), `/weekly_review` (haiku), `/end_of_task` (sonnet), `/implement` (sonnet), `/rollback` (sonnet), `/expand` (sonnet), `/revise-fast` (sonnet). Twelve cheap-tier skills, all running on whatever the session's current model is.

`/architect` Phase 1 (scan) does spawn Sonnet subagents via Task tool — that pattern works b/c those subagents specify `model: "sonnet"` in their dispatch. The same Task-tool mechanism is the lever for fixing #1.

`/architect` produces `architecture.md` then stops. The skill file references "Phase 4 critic" in one place ([architect/SKILL.md:303](dev-workflow/skills/architect/SKILL.md#L303)) but Phase 4 is never defined. `/thorough_plan` and `/plan` get critic loops; `/architect` does not.

Cost ledger rows have shape `<uuid> | <date> | <phase> | <model> | task | <note>`. `/end_of_task` Step 6 and `/cost_snapshot` both shell out to `npx ccusage session -i <UUID> --json` for dollar amounts. When `ccusage` is not installed, both skills print "ccusage not available" and report 0 dollars. The session JSONL files at `~/.claude/projects/<project-hash>/<uuid>.jsonl` contain everything needed to compute cost (per-message `model`, `usage.input_tokens`, `usage.output_tokens`, `usage.cache_creation_input_tokens`, `usage.cache_read_input_tokens`) but no fallback parser exists.

Multi-stage tasks (e.g., `caveman-token-optimization` Stage 1, then Stage 2) currently share one folder. `current-plan.md` from Stage 1 gets overwritten when Stage 2's `/plan` runs. `critic-response-1.md` from Stage 2 collides with the same filename from Stage 1. Lesson 2026-04-18 documents this exact failure but the convention is not codified anywhere.

`/architect`, `/plan`, `/revise`, `/revise-fast`, `/review`, `/critic` all invoke `bash ~/.claude/scripts/with_env.sh python3 ~/.claude/scripts/summarize_for_human.py <body-tmp>` to generate the `## For human` block (Class B Step 2). The script lazy-imports `anthropic`, requires `ANTHROPIC_API_KEY`, calls `claude-haiku-4-5-20251001` directly. `with_env.sh` exists solely to source the user's `~/.zshrc` to pick up the API key in non-interactive subshells.

Repo identity is `claude_dev_workflow` (GitHub `FourthWiz/claude_dev_workflow`), source dir is `dev-workflow/`, CLAUDE.md references it as `dev-workflow/...`, README badges/headers say "Claude Dev Workflow". Twenty-six files contain `dev-workflow` references (103 occurrences). `init_workflow` Step 7 writes `QUICKSTART.md` to `<project>/dev-workflow/QUICKSTART.md` — creating a project-level `dev-workflow/` directory whose only contents are that file (the other "expected" files in Step 5's tree, like SETUP.md and Workflow-User-Guide.html, aren't actually copied to the user's project — only QUICKSTART.md is generated).

## Proposed architecture

Six independent fixes layered into six stages. Each stage is independently shippable, has its own gate, and rolls back cleanly w/o blocking the others. Stage 6 (rebrand) is sequenced last to avoid path-conflict churn during stages 1-5.

### Self-dispatch preamble (item #1)

Each cheap-tier SKILL.md gets a §0 prelude inserted before §1:

```
## §0 Model dispatch (FIRST STEP — execute before anything else)

This skill is declared `model: <declared>`. If the executing agent is running on a model
strictly more expensive than the declared tier, you MUST self-dispatch before doing the
skill's actual work.

Detection:
  - Read your current model from the system context ("powered by the model named X").
  - Tier order: haiku < sonnet < opus.
  - If current_tier > declared_tier AND prompt does NOT start with "[no-redispatch]":
      Spawn an Agent subagent with:
        model: "<declared>"
        description: "<skill name> dispatched at <declared> tier"
        prompt: "[no-redispatch]\n<original user input verbatim>"
      Wait for the subagent. Return its output as your final response. STOP.
  - Otherwise (already at or below declared tier, OR prompt has [no-redispatch] sentinel):
      Proceed to §1 (skill body).
```

The `[no-redispatch]` sentinel prevents infinite recursion: if an Agent subagent re-loads the same skill, the prompt already has the sentinel, so it skips dispatch and runs the body.

Dispatch happens once per user invocation. The single dispatch-instruction read in the parent (Opus 1M) costs ~200-500 tokens; the body's heavy work runs in the subagent at the declared tier. Net savings depend on body size — for /end_of_day's structured-template work (~2-5K tokens of output), Opus 1M → Haiku is ~30x cost reduction.

### ccusage fallback (item #4)

New script `dev-workflow/scripts/cost_from_jsonl.py` deployed to `~/.claude/scripts/cost_from_jsonl.py`. Pure-stdlib JSONL parser. CLI mirrors ccusage's relevant subset:

```
cost_from_jsonl.py session -i <UUID> --json
cost_from_jsonl.py session --json --since YYYY-MM-DD
```

Output JSON is shaped to be a drop-in replacement for `ccusage session ... --json`:

```
{"sessionId": "...", "totalCost": 1.23, "totalTokens": 12345,
 "entries": [{"model": "...", "costUSD": 0.5, "tokens": 1000}, ...]}
```

Pricing table baked in as Python constants w/ `LAST_UPDATED = "2026-04-25"`:

```
PRICES = {  # USD per 1M tokens
  "claude-opus-4-7": {"input": 15.00, "output": 75.00,
                      "cache_create": 18.75, "cache_read": 1.50},
  "claude-sonnet-4-6": {...},
  "claude-haiku-4-5-20251001": {...},
}
```

When invoked, the script walks `~/.claude/projects/<project-hash>/<uuid>.jsonl` (or all files in `~/.claude/projects/<project-hash>/` for `--since` mode), aggregates per-message `usage.*_tokens` × model price, prints JSON to stdout. Exit 0 on success, 2 on UUID-not-found, 1 on parse error.

Update `/end_of_task` Step 6, `/cost_snapshot` Step 2 to call ccusage first, fall back to `cost_from_jsonl.py` on missing-binary or non-zero exit. Both paths produce the same JSON shape, so the parser stays one branch. Print a one-line "[fallback: cost_from_jsonl.py — prices as of 2026-04-25]" notice in fallback mode so the user knows the source.

`install.sh` deploys the new script alongside `validate_artifact.py`. `summarize_for_human.py` and `with_env.sh` stay deployed in stage 2; they are removed in stage 5 once item #6 lands.

### Stage subfolder convention (item #5)

Codify in CLAUDE.md "Task subfolder convention":

```
When a task has multiple stages, create per-stage subfolders:

  .workflow_artifacts/<task-name>/
  ├── architecture.md           ← parent-level (single source of truth)
  ├── cost-ledger.md            ← parent-level (single ledger across all stages)
  ├── stage-1/
  │   ├── current-plan.md
  │   ├── critic-response-1.md
  │   ├── review-1.md
  │   └── gate-*.md
  ├── stage-2/
  │   └── ...
  └── ...

A task is "multi-stage" if architecture.md exists with a `## Stage decomposition`
section. Single-stage tasks use the parent-task-folder layout (no stage subfolder).

Existing task folders predating this convention (those without stage-N/ subfolders
and predating <date>) are grandfathered. Skills MUST detect both layouts.
```

Skills that read/write planning artifacts get a path-resolver helper. Resolution order:

```
1. If user invocation includes "stage N of <task>", path = <task>/stage-N/
2. Else if architecture.md exists at <task>/ AND has ## Stage decomposition AND
   user invocation references a stage by name (e.g., "model-dispatch"):
     resolve stage N from architecture's stage table → path = <task>/stage-N/
3. Else: path = <task>/  (single-stage / legacy layout)
```

Updates needed:
- CLAUDE.md "Task subfolder convention" — add the convention text above.
- `/thorough_plan` SKILL.md Setup §1 — add stage-resolution to "determine the task subfolder".
- `/plan`, `/critic`, `/revise`, `/revise-fast`, `/review`, `/implement`, `/gate` SKILL.md — change `<task>/current-plan.md` references to use the resolved path.
- `/end_of_task` Step 7 — its existing `stage-*` sub-task auto-detection is already aligned; verify no regression.

### Architect critic phase (item #2)

Add Phase 4 to `/architect` after Phase 3 stage decomposition:

```
### Phase 4: Critic loop (max 2 rounds default; max 4 in strict mode)

After writing architecture.md, spawn /critic --target=architecture.md as a fresh
Agent subagent. Always Opus, never tiered (per CLAUDE.md non-negotiable rule).

  Round 1:
    Spawn /critic with: target=architecture.md, repo paths
    Output: architecture-critic-1.md (Class A)

    If verdict = PASS → done. Proceed to Save session state.
    If verdict = REVISE → continue.

  Round 2:
    /architect itself re-runs synthesis with critic feedback (no separate
    /revise-architect skill — architect IS the synthesis skill). Re-write
    architecture.md (Steps 1-6 of Class B writer mechanism).
    Spawn /critic again → architecture-critic-2.md.

    If verdict = PASS → done.
    If verdict = REVISE → continue (in strict mode only; otherwise stop and
    inform user with remaining concerns).

Convergence rules mirror /thorough_plan's: PASS → done; max-rounds → stop with
remaining concerns; loop detection (same CRITICAL/MAJOR title across rounds) →
escalate to user.

Cost guard: max-rounds default is 2 (NOT 4-5 like /thorough_plan). Architecture
should converge fast or signal that requirements are unclear. Lesson 2026-04-22's
~$140 incident is the explicit anti-target: an Opus-only critic loop that ran
3 rounds on a docs-only change.
```

`/architect`'s frontmatter remains `model: opus` (Phase 2 synthesis needs Opus). Phase 4 critic spawns fresh Agent w/ explicit `model: "opus"`. The wiring already exists in the SKILL.md tier-3-critic section but the Phase 4 process body is what was missing.

### Native Haiku summarizer (item #6)

Replace the `bash with_env.sh python3 summarize_for_human.py <body-tmp>` invocation w/ an inline Agent subagent in each Class B writer's Step 2:

```
Step 2: Summary generation (Agent subagent).

Read the frozen prompt template from ~/.claude/memory/summary-prompt.md.
Read the body content from <path>.body.tmp.
Spawn an Agent subagent with:
  model: "haiku"
  description: "Generate ## For human summary"
  prompt: <prompt-template> + "\n\nBody to summarize:\n" + <body-content>
Capture the subagent's response text as summary_raw.

Failure handling: if the Agent dispatch fails OR returns empty after stripping
whitespace, treat as Step 2 failure → trigger Step 5 retry path (re-run Step 2
once; if it still fails, fall back to v2-style write w/o ## For human block).
```

New file `dev-workflow/memory/summary-prompt.md` (Tier 1, hand-edited; never compressed) holds the prompt template currently embedded in `summarize_for_human.py`:

```
You are summarizing a workflow artifact for a human reader who will skim, not read end-to-end.
Produce a `## For human` summary covering, in 5-8 lines of plain English:
1. Current status (one line).
2. Biggest open risk or blocker (one line).
3. What's needed to make progress (one line).
4. What comes next (one line).
Constraints: do NOT invent facts not present in the body. Do NOT use compressed/terse
syntax. Do NOT exceed 8 lines.
```

`install.sh` deploys this new file alongside `format-kit.md`, `glossary.md`, `terse-rubric.md`. Deleted: `summarize_for_human.py`, `with_env.sh`, `tests/test_summarize_for_human.py` (if it exists), and any references in skill SKILL.md to either.

The Agent subagent runs on Haiku regardless of parent session model — same mechanism that fixes item #1. Cost per summary: ~$0.005-0.02 (subagent ~5-10K base context overhead + ~400 output tokens × Haiku price). Direct script was ~$0.001-0.005. Slight cost increase, but eliminates ANTHROPIC_API_KEY requirement and rc-sourcing complexity entirely.

Class B writer skills that change: `/architect` Step 2, `/plan` Step 2, `/revise` Step 2, `/revise-fast` Step 2, `/review` Step 2, `/critic` Step 2 (if Class B variant exists). Stage 5's /implement scope is the diff across these six SKILL.md files.

### Quoin rebrand (item #7)

Rename source directory `dev-workflow/` → `quoin/`. Update install.sh's path expectations (it reads from `$SCRIPT_DIR/skills`, `$SCRIPT_DIR/memory`, `$SCRIPT_DIR/scripts` — all relative to the script's own location, so the rename works mechanically). Update CLAUDE.md every `dev-workflow/...` reference (~26 files, ~103 occurrences). Update README.md w/ Quoin branding (logo/banner/tagline). Update `init_workflow` Step 7: write `QUICKSTART.md` to `<project>/.workflow_artifacts/QUICKSTART.md` instead of `<project>/dev-workflow/QUICKSTART.md`. Migrate the legacy-detection prompt in `init_workflow` Step 3 to also detect old `<project>/dev-workflow/QUICKSTART.md` and offer migration.

GitHub repo rename `FourthWiz/claude_dev_workflow` → `FourthWiz/Quoin` is a manual user action via GitHub UI (we can't push that change from a PR). GitHub's auto-redirect handles `git clone` URLs for old users. Document the rename in the Stage 6 commit message + CHANGELOG.

### Component diagram

```
                user types /<skill>
                       │
                       ▼
              Claude Code loads
              ~/.claude/skills/<skill>/SKILL.md
                       │
                       ▼
            ┌──────────────────────────┐
            │   §0 Self-dispatch       │  ← stage 1 adds this
            │   (cheap-tier skills)    │
            └──────┬─────────────┬─────┘
                   │             │
                  YES           NO  (already at tier OR sentinel present)
                   │             │
                   ▼             ▼
            Spawn Agent       Run skill body
            (model=declared,
             prompt prefixed
             [no-redispatch])
                   │             │
                   └──────┬──────┘
                          ▼
                  Skill writes to disk
                          │
                          ▼
            .workflow_artifacts/<task>/[stage-N/]<artifact>
              ↑ stage 3 codifies the [stage-N/] segment

            Class B writer Step 2:
              Spawn Agent (model=haiku)              ← stage 5 replaces script
              Prompt: summary-prompt.md + body.tmp
              Capture stdout as summary_raw
              Compose final file w/ ## For human + body

            /end_of_task Step 6 / /cost_snapshot Step 2:
              Try: npx ccusage session ...
              Fallback: cost_from_jsonl.py session ...   ← stage 2 adds this
              Same JSON shape, single parser branch

            /architect Phase 4 (post-architecture.md):       ← stage 4 adds this
              Spawn /critic --target=architecture.md (Opus)
              If REVISE → re-run synthesis → re-spawn /critic
              Max 2 rounds (default) / 4 (strict)
```

## Integration analysis

| ID | Integration point | Failure mode | Mitigation |
|----|-------------------|--------------|------------|
| I-01 | Self-dispatch detection (stage 1) | Mis-detection of current model tier (e.g., harness reports unknown model name) | Default to "no-dispatch" (proceed at current tier) on detection failure; log a one-line warning. Better to overspend than to recurse infinitely. |
| I-02 | Self-dispatch sentinel (stage 1) | Parent skill spawns child without `[no-redispatch]` prefix → infinite recursion | Hard cap: detect 2nd dispatch attempt (sentinel-counter via Agent prompt convention `[no-redispatch:N]`); abort w/ error if N≥2. |
| I-03 | ccusage fallback price drift (stage 2) | Anthropic changes prices; baked-in table goes stale | Fallback prints "[prices as of 2026-04-25]" notice every time. README has update procedure. Lesson appended to lessons-learned.md when prices observed to drift. |
| I-04 | JSONL schema drift (stage 2) | Claude Code changes session-log file format | Defensive parsing: tolerate missing fields (treat as 0 tokens), log a one-line warning per unknown field, never crash. Add a dedicated unit test against a real session JSONL fixture. |
| I-05 | Stage subfolder layout vs existing tasks (stage 3) | Existing in-flight task folders break when skills update path resolution | Resolver checks both layouts (stage-N/ and root) and uses whichever exists. Existing tasks predating the convention are grandfathered indefinitely. |
| I-06 | Architect critic infinite loop (stage 4) | Same MAJOR issue title reappears across rounds | Loop detection (per /thorough_plan): compare round N's CRITICAL/MAJOR titles vs round N-1; if any match, escalate to user. Hard max-rounds = 2 default, 4 strict. |
| I-07 | Native summarizer Agent context bleed (stage 5) | Subagent inherits parent's huge context → cache miss + cost spike | Agent tool always starts fresh subagents w/ no parent context. Pass only the prompt template + body bytes. Verify w/ token-count smoke test on stage 5 acceptance. |
| I-08 | Rebrand path conflicts (stage 6) | Stages 1-5 may have fresh refs to `dev-workflow/` that conflict with rename | Hard ordering: stage 6 runs ONLY after stages 1-5 are merged to main. Stage 6 plan includes a final grep sweep for residual `dev-workflow` strings before commit. |
| I-09 | install.sh idempotency post-rename (stage 6) | Users running old install.sh against renamed repo break | The rename commit also updates install.sh's banner messages but its $SCRIPT_DIR-relative path logic is invariant. Test on fresh clone before merge. |
| I-10 | Class B writer V-06/V-07 invariants (stage 5) | Native summarizer's output may differ in shape from script's, breaking V-06 line count or V-07 required-section detection | Stage 5 acceptance: run validate_artifact.py against ≥3 freshly-generated Class B artifacts (architecture, plan, review) and verify all V invariants pass. |

## Risk register

| ID | Risk | Likelihood | Impact | Mitigation | Rollback |
|----|------|-----------|--------|------------|----------|
| R-01 | Self-dispatch recursion bug (item #1) burns tokens infinitely | Low | High | Sentinel + counter (I-02); test with synthetic recursive invocation in stage-1 acceptance | Revert §0 preamble from affected skills; redeploy via install.sh |
| R-02 | ccusage fallback price table staleness (item #4) reports wrong dollars | Medium | Low | `[prices as of YYYY-MM-DD]` notice every fallback invocation; lessons-learned entry on observed drift | Strip price table from script; force ccusage-only path |
| R-03 | Stage-subfolder convention (item #5) breaks orchestrators that hardcoded path strings | Low | Medium | Path-resolver helper, not string substitution; both layouts supported indefinitely; migration is opt-in (new tasks only) | Revert resolver change; skills fall back to root-level paths |
| R-04 | Architect critic loop (item #2) runs away on cost (recall ~$140 lesson 2026-04-22) | Medium | High | Hard max-rounds=2 default, Opus-only critic enforced, recursive-self-critique warning when task targets `/architect` itself | Set max-rounds=0; architect produces architecture.md without critic (current behavior) |
| R-05 | Native summarizer (item #6) Agent overhead exceeds script cost | Low | Low | Smoke test on stage 5 acceptance: ≥3 summaries, measure tokens; if >5x script cost, investigate or revert | Re-deploy summarize_for_human.py + with_env.sh from git history |
| R-06 | Quoin rename (item #7) breaks user installs | Low | Medium | GitHub auto-redirect for git URLs; CHANGELOG entry; install.sh path-relative logic preserves idempotency | Rename `quoin/` → `dev-workflow/` (also a one-shot revert) |
| R-07 | install.sh marker-sentinel (`# === DEV WORKFLOW START ===`) shifts during rebrand and breaks merge logic | Low | High (existing user CLAUDE.md gets corrupted) | Markers stay verbatim — they don't reference the dir name. Stage 6 acceptance: re-run install.sh against an existing seeded `~/.claude/CLAUDE.md` and verify single-section replacement. | Manual: revert ~/.claude/CLAUDE.md from git or `~/.claude/CLAUDE.md.backup` (install.sh writes one) |
| R-08 | Stage 5 prompt-template drift in `summary-prompt.md` (item #6) silently changes summary shape | Low | Medium | Tier 1 hand-edited file; PRs touching it require explicit reviewer call-out; lessons-learned entry on observed drift | Restore prior version from git; per-skill Step 2 includes a content-hash assertion if prompt-template version changes |
| R-09 | Multi-stage in-flight tasks (artifact-format-architecture, caveman-token-optimization, etc.) get accidentally migrated to new layout (item #5) | Low | Medium | Resolver explicitly preserves existing layouts; stage 3 plan includes "do not touch existing task folders" acceptance criterion | Resolver fallback to root-level path is automatic |
| R-10 | Recursive self-critique on stages that modify `/architect` itself (e.g., this task's stage 4) | High | Medium (cost) | Detect at architect Phase 4: if task target includes architect/SKILL.md, warn user upfront and cap max-rounds=1 by default for that case | Manual: bypass critic for the affected task by setting max-rounds=0 |

## De-risking strategy

Six concrete steps before / during implementation:

1. Stage 1 includes a synthetic-recursion test: artificially invoke the §0 preamble w/ a known-bad sentinel and verify the abort-on-recursion guard fires. Land this test before any production skill ships the preamble.
2. Stage 2 includes a real-JSONL fixture test: parse a saved session JSONL from this very task and assert the cost matches what ccusage reports (within 1%). The price-table baseline is empirical, not invented.
3. Stage 3 ships the resolver helper as a small Python module deployed to `~/.claude/scripts/path_resolve.py` and exercised by all skills via `python3 -c "import path_resolve; print(path_resolve.task_path('quoin-foundation', stage=2))"`. Deterministic, testable, single source of truth. Alternative: pure SKILL.md prose w/ string-substitution rules (less testable, more drift risk).
4. Stage 4 ships a hard cost guard: emit a "[critic round 2 starting — ~$10-30 estimated based on body size]" notice before round 2, requiring user confirmation. This prevents another lesson 2026-04-22 incident.
5. Stage 5 keeps the old script(s) deployed for one stage's grace period — i.e., stage 5 ships the new Agent-based path AND keeps `summarize_for_human.py`/`with_env.sh` as a fallback that triggers if Agent dispatch fails 3x in a row. Removal of the scripts is deferred to a stage 5b (or absorbed into stage 6).
6. Stage 6 includes a "fresh-clone install" acceptance test: clone the repo, run install.sh, run /init_workflow in a sample project, verify all paths resolve. Land this test before merge.

## Stage decomposition

1. ⏳ S-01: Self-dispatch preamble for cheap-tier skills (item #1)
   - Scope: insert §0 preamble into 12 SKILL.md files (gate, end_of_day, start_of_day, triage, capture_insight, cost_snapshot, weekly_review, end_of_task, implement, rollback, expand, revise-fast). Update install.sh to redeploy. Add synthetic recursion test.
   - Exclusions: Opus-tier skills (architect, plan, critic, revise, thorough_plan, run, init_workflow, discover, review) do NOT get the preamble — they should run on Opus.
   - Prerequisites: none.
   - Complexity: M (12 SKILL.md edits, 1 test, 1 install.sh check).
   - Key risks: R-01 (recursion), R-10 (low here).
   - Testing strategy: synthetic recursion test (assert abort fires); manual: invoke /gate from Opus 1M session and verify subagent dispatch.
   - Rollback: revert SKILL.md edits; redeploy via install.sh.

2. ⏳ S-02: ccusage fallback via cost_from_jsonl.py (item #4)
   - Scope: new `dev-workflow/scripts/cost_from_jsonl.py`. Update install.sh deployment. Update `/cost_snapshot` Step 2 + `/end_of_task` Step 6 to call ccusage first, fallback on failure.
   - Exclusions: not changing the ledger row format. Not adding new phases. Not touching `/end_of_day` or `/weekly_review` (they explicitly skip ccusage per current design — keep it that way).
   - Prerequisites: none.
   - Complexity: M (new ~200-line script, 2 SKILL.md edits, 1 install.sh edit, 1 fixture test).
   - Key risks: R-02 (price drift), I-04 (JSONL schema drift).
   - Testing strategy: real-JSONL fixture from this task; ccusage-vs-fallback parity within 1%; missing-binary path; missing-UUID path.
   - Rollback: delete cost_from_jsonl.py; revert /cost_snapshot and /end_of_task to ccusage-only.

3. ⏳ S-03: Stage-subfolder convention (item #5)
   - Scope: CLAUDE.md "Task subfolder convention" addition. New helper `dev-workflow/scripts/path_resolve.py`. Update `/thorough_plan` Setup §1, `/plan`, `/critic`, `/revise`, `/revise-fast`, `/review`, `/implement`, `/gate` to use the resolver. Verify `/end_of_task` Step 7 alignment.
   - Exclusions: do NOT migrate existing task folders. Do NOT change cost-ledger location (stays at task root).
   - Prerequisites: none.
   - Complexity: L (CLAUDE.md edit, 8 SKILL.md edits, 1 new script, multi-skill regression test).
   - Key risks: R-03 (orchestrator hardcoded paths), R-09 (accidental migration).
   - Testing strategy: resolver unit tests (single-stage, multi-stage, legacy); end-to-end test invoking /thorough_plan stage-1 of a fixture task.
   - Rollback: revert CLAUDE.md, SKILL.md edits; resolver helper becomes dead code (no harm).

4. ⏳ S-04: Architect critic phase (item #2)
   - Scope: add Phase 4 to `/architect` SKILL.md. Wire `/critic` to accept `--target=architecture.md`. Update format-kit.sections.json if architecture-critic-N.md needs different required sections (already aligned per /architect SKILL.md tier-3 critic section). Add max-rounds parsing.
   - Exclusions: do NOT change /thorough_plan critic loop. Do NOT change Opus-only critic rule.
   - Prerequisites: S-03 (architect critic outputs go into stage subfolder when applicable).
   - Complexity: M (1 large SKILL.md edit, 1 small SKILL.md edit, validator already aligned).
   - Key risks: R-04 (cost runaway), R-10 (recursive self-critique).
   - Testing strategy: invoke /architect on a small fixture task w/ known issues; verify critic spawns, REVISE→re-synthesis, PASS path; cost-guard pre-round-2 notice fires.
   - Rollback: revert Phase 4 from /architect SKILL.md.

5. ⏳ S-05: Native Haiku summarizer (item #6)
   - Scope: new `dev-workflow/memory/summary-prompt.md` (Tier 1). Update Step 2 in 6 Class B writer skills (architect, plan, revise, revise-fast, review, critic if applicable) to spawn Agent w/ model=haiku instead of bash script. Update install.sh to deploy summary-prompt.md and stop deploying summarize_for_human.py + with_env.sh. Delete those two scripts. Add Tier 1 entry to CLAUDE.md.
   - Exclusions: do NOT change the prompt template content (frozen for v3 stage 1 governance reasons). Do NOT change validate_artifact.py V-06 or V-07.
   - Prerequisites: S-01 (validates Agent-tool model dispatch works in this codebase).
   - Complexity: L (1 new memory file, 6 SKILL.md edits, install.sh edit, 2 file deletions, V-06/V-07 regression test).
   - Key risks: R-05 (Agent overhead), R-08 (prompt drift), I-07 (context bleed), I-10 (V invariant break).
   - Testing strategy: generate ≥3 Class B artifacts (architecture.md, current-plan.md, review-1.md), validate_artifact.py PASS on each; token-count smoke vs old-script baseline.
   - Rollback: restore summarize_for_human.py + with_env.sh from git history; revert SKILL.md Step 2 changes; redeploy.

6. ⏳ S-06: Quoin rebrand + QUICKSTART relocation + fancy README (item #7)
   - Scope: rename `dev-workflow/` → `quoin/`. Update 26 files (~103 occurrences) of `dev-workflow` references in CLAUDE.md and skills. Rewrite README.md w/ Quoin branding. Update `/init_workflow` Step 7 to write QUICKSTART.md to `<project>/.workflow_artifacts/QUICKSTART.md`. Add legacy-detection prompt for old `<project>/dev-workflow/QUICKSTART.md`. Update GitHub repo name (manual action, documented in commit msg).
   - Exclusions: do NOT change install.sh's $SCRIPT_DIR-relative logic. Do NOT change `~/.claude/CLAUDE.md` markers. Do NOT touch `.workflow_artifacts/` path conventions.
   - Prerequisites: S-01 through S-05 merged to main (avoid path-conflict churn).
   - Complexity: L (mass rename, README rewrite, init_workflow path update, fresh-clone install test).
   - Key risks: R-06 (user installs), R-07 (install.sh markers), I-08 (residual refs), I-09 (idempotency).
   - Testing strategy: grep sweep for residual `dev-workflow` (must be zero outside CHANGELOG/git history); fresh-clone install on a scratch dir; existing-install upgrade path (run install.sh against seeded ~/.claude/CLAUDE.md, verify section replacement).
   - Rollback: rename `quoin/` → `dev-workflow/`; revert README; revert /init_workflow Step 7.

## Stage Summary Table

| Stage | Description | Complexity | Dependencies | Key Risk |
|-------|-------------|------------|--------------|----------|
| S-01 | Self-dispatch preamble (12 cheap-tier skills) | M | none | R-01 (recursion) |
| S-02 | ccusage fallback (cost_from_jsonl.py) | M | none | R-02 (price drift) |
| S-03 | Stage-subfolder convention | L | none | R-03 (path hardcodes) |
| S-04 | Architect critic Phase 4 | M | S-03 | R-04 (cost runaway) |
| S-05 | Native Haiku summarizer | L | S-01 | R-05/R-08/I-10 |
| S-06 | Quoin rebrand + QUICKSTART relocation + fancy README | L | S-01..S-05 | R-06/R-07/I-08 |

## Next Steps

1. User reviews architecture (gate checkpoint A — post-architect, pre-thorough_plan).
2. User runs `/thorough_plan large: stage-1 of quoin-foundation` to plan S-01.
3. After S-01 implements + reviews + ships, repeat for S-02..S-06 in order.
4. Stages 1-3 are independent and could parallelize on separate branches if desired (different cwd via `EnterWorktree`); S-04 needs S-03; S-05 needs S-01; S-06 needs all of S-01..S-05.

## Open questions

1. Q-01 ✓ RESOLVED 2026-04-25: Include /implement and /end_of_task in stage-1 self-dispatch list. Consistent treatment; `/run` invocations bypass via the [no-redispatch] sentinel.
2. Q-02 ✓ RESOLVED 2026-04-25: `cost_from_jsonl.py` is FALLBACK ONLY in stage 2. Promote to primary in a future task once price-table maintenance is proven.
3. Q-03 ✓ RESOLVED 2026-04-25: Architect critic max-rounds default = 2 (normal mode). Hard cap stays at 2; strict mode allows up to 4 (rare).
4. Q-04 ✓ RESOLVED 2026-04-25: Stage 6 includes CHANGELOG.md (new top-level file). The rename commit is the v1.0 release of Quoin.
