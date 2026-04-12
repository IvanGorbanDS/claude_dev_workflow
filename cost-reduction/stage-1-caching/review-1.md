# Code Review — Stage 1a Caching Hygiene (Tasks 1-5)

## Summary

Five independent tasks implemented as markdown edits to four SKILL.md files plus one new documentation file. All changes match the plan's spec precisely — "before" blocks were correctly replaced, "after" blocks match exactly, insertion points are correct, and acceptance criteria are met. One minor issue found (structural markdown ordering in discover/SKILL.md, already flagged by the Round 2 critic as MIN-2). No correctness, security, or integration concerns.

## Verdict: APPROVED

## Plan Compliance

### Task 1: C1 — Caching audit ✅

| Acceptance criterion | Status | Evidence |
|---------------------|--------|----------|
| `caching-audit.md` exists with real data | ✅ | 169 lines, all data from actual JSONL analysis |
| Cache-hit rates per call documented | ✅ | Per-phase breakdown table (83–95% by phase) |
| Stable prefix components with token counts | ✅ | Table with ~13,500 shared, ~5,200–5,800 unique |
| Raw session JSON preserved | ✅ | Copied to `stage-1-caching/instrumented-thorough-plan.json` |
| Prompt-ordering changes identified | ✅ | Section "Recommendations for SKILL.md prompt structuring" with 3 recommendations and 3 non-recommendations |

**Deviation from plan:** The plan expected a new instrumented run, but existing Stage 0 data was used instead. This is justified — the data is from the same `/thorough_plan` run type and contains all the fields the plan requires. The audit also corrected a Stage 0 finding: subagents use **5-minute TTL** (not 1-hour). This correction adds significant value — it changes the economics of cross-phase cache reuse.

### Task 2: C3 — Critic skip lessons-learned ✅

| Acceptance criterion | Status | Evidence |
|---------------------|--------|----------|
| Round-detection logic present | ✅ | "if `critic-response-1.md` already exists, this is round 2 or later" in both Session bootstrap and Section 1.5 |
| Round 1 behavior unchanged | ✅ | "**Round 1 only:** Read `memory/lessons-learned.md`..." — still reads on round 1 |
| Round 2+ skips lessons-learned | ✅ | "**On rounds 2+, skip this step**" in bootstrap; "**Skip this step on rounds 2+**" in Section 1.5 |
| Framed as correctness, not cost | ✅ | "the file cannot change mid-loop, so re-reading it wastes tokens without adding information" — correctness framing |

**Text match:** The "after" block in the plan matches the actual file content character-for-character. Both the Session bootstrap (line 14) and Section 1.5 (lines 33-37) are correctly updated.

### Task 3: C4 — Diff-only review ✅

| Acceptance criterion | Status | Evidence |
|---------------------|--------|----------|
| Diff-first instruction | ✅ | Step 4: "Read every line carefully" |
| Full-file triggered by specific criteria | ✅ | 5 bullet criteria (structural, security, integration, complex partial, critic-flagged) |
| "When in doubt" safety valve | ✅ | "When in doubt, read the full file — the cost of missing a bug far exceeds..." |
| Important behaviors updated | ✅ | Line 192: "Read the diff thoroughly; read full files selectively." replaces old "Read everything." |

**Text match:** Both changes match the plan's "after" blocks exactly.

### Task 4: C5 — Discover HEAD cache ✅

| Acceptance criterion | Status | Evidence |
|---------------------|--------|----------|
| Check `repo-heads.md` before scanning | ✅ | Step 1: "Read `memory/repo-heads.md` if it exists" |
| Unchanged repos skipped with message | ✅ | Step 3: 'Report to the user: "Skipping <repo-name>..."' |
| `repo-heads.md` format specified | ✅ | Markdown table format with Repo/HEAD columns |
| Force re-scan instruction | ✅ | "When the user explicitly requests a full re-scan... ignore the HEAD cache" |
| After-scan report includes skip info | ✅ | Line 249: "Which repos were skipped (unchanged since last scan) and which were re-scanned" |
| Section before per-repo instructions | ✅ | Inserted between `## What to scan` and `### Per-repo inventory` |

**Text match:** All three changes (new section, "When to re-run" bullet, "After scanning" bullet) match the plan's spec.

### Task 5: C6 — Lessons-learned pruning ✅

| Acceptance criterion | Status | Evidence |
|---------------------|--------|----------|
| Step between 3b and 4 | ✅ | Lines 203-223, between Step 3b (ends line 201) and Step 4 (line 225) |
| Threshold: 30 entries | ✅ | "If the count exceeds 30 entries" |
| Three pruning options | ✅ | Auto-prune, Manual prune, Skip |
| Auto-prune rules explicit | ✅ | 5 numbered rules: merge by tag, remove stale, remove dead refs, preserve recent/important, show before/after |
| User confirmation required | ✅ | Rule 5: "wait for explicit confirmation before overwriting" |
| Silent skip below threshold | ✅ | "If the count is 30 or fewer, skip this step silently" |
| Regex with exclusions | ✅ | `^## \d{4}-\d{2}-\d{2}` with "Ignore any such patterns inside HTML comments, code blocks, or template examples" |

**Text match:** The inserted block matches the plan's spec exactly.

## Issues Found

### Critical (blocks merge)

None.

### Major (should fix before merge)

None.

### Minor (nice to have)

- **[MIN-1] Discover SKILL.md: structural markdown ordering after C5 insertion**
  - Location: `dev-workflow/skills/discover/SKILL.md:36`
  - Description: After the `### Incremental scan` subsection, there's a body-text paragraph ("Starting from the project root folder...") sitting between two `###`-level subsections. In standard markdown hierarchy, body text at the `##` scope should precede all `###` subsections.
  - Impact: None functional. An LLM reading these instructions will understand the flow correctly — the meaning is clear from context. This was already flagged as MIN-2 in the Round 2 critic response.
  - Suggestion: Could move the paragraph above `### Incremental scan` if desired, but not required.

## Integration Safety

These changes affect how four skills (`/critic`, `/review`, `/discover`, `/end_of_day`) behave when invoked. Integration considerations:

1. **`/critic` (C3):** The round-detection logic depends on `critic-response-*.md` file existence. This is reliable — `/thorough_plan` always saves critic responses to numbered files. Risk: if a user manually creates a `critic-response-1.md` file, a fresh `/critic` invocation would think it's round 2+. This is an edge case and consistent with how the system works (file artifacts are the source of truth).

2. **`/review` (C4):** The selective read behavior is opt-in — the "when in doubt, read the full file" instruction preserves the safety floor. No integration risk.

3. **`/discover` (C5):** The `repo-heads.md` file is a new artifact in `memory/`. No other skill reads this file, so there's no backward compatibility concern. If `repo-heads.md` doesn't exist, `/discover` does a full scan — graceful degradation.

4. **`/end_of_day` (C6):** The pruning step only activates when `lessons-learned.md` has >30 entries AND the user selects an option. All three code paths (auto, manual, skip) require user input. No silent data loss is possible.

5. **Cross-skill:** `/critic` (C3) and `/end_of_day` (C6) both touch `lessons-learned.md` but in non-conflicting ways — C3 controls when it's *read*, C6 controls when it's *pruned*. No interaction risk.

6. **Installed vs source parity:** All 4 installed SKILL.md files (`~/.claude/skills/`) are byte-identical to their `dev-workflow/skills/` counterparts.

## Test Coverage

These are markdown instruction files — there is no automated test suite. The plan specifies manual behavioral tests for each task (18 total tests across 5 tasks). These tests cannot be run in this review session because they require:
- Running full `/thorough_plan` loops (Tasks 2, 3)
- Running `/discover` against a multi-repo project (Task 4)
- Running `/end_of_day` with crafted `lessons-learned.md` files (Task 5)
- Running instrumented sessions (Task 1 — already done)

The plan's testing strategy is sound but execution is deferred to real-world usage. Given that all changes are markdown instructions (not executable code), the primary verification is text accuracy — which this review confirms.

## Risk Assessment

- **What could break:** An LLM misinterprets the new instructions and skips a step it shouldn't (e.g., reviewer doesn't read a full file when it should). Mitigated by the "when in doubt" safety valves in C4.
- **Blast radius:** Individual skill invocations only. No shared state is modified (except the new `repo-heads.md`, which degrades gracefully).
- **Detection:** If a `/review` misses a bug due to not reading a full file, it would surface in testing or production. If `/discover` skips a repo incorrectly, the user would notice stale inventory data.
- **Rollback:** Revert the 4 SKILL.md files and delete `caching-audit.md`. Clean, no irreversible changes.
- **De-risking:** All changes are independently revertible. No coordinated rollback needed.

## Recommendations

1. Merge Stage 1a as-is. All changes are clean, match the plan, and carry low risk.
2. Run `/end_of_task` to finalize, push the branch, and capture lessons learned.
3. Stage 1b (C7 architect split) should proceed on its own branch as planned.
4. Consider updating `cost-reduction/baseline.md` with the corrected TTL finding from the caching audit (subagents use 5m, not 1h) — this affects Stage 3 projections.
