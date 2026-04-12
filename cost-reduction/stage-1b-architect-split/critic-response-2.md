# Critic Response -- Round 2

## Verdict: PASS

## Round 1 Issue Resolution

### MAJ-1: Cross-repo integration tracing is lost in the scan phase
**Status: RESOLVED**

The revised plan adds an explicit "Cross-reference and integration mapping (do this FIRST)" step at the top of Phase 2 (Task 4, lines 250-251 of the plan). The fix is exactly what was recommended: match API SURFACE entries from one repo against EXTERNAL DEPENDENCIES entries from other repos, build a cross-repo integration map, and do this BEFORE starting the architectural design. The instruction is prominent (bold "do this FIRST"), correctly explains WHY per-repo agents cannot do this work, and explicitly connects it to the integration analysis section of the architectural plan. Well done.

### MAJ-2: No guidance for scan agent failure or timeout
**Status: RESOLVED**

The revised plan adds a dedicated "Scan agent errors" subsection in Task 2 (lines 167-168). It specifies: flag failures to the user, offers three options (retry, fallback to Opus direct read, proceed without), and explicitly says "Do NOT silently proceed with missing scan data for a task-relevant repo." This addresses the concern completely. The criteria for "incomplete results" (missing one or more of the 5 required sections) is a good operational test.

### MIN-1: ~50-line threshold for targeted reads is too restrictive
**Status: RESOLVED**

The revised plan removes the 50-line threshold entirely. Task 4's Phase 2 now says "targeted reads of specific files directly relevant to a synthesis question (not whole-repo reads)" and Task 6's cost discipline says "specific files directly relevant to a specific synthesis question" with a new bullet "Prefer reading individual files over spawning new scan agents for single-file needs." The per-repo and no-bulk-exploration rules remain as sufficient guardrails. This matches the architecture doc's C7 wording exactly.

### MIN-2: "Recent" is undefined for /discover output staleness check
**Status: RESOLVED**

The revised Task 2 changes "If these exist and are recent" to "If these exist" and lets the repo-heads.md check be the sole staleness mechanism. The ambiguous word "recent" has been removed. The /discover output freshness is now operationally defined by repo-heads.md HEAD comparison, which is concrete and verifiable.

### MIN-3: Cost projections use published API rates, not measured billing rates
**Status: RESOLVED**

The revised plan adds the recommended note in the Cost/benefit summary (lines 467-468): "Dollar figures use published API rates. If the billing tier applies a discount (as observed in Stage 0 baseline -- ~3x lower than published rates), absolute dollar savings would be proportionally lower. The percentage reduction (39-59%) is rate-independent." This is the right framing -- the percentage is the meaningful number.

### MIN-4: /architect baseline was not measured in Stage 0
**Status: RESOLVED**

The revised Executive Summary (line 18) now includes: "Note: The /architect-specific Stage 0 measurement was not completed. Cost estimates are derived from /plan subagent data (similar workload profile) and published API rates. Actual savings should be verified after the first post-implementation /architect run." This acknowledges the limitation without blocking progress.

### MIN-5: No guidance on specifying Sonnet model for scan subagents
**Status: RESOLVED**

The revised Task 2 adds a "Model selection" bullet (line 159): "When spawning scan agents, explicitly request Sonnet as the model. In Claude Code, the Task tool allows specifying the model for the spawned agent. If model specification is not supported in the current harness version, the scan agents still provide value through structured extraction and context isolation, though the model-tiering cost savings would not apply." This is honest about the uncertainty while documenting the intent. The acceptance criteria (line 183) also explicitly includes model selection guidance.

### MIN-6: "Read existing documentation" from original Phase 1 not in scan template
**Status: RESOLVED**

The revised scan template's STRUCTURE section (line 136 area) now includes "Architecture Decision Records (ADRs), design docs, or other documentation (summarize key decisions)." The acceptance criteria (line 185) explicitly confirms this: "Documentation reading (ADRs, design docs) is included in the STRUCTURE section of the scan template."

## New Issues

### CRITICAL

None.

### MAJOR

None.

### MINOR

None. The revisions are clean and internally consistent. I checked for the following potential issues introduced by the revisions:

1. **Cross-reference step + "Do NOT process or interpret" contradiction?** The "Collecting scan results" section says "Do NOT process or interpret them yet -- that is Phase 2," and the cross-referencing step is correctly placed in Phase 2. No contradiction.

2. **Scan agent error handling creates a new untested path?** The fallback to "read the failed repo directly in the main Opus session during Phase 2" is a graceful degradation that reverts to the old behavior for that specific repo. This is safe and does not need its own test case -- it is the pre-existing behavior.

3. **Model selection fallback weakens the value proposition?** The "if model specification is not supported" clause is an honest hedge. If Sonnet cannot be specified, the plan still works (structured extraction + context isolation have independent value), but the headline cost savings would not materialize. This is a risk acknowledgment, not a plan defect. The implementation will immediately reveal whether model specification works, and the testing strategy (Test 1) explicitly checks for it.

4. **ADR mention in STRUCTURE section -- could scan agents waste time searching for docs that don't exist?** No -- "Architecture Decision Records (ADRs), design docs, or other documentation (summarize key decisions)" is a scan instruction, not a mandate. If no docs exist, the agent reports nothing for that item. The output constraint (~3-5K tokens) prevents agents from over-spending time.

## Text match verification

| Task | Before block | Actual file content | Match? |
|------|-------------|---------------------|--------|
| Task 1 (frontmatter) | `description: "Deep architectural analysis..."` | Line 3 of SKILL.md | MATCH |
| Task 2 (Phase 1) | `### Phase 1: Understand the landscape` through item 5 | Lines 27-44 of SKILL.md | MATCH |
| Task 3 (Phase 2) | `### Phase 2: Research and explore` through 4 bullets | Lines 46-53 of SKILL.md | MATCH |
| Task 4 (Phase 3) | `### Phase 3: Architectural design` + intro line | Lines 55-57 of SKILL.md | MATCH |
| Task 5 (Phase 4) | `### Phase 4: Decomposition into stages` | Line 91 of SKILL.md | MATCH |
| Task 6 (end of file) | Last line of Important behaviors: "Consider the team..." | Line 149 of SKILL.md | MATCH |

All "Before" blocks match the actual file content. Edits will apply cleanly.

## Internal consistency check

After applying all revisions, the plan remains internally consistent:

- The Phase 2 cross-reference step correctly references the scan findings structure (API SURFACE + EXTERNAL DEPENDENCIES) from Phase 1's scan template.
- The cost discipline section's rules are consistent with Phase 1 and Phase 2 instructions (no contradictions on when to read files directly vs. spawn agents).
- The acceptance criteria for each task correctly reflect the revised content.
- The testing strategy covers all key behaviors including the new additions (scan agent failure handling would be caught by Test 3's "Phase 2 does not read raw files" -- if a scan agent failed silently, the synthesis phase would lack findings and would have to read raw files, failing Test 3).
- The risk register's R7 (architecture quality degradation) correctly references the mitigations that were strengthened by the revisions (targeted reads, /critic catchnet).

## Completeness check against architecture C7 and /discover integration

- C7's three-part spec (scan, collect, synthesize) is fully covered.
- /discover integration via repo-heads.md is correct. The /discover SKILL.md writes `memory/repo-heads.md` in the format the plan's Phase 1 expects to read (table with Repo | HEAD columns). No format mismatch.
- The /discover output files (`repos-inventory.md`, `architecture-overview.md`, `dependencies-map.md`) referenced in the plan match the output section of discover/SKILL.md exactly.
- E2 (parallelize independent reads) is covered by the parallel scan agent design.
- E3 (explicit context manifests) is partially covered -- acceptable for a first implementation as noted in Round 1.

## Summary

All 8 issues from Round 1 (2 MAJOR, 6 MINOR) have been properly resolved. The fixes are correct, complete, and do not introduce new problems. The plan is internally consistent, faithful to the architecture spec's C7 lever, correctly integrates with /discover output, and has comprehensive testing and rollback strategies.

The plan is ready for implementation.
