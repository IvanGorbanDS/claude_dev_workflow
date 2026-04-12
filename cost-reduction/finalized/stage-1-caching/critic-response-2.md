# Critic Response -- Round 2

**Date:** 2026-04-12
**Plan reviewed:** cost-reduction/stage-1-caching/current-plan.md (Round 2 revision)
**Verdict:** PASS

## Round 1 issue verification

- [MAJ-1] **Fixed.** All line-number references removed from Task 6. All target locations identified by section heading names. Explicit note added at line 377: "All changes below identify target locations by section heading names, not line numbers."
- [MAJ-2] **Fixed.** "Phase 1b: Research and explore" eliminated entirely. Web research folded into Phase 2 (Synthesize) as a dedicated paragraph. Phase structure is now clean: Phase 1 (Scan/Sonnet) -> Phase 2 (Synthesize/Opus, including web research) -> Phase 3 (Decompose). No ambiguous sub-phases.
- [MIN-1] **Fixed.** Task 4 (C5) now inserts the incremental scan section immediately after the `## What to scan` heading, before the introductory paragraph. The intro paragraph no longer has its trailing colon disconnected from `### Per-repo inventory`.
- [MIN-2] **Fixed.** Task 1 step 1 now specifies saving raw output to `cost-reduction/stage-1-caching/instrumented-thorough-plan.json`. Added to acceptance criteria.
- [MIN-3] **Fixed.** Task 5 (C6) now specifies regex `^## \d{4}-\d{2}-\d{2}` and explicitly excludes matches inside HTML comments, code blocks, or template examples. Test 4 added to verify.
- [MIN-4] **Fixed.** Scan agent instructions now include "Keep your total output under ~3,000-5,000 tokens." Risk S1-R7 added. Test 2 and acceptance criteria updated.
- [MIN-5] **Fixed.** Cost discipline first bullet reworded from "during Phase 1" to "for bulk exploration." Exception clause references Phase 2 specifically.
- [MIN-6] **Fixed.** Implementation note added to Task 3 (C4) about em dash character encoding, instructing implementer to copy "before" text from the actual file.

**All eight Round 1 issues are fully addressed.**

## Summary

The revised plan is thorough, accurate, and ready for implementation. All Round 1 issues were addressed cleanly without introducing new problems. I verified every "before" text block against the actual SKILL.md files -- all match (with the known em dash caveat already documented in the plan). The six tasks remain coherent and independent within their documented interaction boundaries. The 1a/1b split is well-justified. No CRITICAL or MAJOR issues remain.

## CRITICAL issues

None.

## MAJOR issues

None.

## MINOR issues

### [MIN-1] Task 3 (C4): Line-number reference for "Step 1: Gather context" is slightly off

**Location:** Task 3, first change block -- "In 'Step 1: Gather context' (lines 29-34)"

**Issue:** The plan says "lines 29-34" but the actual `### Step 1: Gather context` heading is at line 27 (not 29), and the content spans lines 29-33 (5 items, not extending to line 34). The plan's "before" block includes the heading, but the stated line range starts at 29, which skips the heading. This is a cosmetic discrepancy -- the heading name is the primary locator and is correct, and the quoted text in the "before" block is character-accurate. No implementer would be confused since the heading name unambiguously identifies the section.

**Recommendation:** No action needed. The heading name is the reliable locator. If desired for consistency with Task 6 (which removed all line numbers), the line-number reference could be removed here too, but this is not blocking.

### [MIN-2] Task 4 (C5): Structural oddity after insertion -- body text between subsections

**Location:** Task 4, resulting file structure after Change 1

**Issue:** After inserting `### Incremental scan -- skip unchanged repos` immediately after `## What to scan`, the paragraph "Starting from the project root folder, examine every top-level directory. For each repository/service found:" becomes a body-text paragraph sitting between two level-3 subsections (`### Incremental scan` and `### Per-repo inventory`). In standard markdown document structure, body text at the level-2 scope should precede all level-3 subsections, not be interspersed between them. The resulting structure:

```markdown
## What to scan

### Incremental scan -- skip unchanged repos
[content]

Starting from the project root folder, examine every top-level directory. For each repository/service found:

### Per-repo inventory
```

This reads intelligibly (check incremental scan first, then for repos needing scanning, follow the instructions into Per-repo inventory), but the structural hierarchy is slightly nonstandard. An LLM following these instructions would not be confused -- the meaning is clear from context.

**Recommendation:** If desired, the intro paragraph could be moved above the `### Incremental scan` subsection (between `## What to scan` and `### Incremental scan`), which would be more structurally standard:

```markdown
## What to scan

Starting from the project root folder, examine every top-level directory. For each repository/service found:

### Incremental scan -- skip unchanged repos
[content -- check which repos to scan]

### Per-repo inventory
[content -- how to scan each repo]
```

But this is a style preference, not a correctness issue. The plan's current approach is functional.

## What the plan gets right

- **All Round 1 issues addressed completely.** Every MAJ and MIN issue from Round 1 has a clear, correct fix. The revision history section at the end of the plan documents each fix explicitly, making it easy to audit.

- **All "before" text blocks are character-accurate against the actual SKILL.md files.** I verified every quoted block against the source files. The text content matches. The em dash encoding caveat is documented with a clear implementation note.

- **The Phase 1/Phase 2/Phase 3 structure for Task 6 is clean.** Merging web research into Phase 2 (Synthesize) is the best of the three options the Round 1 critic suggested. Web research is naturally interleaved with synthesis reasoning, and having it in the Opus session makes sense because it benefits from the strongest model's judgment.

- **The scan agent instructions are complete and well-constrained.** The structured output template (5 numbered sections), the output size constraint (~3K-5K tokens), the per-repo scoping, the minimum content threshold, and the small-repo batching rule together form a coherent scan agent design.

- **The integration analysis is thorough and identifies the real interactions.** The C5/C7 positive interaction (repo-heads cache reuse) is correctly specified in both Task 4 and Task 6. The C3/C6 complementary relationship is correctly explained.

- **The cost/benefit estimates are appropriately caveated.** The plan explicitly states that estimates use illustrative token counts from the architecture document and that Task 1 will produce real numbers. No over-promising.

- **The testing strategy covers normal, edge, and override cases for each task.** Task 5 testing includes the HTML-comment false-positive case. Task 4 includes force-rescan. Task 6 includes quality comparison against the old approach.

- **The 1a/1b split remains well-justified.** Five independent low-risk text edits (1a) versus one significant architectural rewrite (1b). They can be implemented and shipped independently.

- **The revision history section is a model of transparency.** Documenting exactly what changed and why makes the plan auditable across revision rounds.
