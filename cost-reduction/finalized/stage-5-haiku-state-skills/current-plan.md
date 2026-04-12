# Plan: Stage 5 — Haiku for State-Management Skills

## Convergence Summary
- **Rounds:** 2
- **Final verdict:** PASS
- **Key revisions:** Resolved contradiction between "Stay factual" and "Capture the narrative" in `/weekly_review` (replaced narrative bullet with factual-connection instruction); aligned reconciliation output section name with existing briefing template; softened git-log instruction to not conflict with existing "capture the why" guidance; corrected line number references
- **Remaining concerns:** Two MINOR issues noted in Round 2 — `gh` fallback message and a line-number off-by-one — neither blocking

## Overview

Move four low-risk state-management skills from Sonnet to Haiku: `/start_of_day`, `/end_of_day`, `/capture_insight`, `/weekly_review`. These skills perform structured file I/O (read caches, write markdown, run git commands) with minimal reasoning demands. The primary risk is output quality regression in daily caches and weekly reviews — mitigated by a one-week side-by-side validation before committing the change.

Three Sonnet skills are explicitly NOT moved: `/gate` (safety-critical checks), `/rollback` (safe undo requires careful reasoning), `/end_of_task` (commit/push with lessons learned).

## Scope

**In scope:**
- Change `model:` frontmatter from `sonnet` to `haiku` in 4 SKILL.md files
- Update the model assignments table in `dev-workflow/CLAUDE.md`
- Assess and apply skill content adjustments to compensate for Haiku's reduced capability
- Define the validation strategy for side-by-side comparison

**Out of scope:**
- Changes to `~/.claude/CLAUDE.md` (updated by `install.sh`, per project convention)
- Changes to `/gate`, `/rollback`, `/end_of_task` skill files
- Changes to `install.sh` (it already copies all SKILL.md files and CLAUDE.md generically — no model-specific logic)
- Changes to any planning/implementation skills (`/plan`, `/critic`, `/revise`, `/revise-fast`, `/thorough_plan`, `/implement`, `/review`, `/architect`, `/discover`)

## Design Decisions

### DD1: install.sh requires no changes

`install.sh` copies all `skills/*/SKILL.md` files and the full `dev-workflow/CLAUDE.md` to `~/.claude/`. It has no model-specific logic — the `model:` field is in the SKILL.md frontmatter and is read by the Claude Code runtime, not by install.sh. Changing the frontmatter values is sufficient; install.sh propagates them on next run.

### DD2: Skill content adjustments for Haiku

Haiku is less capable than Sonnet at multi-step reasoning, nuanced judgment, and generating long structured output. After reading all four skill files:

- **`/capture_insight`** — Already minimal (classify type, write one entry, one-line confirmation). No adjustments needed. This is the lowest-risk skill of the four.

- **`/start_of_day`** — The reconciliation step (Step 4) requires comparing cached state vs actual git state and identifying drift. This is the most reasoning-heavy step. Adding explicit enumeration of what to check and a structured output template for each check will help Haiku produce consistent results.

- **`/end_of_day`** — The insight promotion flow (Step 3b) requires deduplication against lessons-learned.md and judgment about what to promote. The pruning logic (Step 3c) is also judgment-heavy. These steps benefit from more explicit decision criteria to reduce ambiguity for Haiku.

- **`/weekly_review`** — Generating a narrative weekly review from multiple sources requires synthesis. The current instructions already provide a detailed template. The main risk is the "Highlights" section (which asks for outcome-oriented bullets) and the prose in "Next Week." Adding a stricter template and explicit instructions to stay factual rather than narrative will help.

### DD3: Validation approach

The architecture calls for "one-week side-by-side validation." Rather than running both models simultaneously (expensive and complex), we use a sequential approach: run with Haiku for one week, then compare the outputs against the existing Sonnet-produced artifacts in `memory/daily/` and `memory/weekly/` from prior weeks. The user assesses whether the Haiku outputs are acceptably close in quality.

## Tasks

### Task 1: Adjust `/capture_insight` skill content and change model to Haiku ✅ completed

**Files:** `dev-workflow/skills/capture_insight/SKILL.md`

**Changes:**

1. Change frontmatter `model: sonnet` to `model: haiku` (line 4)
2. No content adjustments needed — this skill is already minimal and structured:
   - Determine insight from user input
   - Pick a type from a fixed list
   - Set Promote? from a fixed list
   - Append a templated markdown entry
   - One-line confirmation

**Risk:** Very low. The skill is essentially template fill-in with a simple classification. Haiku handles this well.

### Task 2: Adjust `/start_of_day` skill content and change model to Haiku ✅ completed

**Files:** `dev-workflow/skills/start_of_day/SKILL.md`

**Changes:**

1. Change frontmatter `model: sonnet` to `model: haiku` (line 4)

2. In Step 4 (Reconcile), replace the current loose description with an explicit checklist. The current text (lines 47-53) says:

```
Compare what the daily cache says should be happening with what git actually shows. Look for:

- **Drift** — did someone else push commits to a branch you're working on?
- **Uncommitted work** — files changed but not committed (maybe the user started something after `/end_of_day`)
- **Branch state** — are you on the right branch for the unfinished task?
- **Stale PRs** — any open PRs that might have reviews or CI results overnight?
```

Replace with a more structured version that tells Haiku exactly what to do for each check:

```
For each unfinished task from the daily cache, run these checks and report the result:

1. **Branch match** — Is the repo on the branch the daily cache says? If not, report the actual branch.
2. **New remote commits** — Run `git log HEAD..origin/<branch> --oneline`. If output is non-empty, report "N new commits from remote."
3. **Uncommitted local changes** — Check `git status --short`. If non-empty, list the changed files.
4. **Stale PRs** — If `gh` is available, run `gh pr list --head <branch> --json number,title,reviewDecision,statusCheckRollup --limit 5`. Report any PRs with new reviews or failed checks.

Report each check result in the briefing's "## Since last session" section (matching the existing Step 5 template). If everything matches the daily cache, say "Git state matches cached state — no drift detected."
```

3. In Step 5 (Present the briefing), add a note after the template (after line 83):

```
Keep the briefing factual. Report what you found in each step — do not speculate about what the user might want to do beyond what the daily cache and git state suggest. Let the user decide priorities.
```

**Risk:** Low-medium. The reconciliation step is the most reasoning-intensive part. The structured checklist reduces the chance of Haiku missing a check. If Haiku struggles with the git command output parsing, this will be visible in the first usage.

### Task 3: Adjust `/end_of_day` skill content and change model to Haiku ✅ completed

**Files:** `dev-workflow/skills/end_of_day/SKILL.md`

**Changes:**

1. Change frontmatter `model: sonnet` to `model: haiku` (line 4)

2. In Step 3b (Review and promote daily insights), the deduplication pass (Pass 2) currently says (around line 163):

```
**Pass 2 — Deduplicate:**
- Read `memory/lessons-learned.md`
- If a collected entry is substantially similar to an existing lesson, drop it or flag it as a duplicate
```

Add explicit dedup criteria below the existing bullets:

```
An entry is a duplicate if it describes the same root cause AND the same takeaway as an existing lesson. Entries about the same topic but with different lessons are NOT duplicates — keep both and note the connection.
```

3. In Step 3c (Prune lessons-learned if oversized), no changes needed — the auto-prune rules are already highly structured with explicit criteria. Haiku can follow numbered rules.

4. In Step 2 (Update git-log.md), add after the "Then for each commit" instruction (after line 108):

```
Keep commit descriptions to one sentence. Base them on the commit message and diff summary — do not speculate about intent beyond what the message states.
```

**Risk:** Low. The skill is heavily template-driven. The insight promotion flow asks the user to confirm before writing, so any Haiku misjudgment in the dedup pass is caught by the user.

### Task 4: Adjust `/weekly_review` skill content and change model to Haiku ✅ completed

**Files:** `dev-workflow/skills/weekly_review/SKILL.md`

**Changes:**

1. Change frontmatter `model: sonnet` to `model: haiku` (line 4)

2. In Step 3 (Build the review), add guidance for the Highlights section. After the template's `<3-5 bullet points: the most important things that happened this week. Lead with outcomes, not activity.>` (line 50), add a note outside the template block:

```
For the Highlights section: each bullet should state a concrete outcome or deliverable, not a process step. Use this pattern: "<What was delivered/decided> — <why it matters or what it unblocks>". If a task is still in progress, it is not a highlight unless it hit a significant milestone.
```

3. In the "Next Week" section of the template (line 97), replace:

```
<Based on in-progress work, blockers, and momentum — what should be the priorities?>
```

with:

```
<List the in-progress tasks that should continue, any blockers to resolve, and any new work the user mentioned. Do not speculate about priorities beyond what the data shows.>
```

4. In "Important behaviors" (line 145), replace the existing "Capture the narrative" bullet:

```
- **Capture the narrative.** The weekly review tells the story of the week. Connect the dots between tasks — "Started the week debugging auth timeouts, which led to discovering the retry logic gap, which became the main task."
```

with:

```
- **Connect related work factually.** If tasks are related, note the observable connection (e.g., "Task B was created as a follow-up to Task A"). Do not infer intent, mood, or momentum. When data is sparse, keep the review short rather than padding with interpretation.
```

**Rationale:** The original "Capture the narrative" instruction asks for inference and synthesis ("tells the story," "connect the dots"), which directly contradicts a "Stay factual" instruction. On Haiku, contradictory instructions cause inconsistent output. By replacing the narrative bullet entirely with a factual-connection instruction, we remove the contradiction while preserving the useful behavior (noting when tasks relate to each other).

**Risk:** Low-medium. Weekly reviews involve synthesis across multiple data sources. The risk is that Haiku produces a more mechanical, less insightful review. The added guidance steers it toward factual reporting, which is the acceptable minimum. If the user wants richer narrative, they can override with `model: sonnet` or run the review manually.

### Task 5: Update model assignments table in `dev-workflow/CLAUDE.md` ✅ completed

**Files:** `dev-workflow/CLAUDE.md`

**Changes:**

In the "Model assignments" table (lines 323-342), update these four rows:

| Old | New |
|-----|-----|
| `\| /end_of_day \| Sonnet \| Session state capture and daily cache consolidation \|` | `\| /end_of_day \| Haiku \| Session state capture and daily cache consolidation (structured template work) \|` |
| `\| /start_of_day \| Sonnet \| Context restoration and git state reconciliation \|` | `\| /start_of_day \| Haiku \| Context restoration and git state reconciliation (structured checklist) \|` |
| `\| /weekly_review \| Sonnet \| Aggregates weekly progress, decisions, and outcomes \|` | `\| /weekly_review \| Haiku \| Aggregates weekly progress, decisions, and outcomes (template-driven) \|` |
| `\| /capture_insight \| Sonnet \| Quick insight logging to daily scratchpad during task work \|` | `\| /capture_insight \| Haiku \| Quick insight logging to daily scratchpad during task work \|` |

The Reasoning column gets a brief parenthetical explaining why Haiku is sufficient, except for `/capture_insight` which is already self-evidently simple.

**Note on propagation:** The `~/.claude/CLAUDE.md` model assignments table lives inside the `# === DEV WORKFLOW START ===` to `# === DEV WORKFLOW END ===` markers and is replaced wholesale by `install.sh` from `dev-workflow/CLAUDE.md` -- no separate manual update to `~/.claude/CLAUDE.md` is needed.

**Risk:** None. This is documentation. It gets propagated to `~/.claude/CLAUDE.md` by `install.sh` on next run.

### Task 6: Run `install.sh` to propagate changes ✅ completed

**Files:** `dev-workflow/install.sh` (run, not modified)

**Changes:**

Run `bash dev-workflow/install.sh` to copy the updated SKILL.md files and CLAUDE.md to `~/.claude/`. Verify the installation succeeded by spot-checking:
- `~/.claude/skills/start_of_day/SKILL.md` has `model: haiku`
- `~/.claude/skills/capture_insight/SKILL.md` has `model: haiku`
- `~/.claude/CLAUDE.md` model assignments table shows Haiku for the four skills

**Risk:** None. install.sh is idempotent and well-tested from previous stages.

## Integration Analysis

### Integration points affected

This change affects only the `model:` frontmatter and instruction text within four skill files. The integration points are:

1. **SKILL.md `model:` field → Claude Code runtime** — The runtime reads this field to select which model to invoke. Changing `sonnet` to `haiku` is a supported value. No API contract changes.

2. **SKILL.md instructions → model behavior** — Haiku follows instructions but with less nuance than Sonnet. The skill content adjustments (Tasks 2-4) compensate by making instructions more explicit and structured.

3. **install.sh → `~/.claude/`** — install.sh copies files verbatim. No logic depends on model values.

4. **Skill outputs → `memory/` files** — The four skills write to `memory/daily/`, `memory/sessions/`, `memory/weekly/`, and `memory/git-log.md`. These files are consumed by `/start_of_day`, `/end_of_day`, `/weekly_review` (self-referential loop), and by planning skills that read lessons-learned.md. Lower quality outputs here propagate into future sessions.

### Failure modes

| Failure | Likelihood | Impact | Detection |
|---------|-----------|--------|-----------|
| Haiku produces poorly structured daily cache | Low | Medium — `/start_of_day` may misparse or miss context | User notices during morning briefing within 1 day |
| Haiku misclassifies insight type or Promote? tag | Very low | Low — user reviews at end of day | Visible during `/end_of_day` promotion flow |
| Haiku produces shallow weekly review | Medium | Low — user supplements with their own knowledge | User reads the review and notices missing depth |
| Haiku misses git drift in start_of_day reconciliation | Low | Medium — user works on stale code | Explicit git command checklist reduces this significantly |
| Haiku fails to follow the dedup logic for insight promotion | Low | Low — worst case is a duplicate lesson in lessons-learned.md | User confirms promotions before they are written |

### Backward compatibility

Fully backward compatible. The `model:` field change requires no coordinated deployment. Skills can be individually reverted to `sonnet` at any time by changing the frontmatter value and re-running install.sh.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| R6 (from architecture): Haiku produces lower-quality daily caches leading to context loss | Low | Medium | Skill content adjustments make instructions more explicit; one-week validation period; immediate rollback available |
| Haiku struggles with multi-source synthesis in `/weekly_review` | Medium | Low | Added "stay factual" guidance; weekly review is read by user immediately — quality issues are caught in real time |
| Haiku misinterprets git command output in `/start_of_day` | Low | Medium | Replaced open-ended reconciliation with explicit command-by-command checklist with expected output handling |
| Content adjustments inadvertently change Sonnet behavior if rolled back | Very low | Very low | Adjustments add specificity without removing capability — they are neutral-to-positive for Sonnet too |

## Rollback Plan

**Per-skill rollback (if one skill underperforms):**

1. Open the specific `dev-workflow/skills/<skill>/SKILL.md`
2. Change `model: haiku` back to `model: sonnet`
3. Update the corresponding row in `dev-workflow/CLAUDE.md` model assignments table
4. Run `bash dev-workflow/install.sh`
5. The content adjustments made in Tasks 2-4 can remain — they are improvements regardless of model

**Full Stage 5 rollback:**

1. `git revert <stage-5-commit>` to undo all changes
2. Run `bash dev-workflow/install.sh` to propagate
3. All four skills return to Sonnet

**Decision point:** If 2 or more of the 4 skills show quality issues during validation, revert the entire stage rather than trying to fix individual skills. The absolute cost savings of Stage 5 are small (Sonnet state skills are already cheap), so the bar for quality is "no noticeable regression."

## Validation Strategy

### Pre-deployment: Content review

Before changing any `model:` values, review the skill content adjustments (Tasks 2-4) to confirm they do not remove any capability, only add structure.

### Week 1: Haiku validation period

After deploying all changes (Tasks 1-6):

1. **Use all four skills normally for one week** — run `/start_of_day` each morning, `/end_of_day` each evening, `/capture_insight` ad hoc, `/weekly_review` at end of week.

2. **Compare outputs against prior Sonnet artifacts** — the `memory/daily/` and `memory/weekly/` directories already contain Sonnet-produced files from previous weeks. Compare:
   - **Completeness:** Does the Haiku daily cache capture all the same sections? Any missing information?
   - **Accuracy:** Does `/start_of_day` correctly identify git drift and uncommitted changes?
   - **Structure:** Are the markdown files well-formed and following the templates?
   - **Insight quality:** Are `/capture_insight` entries properly classified and formatted?

3. **Track issues** — if any skill produces noticeably lower-quality output, note it in `memory/daily/insights-<date>.md` with `Applies to: workflow` and `Promote?: yes`.

4. **End-of-week decision:**
   - **No issues found** → Stage 5 is complete. Proceed to `/end_of_task`.
   - **Minor issues in 1 skill** → Adjust that skill's instructions and continue for another week.
   - **Significant issues in 2+ skills** → Roll back the entire stage per the rollback plan.

### Success criteria

- Daily caches contain all sections from the template with no missing data
- `/start_of_day` correctly identifies at least: branch state, uncommitted changes, and remote drift
- `/capture_insight` correctly classifies insight type and sets Promote? tag
- `/weekly_review` covers all data sources and produces a scannable report
- No context loss incidents (user confused about what they were working on because of poor cache quality)

## Task Dependency Order

```
Task 1 (/capture_insight)  ─┐
Task 2 (/start_of_day)     ─┤
Task 3 (/end_of_day)        ├─→ Task 5 (CLAUDE.md table) ──→ Task 6 (install.sh)
Task 4 (/weekly_review)    ─┘
```

Tasks 1-4 are independent and can be implemented in any order or in parallel. Task 5 depends on Tasks 1-4 being complete (to know the final model values). Task 6 depends on Task 5.

## Revision Log

### Round 1 (from critic-response-1.md)

**MAJOR -- "Stay factual" contradicts "Capture the narrative" in `/weekly_review` (Task 4)**
- **Verified:** Line 145 of `weekly_review/SKILL.md` has "Capture the narrative. The weekly review tells the story of the week. Connect the dots between tasks..." which directly contradicts the proposed "Stay factual. Do not infer intent, mood, or momentum."
- **Fix:** Changed Task 4 change #4 from *adding* a "Stay factual" bullet to *replacing* the "Capture the narrative" bullet with a new "Connect related work factually" bullet. This removes the contradiction while preserving the useful behavior (noting when tasks relate to each other). The new instruction explicitly says to note observable connections without inferring intent or momentum.

**MINOR -- Line number off-by-one in Task 4 "Next Week" section**
- **Verified:** The text `<Based on in-progress work, blockers, and momentum...>` is at line 97, not 98.
- **Fix:** Changed "line 98" to "line 97" in Task 4 change #3.

**MINOR -- install.sh propagation mechanism not explained in Task 5**
- **Fix:** Added a "Note on propagation" sentence to Task 5 explaining that `install.sh` replaces the full `# === DEV WORKFLOW START/END ===` block in `~/.claude/CLAUDE.md`, so no separate manual update is needed.

**MINOR -- "## Git State" conflicts with "## Since last session" template section in `/start_of_day` (Task 2)**
- **Verified:** Line 61 of `start_of_day/SKILL.md` uses `## Since last session` in the briefing template. The plan's new Step 4 replacement instructed reporting under `## Git State`, which would create conflicting/overlapping sections.
- **Fix:** Changed the Step 4 replacement to report in the `## Since last session` section instead of a new `## Git State` section, matching the existing template.

**MINOR -- `end_of_day` Step 2 "capture the why" vs "do not interpret" (Task 3)**
- **Verified:** Line 109 of `end_of_day/SKILL.md` says "capture the *logic* of recent changes -- not just file lists but *why* things changed." The plan originally added "Do not analyze or interpret the changes beyond what the diff summary shows," which partially contradicts the existing instruction.
- **Fix:** Softened the addition to "Base them on the commit message and diff summary -- do not speculate about intent beyond what the message states." This is compatible with the existing "capture the why" instruction: the commit message itself states the why; Haiku should use it rather than inventing its own interpretation.
