# Critic Response -- Round 1

**Date:** 2026-04-12
**Plan reviewed:** cost-reduction/stage-1-caching/current-plan.md
**Verdict:** REVISE

## Summary

The plan is well-structured, thorough, and demonstrates strong understanding of the architecture document's intent. The 1a/1b split is well-justified. However, there are two MAJOR issues that should be addressed before implementation: (1) Task 6 (C7) provides incorrect line numbers throughout, which will cause confusion during implementation, and (2) Task 6's Phase renumbering creates an awkward "Phase 1, Phase 1b, Phase 2, Phase 3" sequence where "Phase 1b" runs in the main Opus session rather than as a subagent, creating a misleading naming structure for an LLM reading the instructions. Tasks 1-5 are solid with only minor issues. No CRITICAL issues -- the plan's proposed changes are directionally correct and consistent with the architecture document.

## CRITICAL issues

None.

## MAJOR issues

### [MAJ-1] Task 6: All line-number references are incorrect by 1-2 lines and will cause implementation errors

**Location:** Task 6 (C7), Changes 1-5

**Issue:** The plan provides line numbers for every change in Task 6, and nearly all are off by 1-2 lines relative to the actual file. An implementer relying on line numbers will make mistakes on the first attempt at every change.

Specific discrepancies in `dev-workflow/skills/architect/SKILL.md`:

| Plan claims | Actual line | Content |
|-------------|-------------|---------|
| Line 3 (description) | Line 3 | Correct -- this one matches |
| Lines 29-44 (Phase 1) | Lines 27-44 | Phase 1 heading is at line 27, not 29 |
| Lines 46-54 (Phase 2) | Lines 46-53 | Phase 2 ends at line 53 (last bullet), line 54 is blank |
| Line 56 (Phase 3) | Line 55 | Phase 3 heading is at line 55, not 56 |

The plan also says "Add a new section after '## Important behaviors' at the end of the file" (Change 6) but "## Important behaviors" is at line 143, not "at the end of the file." However, since the plan identifies the section by name rather than line number, this is workable.

**Evidence:** Actual file structure:
```
Line 27: ### Phase 1: Understand the landscape
Line 46: ### Phase 2: Research and explore
Line 55: ### Phase 3: Architectural design
Line 91: ### Phase 4: Decomposition into stages
Line 110: ### Output format
Line 132: ## Save session state
Line 143: ## Important behaviors
```

**Recommendation:** Either (a) remove all line-number references from Task 6 and identify sections purely by their heading names, which the plan already does as primary identifiers and which are more robust against future edits, or (b) correct every line number to match the actual file. Option (a) is preferred since the heading-name references are already present and sufficient.

### [MAJ-2] Task 6: "Phase 1b" naming creates a misleading structure for the LLM reading the skill

**Location:** Task 6 (C7), Change 3 -- replacement of Phase 2 with "Phase 1b"

**Issue:** The plan proposes this phase structure after all changes:

1. `### Phase 1: Scan -- parallel repo exploration (Sonnet subagents)` -- Sonnet subagents do the reading
2. `### Phase 1b: Research and explore (in the main Opus session)` -- Opus main session does web research
3. `### Phase 2: Synthesize -- architectural design (Opus)` -- Opus main session does synthesis
4. `### Phase 3: Decomposition into stages` -- Opus main session decomposes

Phase 1b is labeled as part of Phase 1 but is fundamentally different: Phase 1 runs on Sonnet subagents in parallel, while Phase 1b runs in the main Opus session. An LLM reading these instructions might: (a) try to include web research in the Sonnet subagent instructions because it is labeled "Phase 1b", or (b) attempt to run Phase 1b before the scan agents complete because both are "Phase 1", when in reality Phase 1b can happen either during or after Phase 1.

The web research step also does not have a natural sequencing dependency on Phase 1 -- it could happen in parallel with the scan agents, or before them, or after. Labeling it "1b" implies it happens after "1" but before "2", which may be correct but is not inherently required.

**Evidence:** The plan's own description of Phase 1b says "This step happens in the main Opus session (not in subagents)," which contradicts the "Phase 1" label. Phase 1's entire identity is about subagent delegation.

**Recommendation:** Rename "Phase 1b" to one of:
- `### Phase 1.5: Research and explore (main Opus session)` -- clearer that it is a distinct step
- `### Research phase (main Opus session)` -- drops the numbering entirely since it is optional and not always needed
- Move the web research instructions into the Phase 2 (Synthesize) preamble, since web research is contextual input for synthesis and often happens interleaved with synthesis reasoning anyway

The third option is cleanest: the synthesizer (Opus) doing web research as needed during synthesis is a natural pattern and avoids the awkward phase naming entirely. The current Phase 2 preamble already says "You now have structured scan findings from every relevant repo (Phase 1) and any external research" -- just make the external research something the synthesizer does on demand rather than a separate phase.

## MINOR issues

### [MIN-1] Task 4 (C5): Insertion point splits the "What to scan" intro text from its first subsection

**Location:** Task 4, Change 1 -- "Add a new section after '## What to scan' (after line 17) and before '### Per-repo inventory'"

**Issue:** In the actual file, line 17 reads: "Starting from the project root folder, examine every top-level directory. For each repository/service found:" -- this sentence leads directly into "### Per-repo inventory" at line 19. Inserting "### Incremental scan -- skip unchanged repos" between them creates an awkward read flow where "For each repository/service found:" now dangles, separated from the subsection it introduces by a multi-paragraph incremental-scan section.

After insertion:
```markdown
## What to scan

Starting from the project root folder, examine every top-level directory. For each repository/service found:

### Incremental scan -- skip unchanged repos
[... 15+ lines of new content ...]

### Per-repo inventory
1. **Identity**
```

The "For each repository/service found:" colon now points at the incremental scan section, not the per-repo inventory.

**Recommendation:** Insert the incremental scan section BEFORE the intro paragraph (between the "## What to scan" heading at line 15 and the text at line 17), or place it as a separate section before "## What to scan" entirely. Since incremental scanning is about deciding WHICH repos to scan, it logically precedes the instructions for HOW to scan each repo.

### [MIN-2] Task 1 (C1): No storage path specified for raw instrumented session output

**Location:** Task 1, "Specific work" step 1

**Issue:** Task 1 says to run an instrumented session and extract cache data, and specifies the output document (`cost-reduction/caching-audit.md`), but does not specify where to save the raw JSON session output. The Stage 0 instrumentation notes establish the method (`--verbose --output-format stream-json > output.json`), but the raw data file location is unspecified. For reproducibility and future reference, the raw output should be preserved.

**Recommendation:** Add: "Save the raw session output to `cost-reduction/stage-1-caching/instrumented-thorough-plan.json` for reference."

### [MIN-3] Task 5 (C6): The "count `## <date>` entries" detection method may miscount

**Location:** Task 5, "Check `memory/lessons-learned.md`. Count the number of `## <date>` entries"

**Issue:** The plan says to count entries by counting `## <date>` headings. The actual `lessons-learned.md` format (per CLAUDE.md shared rules) is `## <date> -- <task-name>`. The plan's detection rule says "each entry begins with a level-2 heading starting with `##` followed by a date." This would work correctly today. However, the file currently contains an HTML comment block (lines 5-9) with an example `## <date> -- <task-name>` template. Depending on how the counting is implemented, this example inside the comment could be matched as an entry.

**Recommendation:** Specify more precisely: "Count lines that begin with `## ` followed by a date pattern (YYYY-MM-DD), excluding lines inside HTML comments (`<!-- -->`). Alternatively, count lines matching the regex `^## \d{4}-\d{2}-\d{2}`."

### [MIN-4] Task 6 (C7): Scan agent instructions do not specify output size constraints

**Location:** Task 6, Change 2 -- scan agent instructions

**Issue:** The scan agent template instructs each agent to report structured findings across 5 sections but does not specify a target output size. Sonnet agents with broad instructions may produce very long outputs (10K+ tokens per repo), which would make the combined findings document large and expensive for Opus to read during synthesis. This partially defeats the purpose -- if scan findings total 50K tokens across 5 repos, Opus reads nearly as much as it would have read in raw files.

**Recommendation:** Add an output constraint to the scan agent instructions: "Keep your total output under ~3,000-5,000 tokens. Be concise -- include file paths and brief summaries, not full code excerpts. The synthesis phase can do targeted reads of specific files if needed." This ensures the scan output is genuinely compressed relative to the raw files.

### [MIN-5] Task 6 (C7): The "Cost discipline" section (Change 6) first bullet is confusingly worded

**Location:** Task 6, Change 6 -- "Cost discipline" section, first bullet

**Issue:** The bullet says: "Never read raw source files in the main Opus session during Phase 1. That is what scan agents are for." This is confusingly worded because Phase 1 by definition does not run in the main Opus session -- it runs on Sonnet subagents. The intent is clear (do not use Opus for bulk file reading), but the phrasing ties the rule to a phase label that already excludes the main session.

**Recommendation:** Reword to: "Never read raw source files in the main Opus session for bulk exploration. That is what scan agents are for. The only exception is targeted reads of specific files (fewer than ~50 lines, directly relevant to a specific synthesis question) during Phase 2."

### [MIN-6] Task 3 (C4): Dash character in "Important behaviors" replacement must be byte-identical

**Location:** Task 3 (C4), second change block -- replacement of the "Read everything" bullet

**Issue:** The plan's quoted "before" text and the actual file both use an em dash character in "they create false confidence." If the implementer uses a text-matching tool (such as the Edit tool's `old_string` parameter), the dash characters must be byte-identical between the plan's text and the actual file. The plan appears to use `--` (two hyphens) while the actual file uses an em dash character. This mismatch would cause a text-match failure during implementation.

**Recommendation:** During implementation, copy the "before" text directly from the file rather than from the plan. This avoids character-encoding mismatches.

## What the plan gets right

- **The 1a/1b split is well-justified.** Five independent low-risk text edits in 1a versus one significant architectural rewrite in 1b. The plan explains the independence clearly and recommends they can be done in parallel.

- **The Stage 0 findings are properly integrated.** The break-even analysis for C7 scan agents (content must exceed ~10K tokens to justify ~41K base overhead) is mathematically sound and directly shapes design decisions (per-repo scoping, minimum content threshold, small-repo batching).

- **All quoted "before" text in Tasks 2-5 matches the actual file content.** I verified every quoted block against the actual SKILL.md files. The text content matches correctly (minor dash-character caveat noted in MIN-6).

- **The integration analysis is thorough and identifies real interactions.** The C5/C7 positive interaction (repo-heads cache reuse) is correctly identified and specified in Task 6's instructions.

- **The testing strategy is concrete and falsifiable.** Each task has specific test cases with clear pass/fail criteria covering normal, edge, and override scenarios.

- **The cost/benefit analysis is honest about its limitations.** The plan explicitly states that estimates are illustrative and that Task 1 will produce real data. No over-promising.

- **The risk assessment is well-calibrated.** The highest risk (S1-R4, scan agents missing context) is rated Medium/Medium with concrete mitigations. Lower risks get proportionally lower ratings.

- **The plan correctly respects the architecture's staging and gating intent.** It does not attempt to bundle Stage 2 or Stage 3 changes into Stage 1. The scope boundary is clean.

- **Task 6's C7 design faithfully implements the architecture document's intent.** The architecture says C7 should "spawn narrow Sonnet read-only subagents for bulk file exploration (one per repo, in parallel), collect structured findings, run the synthesis pass on Opus serially against the findings." The plan does exactly this, with well-considered additions: /discover integration, minimum content thresholds, small-repo batching, and a cost discipline section.
