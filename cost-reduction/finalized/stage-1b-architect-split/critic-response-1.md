# Critic Response -- Round 1

## Verdict: REVISE

Two MAJOR issues need to be addressed before implementation. No CRITICAL issues (text matches are clean).

## Issues

### CRITICAL

None.

### MAJOR

**MAJ-1: Cross-repo integration tracing is lost in the scan phase.**

The original Phase 1 included item 3: "Trace integrations -- identify how services communicate: HTTP APIs, gRPC, message queues, shared databases, event buses. Map the dependency graph between services." This is inherently cross-repo analysis -- a per-repo scan agent cannot map which service calls which, because it only sees one repo at a time.

The new scan agent template captures per-repo inputs (EXTERNAL DEPENDENCIES lists what a repo calls) and per-repo outputs (API SURFACE lists what a repo exposes), but nobody is told to connect the dots. The plan says "Do NOT process or interpret them yet -- that is Phase 2." But Phase 2's instructions say "reason across all of these inputs to produce the architectural design" -- a general mandate, not an explicit call to perform integration tracing.

**Why this matters:** Integration tracing is the most architecturally valuable part of the old Phase 1. Missing it silently degrades architecture quality -- exactly the R7 risk the plan's own risk register flags as "Medium likelihood, High impact."

**Fix:** Add an explicit step at the top of Phase 2 (Synthesize): "Before starting the architectural design, cross-reference the scan findings to map integration points: match API SURFACE entries from one repo against EXTERNAL DEPENDENCIES entries from other repos. Identify which service calls which, shared databases, shared message topics. This cross-repo integration map is the foundation for the integration analysis section of the architectural plan." This makes it the first thing Opus does in synthesis -- before it forgets.

**MAJ-2: No guidance for scan agent failure or timeout.**

The plan specifies parallel scan agents but has zero guidance for what happens when one fails. Scan agents are ephemeral subagents with a 5-minute TTL. On a large repo, a Sonnet scan could time out or error. The plan's "Collecting scan results" section says "Collect all findings into a combined document" but doesn't address partial results.

**Why this matters:** If a scan agent for the most important repo fails silently, the synthesis phase produces an architecture that's blind to that repo. The architect (or the user) won't necessarily notice the gap.

**Fix:** Add to the "Collecting scan results" section: "If a scan agent fails, times out, or returns incomplete results (missing one or more of the 5 required sections), flag it to the user. Options: (a) retry the failed scan, (b) read the failed repo directly in the Opus session (fallback to old behavior for that repo), (c) proceed without it if the repo is peripheral to the task. Do not silently proceed with missing scan data for a task-relevant repo."

### MINOR

**MIN-1: The ~50-line threshold for targeted reads is too restrictive and not in the parent spec.**

The Cost Discipline section says targeted reads should be "fewer than ~50 lines." The architecture doc's C7 description says "targeted reads of specific files (not whole-repo reads)" without a line-count threshold. Many important files (route definitions, service classes, configuration) are 200-500 lines. A 50-line cap would force the architect to spawn a new scan agent just to read a single file, paying ~41K tokens of overhead for a 500-line file (~1.5K tokens of actual content).

**Suggested fix:** Change "fewer than ~50 lines" to "specific files directly relevant to a synthesis question" and add "prefer reading individual files over spawning new scan agents for single-file needs." The per-repo rule and the no-bulk-exploration rule are sufficient discipline without an arbitrary line cap.

**MIN-2: "Recent" is undefined for /discover output staleness check.**

The Phase 1 text says "If these exist and are recent, read them." The repo-heads.md mechanism handles commit-level staleness, but "recent" is never defined. In practice, the repo-heads.md check is the operational definition of "recent" -- if HEADs match, the output is current. The word "recent" is vestigial from the original Phase 1 text and creates ambiguity.

**Suggested fix:** Replace "If these exist and are recent" with "If these exist" and let the repo-heads.md check be the sole staleness mechanism. Or define "recent" explicitly (e.g., "scanned within the last 7 days, as shown by the 'Last scanned:' date in the files").

**MIN-3: Cost projections use published API rates, not measured billing rates.**

The baseline document explicitly states: "The measured cost ($10.66) does not match standard published Anthropic API rates" and "For cost reduction projections, use the reported $10.66 as the baseline, not the rate-calculated amount." The plan's cost table uses published rates ($15/M for Opus, $3/M for Sonnet). The percentage savings (39-59%) are likely correct regardless of the billing rate (since the ratio between Opus and Sonnet is the same), but the dollar figures ($0.95-4.48 per invocation, $2-13/week) may overstate actual savings by ~3x.

**Suggested fix:** Add a note to the Cost/benefit summary: "Dollar figures use published API rates. If the billing tier applies a discount (as observed in Stage 0 baseline -- ~3x lower than published rates), absolute dollar savings would be proportionally lower. The percentage reduction (39-59%) is rate-independent."

**MIN-4: /architect baseline was not measured in Stage 0 -- plan should acknowledge this.**

The baseline document says (Section 2): "Not measured in this session. Task 5 (instrumented /architect run) remains to be completed." The architecture doc says C7 "sizing depends on Stage 0's /architect-specific measurement." The plan proceeds without this measurement, using estimates derived from the /plan subagent data. This is reasonable (the plan should not be blocked on a measurement that wasn't done), but the plan should acknowledge it as a limitation rather than presenting the cost numbers as firm.

**Suggested fix:** Add a line to the Executive Summary or Cost/benefit summary: "Note: The /architect-specific Stage 0 measurement was not completed. Cost estimates below are derived from /plan subagent data (similar workload profile) and published API rates. Actual savings should be verified after the first post-implementation /architect run."

**MIN-5: The plan does not address how to specify Sonnet model for scan subagents.**

The plan says "Model: Sonnet (cheaper for bulk reading)" in the scan agent instructions, but the architect skill runs as `model: opus`. The baseline data (Appendix B) shows subagents are spawned via the Task tool. The plan assumes the Opus session can spawn Sonnet subagents but doesn't document the mechanism. If Claude Code's Task tool inherits the parent's model setting, scan agents would run on Opus, defeating the purpose.

**Suggested fix:** Add a note: "When spawning scan agents, explicitly request Sonnet as the model. In Claude Code, the Task tool allows specifying the model for the spawned agent. If this is not possible, the scan agents still provide value through structured extraction and context isolation, though the model-tiering cost savings would not apply." (Or verify the mechanism and document it concretely.)

**MIN-6: "Read existing documentation" from original Phase 1 is not explicitly in scan template.**

The original Phase 1 item 4 says "Read existing documentation -- check for architecture docs, ADRs (Architecture Decision Records), design docs, wikis. Read them." The scan agent template's 5 sections don't explicitly include this. ADRs and design docs would partially fall under STRUCTURE ("Configuration files and what they control") but that's a stretch. Documentation reading may be better handled by the /discover output (which captures "Key architectural decisions" in `architecture-overview.md`) or by an explicit mention in the scan template.

**Suggested fix:** Add to the STRUCTURE section of the scan template: "- Architecture Decision Records (ADRs), design docs, or other documentation (summarize key decisions)". Or note in Phase 2 that the synthesis phase should check for docs that scan agents may have missed.

## Text match verification

| Task | Before block | Actual file content | Match? |
|------|-------------|-------------------|--------|
| Task 1 (frontmatter) | `description: "Deep architectural analysis..."` | Line 3 of SKILL.md | MATCH -- character-for-character identical |
| Task 2 (Phase 1) | `### Phase 1: Understand the landscape` through item 5 | Lines 27-44 of SKILL.md | MATCH -- verified line by line |
| Task 3 (Phase 2) | `### Phase 2: Research and explore` through 4 bullets | Lines 46-53 of SKILL.md | MATCH |
| Task 4 (Phase 3) | `### Phase 3: Architectural design` + intro line | Lines 55-57 of SKILL.md | MATCH |
| Task 5 (Phase 4) | `### Phase 4: Decomposition into stages` | Line 91 of SKILL.md | MATCH |
| Task 6 (Cost discipline) | Last line of Important behaviors section | Line 149 of SKILL.md | MATCH |

All "Before" blocks match the actual file content. The edits will apply cleanly.

## Completeness check against parent spec (Stage 1a Task 6)

The Stage 1a plan's Task 6 specifies 6 changes. The Stage 1b plan maps these 1:1:

| Parent spec change | Stage 1b task | Faithful? |
|-------------------|---------------|-----------|
| Change 1 (frontmatter) | Task 1 | Yes -- identical text |
| Change 2 (Phase 1 replacement) | Task 2 | Yes -- identical text |
| Change 3 (Remove Phase 2) | Task 3 | Yes |
| Change 4 (Replace Phase 3 heading/intro) | Task 4 | Yes -- identical text |
| Change 5 (Renumber Phase 4) | Task 5 | Yes |
| Change 6 (Cost discipline section) | Task 6 | Yes -- identical text |

Nothing from the parent spec was dropped or changed. The Stage 1b plan is a faithful expansion of the parent spec with added context, risk analysis, testing, and rollback planning.

## Completeness check against architecture C7

The architecture doc's C7 lever specifies:
- (a) Spawn narrow Sonnet read-only subagents for bulk file exploration (one per repo, in parallel) -- **covered** in Task 2
- (b) Collect structured findings -- **covered** in Task 2
- (c) Run the synthesis pass on Opus serially against the findings (not the raw files) -- **covered** in Task 4
- Pair with C5 to skip unchanged repos entirely -- **covered** in Task 2 (repo-heads.md integration)
- Cache the final architecture.md so downstream skills reading it get the cached-read discount -- **not covered**, but this is a harness-level behavior, not a SKILL.md change. The harness already caches file reads at 87.5% hit rate per baseline data. Not actionable in this plan.

E2 (parallelize independent reads) -- **covered** by the parallel scan agent design.
E3 (explicit context manifests per subagent) -- **partially covered**. The scan agent instructions include the repo path and task context, but the plan doesn't have the orchestrator providing an explicit list of files to read per repo. The scan agent is told to discover files itself. This is acceptable for the scan use case (the agent needs to discover what exists) but diverges from E3's "prevent agents from re-discovering files the orchestrator already knows about." For a first implementation this is fine; E3 optimization can come later.

## Summary

The plan is well-structured, thorough, and faithfully implements the parent spec. All text matches verify cleanly -- the implementation edits will apply without issues. The cost analysis is directionally correct and the risk register is comprehensive.

Two issues require revision before implementation:

1. **Cross-repo integration tracing (MAJ-1)** is the most important fix. The original Phase 1's integration tracing step is architecturally critical and is currently lost in the per-repo scan agent model. An explicit synthesis step to cross-reference scan findings fixes this cleanly.

2. **Scan agent failure handling (MAJ-2)** is a practical gap. Parallel subagents can fail, and the plan needs guidance for incomplete results.

The MINOR issues are real but non-blocking. MIN-1 (50-line threshold), MIN-3 (cost rate discrepancy), and MIN-5 (Sonnet model mechanism) are the most worth addressing. The others are documentation polish.

Overall quality: **good**. With the two MAJOR fixes, the plan is ready for implementation.
