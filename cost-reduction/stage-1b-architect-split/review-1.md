# Review 1 — Stage 1b: /architect Scan/Synthesize Split (C7)

**Date:** 2026-04-12
**Reviewer:** /review (Opus)
**File reviewed:** `dev-workflow/skills/architect/SKILL.md`
**Plan:** `cost-reduction/stage-1b-architect-split/current-plan.md`

---

## Summary

The implementation is a faithful, clean rewrite of `architect/SKILL.md` from a 4-phase monolithic Opus structure to a 3-phase scan/synthesize split. All 6 planned tasks were implemented correctly in a single commit. Both MAJOR critic issues (cross-repo integration tracing, scan agent error handling) are properly addressed. The installed copy at `~/.claude/skills/architect/SKILL.md` matches the source file exactly.

## Verdict: APPROVED

---

## Plan Compliance

### Task-by-task verification

| Task | Description | Before removed? | After matches plan? | Acceptance criteria |
|------|-------------|-----------------|---------------------|---------------------|
| 1 | Update frontmatter description | Yes | Yes -- character-for-character match | PASS: mentions "scan/synthesize split" and "Sonnet subagents"; all trigger phrases preserved; no other frontmatter fields changed |
| 2 | Replace Phase 1 with scan phase | Yes -- old "Phase 1: Understand the landscape" and all 5 numbered items removed | Yes -- new heading, /discover integration, scan template, parallelism, model selection, minimum threshold, error handling, questions section all present | PASS: all 11 acceptance criteria met (see detail below) |
| 3 | Remove Phase 2 (web research) | Yes -- old "Phase 2: Research and explore" section completely removed | N/A (deletion) | PASS: section no longer exists; content reappears in Task 4's Phase 2 |
| 4 | Replace Phase 3 with synthesis phase | Yes -- old heading and intro line replaced | Yes -- new heading, cross-reference step, web research content, "Produce a detailed architectural plan" line preserved | PASS: all 7 acceptance criteria met |
| 5 | Renumber Phase 4 to Phase 3 | Yes | Yes -- heading reads "Phase 3: Decomposition into stages" | PASS: content below heading unchanged |
| 6 | Add cost discipline section | N/A (additive) | Yes -- all 5 bullet points present as final section | PASS: all 5 acceptance criteria met |

### Task 2 acceptance criteria detail

| Criterion | Status |
|-----------|--------|
| New Phase 1 heading reads "Phase 1: Scan -- parallel repo exploration (Sonnet subagents)" | PASS |
| /discover integration specified (check for existing output, use repo-heads.md, skip unchanged repos) | PASS |
| Scan agent instructions with all 5 numbered sections (IDENTITY, STRUCTURE, EXTERNAL DEPENDENCIES, API SURFACE, TASK-RELEVANT CODE) | PASS |
| Output size constraint (~3,000-5,000 tokens) explicit in scan agent instructions | PASS |
| Minimum content threshold documented (~5 source files, ~41K token overhead) | PASS |
| Small-repo batching rule (batch 2-3 small repos with < 10 files each) | PASS |
| Parallelism explicit (spawn all simultaneously) | PASS |
| Model selection guidance documented (explicitly request Sonnet; fallback if not supported) | PASS |
| Scan agent failure handling documented (flag to user, retry/fallback/skip, never silently skip) | PASS |
| ADR/documentation reading included in STRUCTURE section of scan template | PASS |
| "Ask questions" behavior preserved (moved to "Questions before synthesis" subsection) | PASS |

### Task 4 acceptance criteria detail

| Criterion | Status |
|-----------|--------|
| New heading reads "Phase 2: Synthesize -- architectural design (Opus)" | PASS |
| Explicit instruction NOT to re-read raw source files | PASS |
| Cross-repo integration mapping step as FIRST action in Phase 2 | PASS |
| Targeted-read fallback documented (specific files only, not whole-repo reads) | PASS |
| Web research content from old Phase 2 fully incorporated | PASS |
| Existing numbered list (1-6) after intro line preserved unchanged | PASS |
| "Produce a detailed architectural plan. The plan should include:" line preserved | PASS |

---

## Critic Issue Verification

### MAJ-1: Cross-repo integration tracing

**Status: RESOLVED**

The "Cross-reference and integration mapping (do this FIRST)" paragraph is present in Phase 2 (line 105 of the final file). It explicitly instructs: match API SURFACE entries against EXTERNAL DEPENDENCIES entries, identify service-to-service calls, shared databases, message queues, event buses, shared libraries. It is positioned before the architectural design work and is marked as the FIRST action. The paragraph also explains WHY this step is needed here ("per-repo scan agents cannot perform because each only sees one repo"). This is a complete fix.

### MAJ-2: Scan agent error handling

**Status: RESOLVED**

The "Scan agent errors" subsection (line 93-95 of the final file) covers: detection criteria (fails, times out, or returns incomplete results with missing sections), three options (retry, fallback to Opus, proceed without), and the prohibition on silently proceeding with missing task-relevant data. This is a complete fix.

---

## Structural Coherence of the Final File

### Phase numbering

- Phase 1: Scan (line 27) -- correct
- Phase 2: Synthesize (line 101) -- correct
- Phase 3: Decomposition (line 143) -- correct
- Sequential, no gaps, no orphaned references to old phase numbers

### Orphaned references check

No references to "Phase 4" remain anywhere in the file. No references to the old phase names ("Understand the landscape", "Research and explore") remain. The Phase 2 cross-reference paragraph mentions "the original Phase 1's 'Trace integrations' work" -- this is explanatory context, not an orphaned reference, and is appropriate.

### Markdown structure

- All headings are properly leveled (## for top-level sections, ### for phases, #### for subsections within Phase 1)
- No unclosed code blocks
- The blockquote for scan agent instructions uses proper `>` formatting
- Numbered lists within the blockquote are correct
- Bullet lists are consistently formatted

### Section integrity

| Section | Status |
|---------|--------|
| Frontmatter (name, description, model) | Correct -- model still "opus" |
| "# Architect" heading and intro paragraph | Unchanged |
| "## Model requirement" | Unchanged |
| "## Session bootstrap" (4 numbered steps) | Unchanged |
| "## How you work" intro paragraph | Unchanged |
| Phase 1 (Scan) | New -- correct per plan |
| Phase 2 (Synthesize) | New heading/intro + preserved numbered list (1-6) |
| Phase 3 (Decomposition) | Renumbered -- content unchanged |
| "### Output format" | Unchanged |
| "## Save session state" | Unchanged |
| "## Important behaviors" (5 bullets) | Unchanged |
| "## Cost discipline" (5 bullets) | New -- correct per plan |

### Internal consistency

- Cost discipline says "Never read raw source files in the main Opus session for bulk exploration" -- consistent with Phase 2's instruction "You do NOT need to re-read the raw source files"
- Cost discipline says "Use /discover output when available" -- consistent with Phase 1's "/discover output first" check
- Cost discipline says "Spawn scan agents per-repo, not per-file" -- consistent with Phase 1's scope specification
- Cost discipline says "Batch small repos" with ~5 source files threshold -- consistent with Phase 1's minimum content threshold
- Cost discipline says "Targeted re-scans during synthesis" for specific files -- consistent with Phase 2's targeted-read fallback
- No contradictions found between any sections

---

## /discover Integration Verification

Cross-checked against `dev-workflow/skills/discover/SKILL.md`:

| Reference in architect/SKILL.md | Actual in discover/SKILL.md | Match? |
|---------------------------------|---------------------------|--------|
| `repos-inventory.md` | Output section: `### repos-inventory.md` | Yes |
| `architecture-overview.md` | Output section: `### architecture-overview.md` | Yes |
| `dependencies-map.md` | Output section: `### dependencies-map.md` | Yes |
| `memory/repo-heads.md` | Written after scans, format: `\| Repo \| HEAD \|` table | Yes |
| HEAD comparison to detect changes | discover checks `git rev-parse HEAD` per repo | Yes |

The integration is correctly specified. The architect skill reads the same files that discover writes, in the expected format.

---

## Installed Copy Verification

`diff` between `dev-workflow/skills/architect/SKILL.md` and `~/.claude/skills/architect/SKILL.md` returned no output -- the files are identical.

---

## Issues Found

### CRITICAL

None.

### MAJOR

None.

### MINOR

**MIN-1: "stale" in Phase 1 is ambiguous.**

Line 37: "If /discover output does not exist **or is stale**, scan all repos." The word "stale" is not defined. The plan's own Phase 1 text above it uses repo-heads.md as the staleness check for individual repos, but this fallback line about scanning "all repos" when output "is stale" has no operational definition. The Round 1 critic raised this as MIN-2 and the plan's convergence summary says it was fixed by removing "recent" -- but "stale" survived. This is vestigial ambiguity.

**Impact:** Low. In practice, if `/discover` output exists, the repo-heads.md check handles staleness per-repo. This line is a catch-all for the case where `/discover` output is missing entirely. An agent following the instructions would likely interpret "stale" as "repo-heads.md shows changes" which is the correct behavior.

**Suggested fix:** Change "or is stale" to "or repo-heads.md does not exist" to make the condition fully operational. Or remove "or is stale" entirely since the per-repo HEAD check above already handles the partial-staleness case.

---

## Integration Safety

| Integration point | Assessment |
|-------------------|------------|
| /discover output files | Safe -- read-only consumption of well-defined files. Format matches discover/SKILL.md. |
| repo-heads.md | Safe -- read-only consumption. Format matches discover/SKILL.md. |
| architecture.md (output) | Safe -- output format and structure unchanged. Downstream consumers (/plan, /critic, etc.) are unaffected. |
| Claude Code Task tool (subagent spawning) | Untested -- the skill assumes Task tool supports model specification for subagents. Fallback documented if not supported. |
| Session state files | Unchanged -- Save session state section is identical to pre-rewrite. |

No cross-service or cross-skill breaking changes. The change is internal to how /architect produces its output, not what it produces.

---

## Risk Assessment

| Risk | Assessment |
|------|------------|
| Plan-quality regression from scan/synthesize split | Mitigated by: (a) cross-repo integration mapping step in Phase 2, (b) targeted reads for specific questions, (c) /critic runs independently on Opus with full access. Acceptable risk. |
| Subagent model specification not working | Documented fallback in the skill. The skill still works (structured extraction + isolation), just without the Sonnet cost savings. Will be immediately apparent on first use. |
| Scan agent output inconsistency | Mitigated by strict 5-section template with numbered sections. Sonnet follows structured templates reliably. |
| Rollback needed | Clean -- single file, single commit, `git revert` + `bash install.sh` restores old behavior. |

---

## Quality Assessment

### Scan agent template
The template is complete, well-structured, and unambiguous. The 5 sections cover all the information categories from the original Phase 1 (identity, structure, dependencies, API surface, task-relevant code) plus documentation (ADRs). The output constraint (3-5K tokens) is clear. The template is factual-only ("Be factual, not interpretive") which correctly defers reasoning to Phase 2.

### Phase 2 synthesis instructions
The cross-reference step is well-specified and correctly positioned as the FIRST action. The web research content is fully preserved from the old Phase 2. The "do NOT re-read raw source files" instruction is clear and the targeted-read exception is well-scoped.

### Cost discipline section
All 5 rules are internally consistent with Phases 1 and 2. The rules are operational (not vague -- they reference specific thresholds, specific files, specific patterns). The ~41K overhead figure provides a concrete justification for the per-repo-not-per-file rule.

---

## Recommendations

1. **Consider fixing the "stale" ambiguity (MIN-1)** before merging. It is a one-word change and removes the last piece of undefined language in the file.

2. **First real-world test should verify Sonnet model selection for subagents.** This is the load-bearing assumption for the cost savings. If the Task tool does not support model specification, the savings are limited to context isolation (still valuable, but not the headline win).

3. **Capture a baseline /architect run cost before and after this change.** The plan acknowledges the Stage 0 /architect measurement was never done. The first post-implementation run should be instrumented to establish the actual savings.
