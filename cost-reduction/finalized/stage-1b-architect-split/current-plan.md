# Stage 1b Plan: /architect Scan/Synthesize Split (C7)

**Date:** 2026-04-12
**Task:** Rewrite `dev-workflow/skills/architect/SKILL.md` to use a two-phase approach: Sonnet subagents scan repos in parallel, then Opus synthesizes findings
**File to modify:** `dev-workflow/skills/architect/SKILL.md` (149 lines, ~2,171 tokens)
**Lever:** C7 from the cost-reduction architecture

---

## Convergence Summary
- **Rounds:** 2
- **Final verdict:** PASS
- **Key revisions:** Round 1 critic found 2 MAJOR issues: (1) cross-repo integration tracing was lost when moving from unified Opus Phase 1 to per-repo scan agents — fixed by adding explicit cross-referencing step at the top of Phase 2 (Synthesize); (2) no guidance for scan agent failure/timeout — fixed by adding error handling subsection with retry, fallback-to-Opus, and skip options. All 6 MINOR issues also addressed (removed arbitrary line cap on targeted reads, clarified staleness check, added rate disclaimers, acknowledged missing /architect baseline, documented subagent model selection mechanism, added ADR scanning to template).
- **Remaining concerns:** None — Round 2 critic found no new issues.

---

## Executive summary

The `/architect` skill is the single most expensive per-invocation skill in the workflow. It runs entirely on Opus and performs bulk file reading across multiple repos — paying Opus rates (~$15/M input) for what is essentially mechanical extraction work. This plan rewrites the skill into two phases: (1) spawn parallel Sonnet subagents to scan repos and extract structured findings, (2) use the Opus session for synthesis, architectural reasoning, and design — the work that actually benefits from the strongest model.

The rewrite also integrates with the `/discover` output and the `repo-heads.md` mechanism (C5, already implemented in Stage 1a) so that unchanged repos are not re-scanned at all.

**Scope:** One file rewrite (`architect/SKILL.md`). No code, no tests to run. Testing is behavioral (run `/architect` and verify the two-phase pattern).

**Expected savings:** ~$0.95-4.48 per `/architect` invocation (39-59% reduction in file-reading cost), depending on project size. Note: The /architect-specific Stage 0 measurement was not completed. Cost estimates are derived from /plan subagent data (similar workload profile) and published API rates. Actual savings should be verified after the first post-implementation /architect run.

---

## Stage 0 findings that shape this plan

From `cost-reduction/baseline.md` and `cost-reduction/caching-audit.md`:

| Finding | Value | Implication for this plan |
|---------|-------|--------------------------|
| Per-spawn base overhead | ~41,000 tokens | Each scan subagent pays this. Break-even vs Opus inline reading is ~10K tokens of actual content per agent. Only spawn agents for repos with enough content to justify the overhead. |
| Subagent TTL | 5 minutes (ephemeral) | Scan agents are short-lived; their cache writes expire fast. Not a concern since we only need them for one pass. |
| Subagent cache sharing | ~13,500 tokens of shared prefix across subagents | Multiple scan agents share the system prompt + CLAUDE.md prefix, so the 2nd+ scan agent gets a partial cache hit if spawned within 5 minutes of the first. |
| Sonnet vs Opus input rate | $3/M vs $15/M (5x cheaper) | The core cost win. File reading on Sonnet saves 80% on input tokens. |
| /plan peak context | 123,923 tokens (heavy file reading) | /architect likely similar or higher. Moving this to Sonnet is the largest lever. |
| Caching already at 87.5% hit rate | Within-phase cache reads are excellent | The savings come from model tiering (Sonnet vs Opus), not from caching improvements. |

---

## Tasks

### Task 1: Update frontmatter description ✅ completed

**What:** Update the YAML frontmatter `description` field to reflect the scan/synthesize pattern. This is a cosmetic but important change — it affects how the skill loader describes the skill and helps future readers understand the design intent.

**File:** `dev-workflow/skills/architect/SKILL.md`

**Location:** The `description:` field in the YAML frontmatter block (between the `---` delimiters at the top of the file).

**Before:**
```yaml
description: "Deep architectural analysis and planning using the strongest available model (Opus). Use this skill whenever the user needs to explore a complex system, understand how multiple repositories interact, design a new architecture, decompose a large problem into implementable stages, or answer hard cross-cutting questions about a codebase. Triggers on: /architect, architecture design, system design, technical exploration, cross-repo analysis, complex technical questions, 'how should we build this', 'what's the best approach for', deep code exploration, multi-service design. Even if the user just says 'I need to think through X' where X is technical — use this skill."
```

**After:**
```yaml
description: "Deep architectural analysis and planning using the strongest available model (Opus), with a scan/synthesize split for efficiency. Spawns Sonnet subagents in parallel to read repos, then synthesizes findings on Opus. Use this skill whenever the user needs to explore a complex system, understand how multiple repositories interact, design a new architecture, decompose a large problem into implementable stages, or answer hard cross-cutting questions about a codebase. Triggers on: /architect, architecture design, system design, technical exploration, cross-repo analysis, complex technical questions, 'how should we build this', 'what's the best approach for', deep code exploration, multi-service design. Even if the user just says 'I need to think through X' where X is technical — use this skill."
```

**Acceptance criteria:**
- Description mentions "scan/synthesize split" and "Sonnet subagents"
- All existing trigger phrases are preserved
- No other frontmatter fields are changed

**Risk:** None. Cosmetic change.

**Dependencies:** None. Can be implemented independently.

---

### Task 2: Replace Phase 1 with scan phase (Sonnet subagents) ✅ completed

**What:** Replace the entire `### Phase 1: Understand the landscape` section with a new `### Phase 1: Scan — parallel repo exploration (Sonnet subagents)` section. This is the core change — it moves bulk file reading from the Opus session to parallel Sonnet subagents.

**File:** `dev-workflow/skills/architect/SKILL.md`

**Location:** The section starting with `### Phase 1: Understand the landscape` and ending just before `### Phase 2: Research and explore`. This spans from the heading through the numbered list items (1. Scan the project folder, 2. Read key files, 3. Trace integrations, 4. Read existing documentation, 5. Ask questions).

**Before:**
```markdown
### Phase 1: Understand the landscape

Before designing anything, build a complete mental model. **Start by checking if `/discover` has already been run** — look for these files in `memory/`:
- `repos-inventory.md` — per-repo tech stack, structure, dependencies
- `architecture-overview.md` — service map, communication patterns, request flows
- `dependencies-map.md` — cross-service dependencies, shared resources, deployment order

If these exist and are recent, read them first — they give you a huge head start. If they don't exist or are stale, suggest running `/discover` first, or do the scanning yourself:

1. **Scan the project folder** — list all repositories, services, packages. Understand the directory structure and what lives where. Use `find`, `ls`, `tree` to map the terrain.

2. **Read key files** — for each repo/service, read: README, package.json/go.mod/Cargo.toml/pyproject.toml (dependency context), main entry points, configuration files, docker-compose or k8s manifests, CI/CD configs. Don't skim — read properly.

3. **Trace integrations** — identify how services communicate: HTTP APIs, gRPC, message queues, shared databases, event buses. Map the dependency graph between services. This is critical for risk analysis later.

4. **Read existing documentation** — check for architecture docs, ADRs (Architecture Decision Records), design docs, wikis. Read them. They contain institutional knowledge.

5. **Ask questions** — if something is unclear or ambiguous, ask the user. Don't assume. Use the AskUserQuestion tool with specific, pointed questions. Better to ask 3 good questions upfront than to build a plan on wrong assumptions.
```

**After:**
```markdown
### Phase 1: Scan — parallel repo exploration (Sonnet subagents)

The goal of Phase 1 is to gather structured facts from the codebase WITHOUT doing architectural reasoning. Reasoning is Phase 2's job. Phase 1 is read-only bulk extraction.

**Check for /discover output first.** Before spawning scan agents, check `memory/` for existing `/discover` output (`repos-inventory.md`, `architecture-overview.md`, `dependencies-map.md`). If these exist:
- Read them to understand the landscape baseline
- Use `memory/repo-heads.md` (if it exists) to identify repos that have changed since the last `/discover` run
- Only spawn scan agents for repos that are (a) changed since last scan, or (b) specifically relevant to the current task
- For unchanged repos, the `/discover` output IS the scan output — no need to re-scan

**If /discover output does not exist or is stale**, scan all repos.

#### Spawning scan agents

For each repo (or batch of small repos) that needs scanning, spawn a subagent with these parameters:

- **Model:** Sonnet (cheaper for bulk reading — this is the core cost win)
- **Scope:** One repo per agent (or batch 2-3 small repos into one agent if each has < 10 files)
- **Instructions to each scan agent:**

  > You are a read-only code scanner. Your job is to extract structured facts from this repository. Do NOT do architectural analysis or design — just report what you find.
  >
  > Repo path: <repo-path>
  > Task context: <brief description of what the /architect session is investigating>
  >
  > Scan and report:
  >
  > 1. IDENTITY
  >    - Repo name, primary language(s), framework(s), runtime, build system
  >    - Detected from: package.json, go.mod, Cargo.toml, requirements.txt, etc.
  >
  > 2. STRUCTURE
  >    - Key directories and what they contain
  >    - Entry points (main files, index files, server startup)
  >    - Configuration files and what they control
  >    - Test structure (where tests live, framework used)
  >    - Architecture Decision Records (ADRs), design docs, or other documentation (summarize key decisions)
  >
  > 3. EXTERNAL DEPENDENCIES
  >    - Key libraries/frameworks (the important ones, not every transitive dep)
  >    - External services called (from config, env vars, client code)
  >    - Database connections (type, patterns)
  >    - Message queues, event buses, cache systems
  >
  > 4. API SURFACE
  >    - Exposed endpoints (REST routes, GraphQL schemas, gRPC protos)
  >    - Published events/messages
  >    - Shared libraries or packages exported
  >
  > 5. TASK-RELEVANT CODE
  >    - Files, functions, and patterns specifically relevant to: <task context>
  >    - Include file paths and brief code summaries (not full file contents)
  >    - Flag any code that seems fragile, complex, or likely to interact with the task
  >
  > **Output constraint:** Keep your total output under ~3,000-5,000 tokens. Be concise — include file paths and brief summaries, not full code excerpts. The synthesis phase can do targeted reads of specific files if it needs more detail.
  >
  > Output format: structured markdown with the sections above. Be factual, not interpretive. Include file paths for everything you reference.

- **Parallelism:** Spawn all scan agents simultaneously. They are independent and read-only.
- **Model selection:** When spawning scan agents, explicitly request Sonnet as the model. In Claude Code, the Task tool allows specifying the model for the spawned agent. If model specification is not supported in the current harness version, the scan agents still provide value through structured extraction and context isolation, though the model-tiering cost savings would not apply.
- **Minimum content threshold:** Only spawn a scan agent if the repo contains enough code to justify the ~41K token base overhead. For repos with fewer than ~5 source files, include them in a batch with another small repo, or read them directly in the main session during Phase 2.

#### Collecting scan results

Each scan agent returns its structured findings. Collect all findings into a combined document. Do NOT process or interpret them yet — that is Phase 2.

#### Scan agent errors

If a scan agent fails, times out, or returns incomplete results (missing one or more of the 5 required sections), flag it to the user. Options: (a) retry the failed scan, (b) read the failed repo directly in the main Opus session during Phase 2 (fallback to old behavior for that repo), (c) proceed without it if the repo is peripheral to the task. Do NOT silently proceed with missing scan data for a task-relevant repo.

#### Questions before synthesis

If something in the scan findings is unclear or ambiguous, ask the user. Don't assume. Use the AskUserQuestion tool with specific, pointed questions. Better to ask 3 good questions upfront than to build a plan on wrong assumptions.
```

**Acceptance criteria:**
- New Phase 1 heading reads "Phase 1: Scan — parallel repo exploration (Sonnet subagents)"
- /discover integration is specified: check for existing output, use repo-heads.md, skip unchanged repos
- Scan agent instructions are complete with all 5 numbered sections (IDENTITY, STRUCTURE, EXTERNAL DEPENDENCIES, API SURFACE, TASK-RELEVANT CODE)
- Output size constraint (~3,000-5,000 tokens) is explicit in the scan agent instructions
- Minimum content threshold is documented (~5 source files, ~41K token overhead justification)
- Small-repo batching rule is specified (batch 2-3 small repos with < 10 files each)
- Parallelism is explicit (spawn all simultaneously)
- Model selection guidance is documented (explicitly request Sonnet; fallback behavior if not supported)
- Scan agent failure handling is documented (flag to user, retry/fallback/skip options, never silently skip task-relevant repos)
- Documentation reading (ADRs, design docs) is included in the STRUCTURE section of the scan template
- The "Ask questions" behavior from the original Phase 1 is preserved (moved to end of scan collection)

**Risk:** Medium. This is the most significant change. Risks:
1. Scan agents miss something a unified Opus pass would catch. Mitigation: task-relevant code section in scan template; targeted reads in Phase 2; /critic still runs on Opus with full access.
2. Subagent overhead eats savings on small projects. Mitigation: minimum content threshold and batching.
3. Scan output format inconsistent across agents. Mitigation: strict numbered template.

**Dependencies:** None. But benefits from C5 (`repo-heads.md`) already being implemented.

---

### Task 3: Remove Phase 2 (web research) and merge into synthesis ✅ completed

**What:** Remove the entire `### Phase 2: Research and explore` section. Its content (web research instructions) will be folded into the new Phase 2 (Synthesize) in Task 4.

**File:** `dev-workflow/skills/architect/SKILL.md`

**Location:** The section starting with `### Phase 2: Research and explore` and ending just before `### Phase 3: Architectural design`. This is the 4-bullet-point section about web research, external docs, similar solutions, and internal patterns.

**Before:**
```markdown
### Phase 2: Research and explore

When the problem requires knowledge beyond what's in the codebase:

- **Search the web** for best practices, design patterns, known pitfalls with specific technologies
- **Read external documentation** for APIs, frameworks, or services involved
- **Look at how others have solved similar problems** — open source examples, blog posts, conference talks
- **Check for existing internal patterns** — if the codebase already has a way of doing things (error handling, logging, auth), follow those patterns unless there's a strong reason to deviate
```

**After:** (section is deleted entirely — content is incorporated into Task 4's new Phase 2)

**Acceptance criteria:**
- The old `### Phase 2: Research and explore` section no longer exists as a standalone section
- None of its content is lost — it reappears in the new Phase 2 (Task 4)

**Risk:** None if Task 4 is implemented in the same commit. Medium if implemented separately (web research instructions would be missing temporarily).

**Dependencies:** Must be implemented together with Task 4 (same commit).

---

### Task 4: Replace Phase 3 with synthesis phase (Opus) ✅ completed

**What:** Replace the `### Phase 3: Architectural design` heading and its introductory line with a new `### Phase 2: Synthesize — architectural design (Opus)` section that incorporates the web research content from the deleted Phase 2, and explicitly instructs the Opus session to work from scan findings rather than raw files.

**File:** `dev-workflow/skills/architect/SKILL.md`

**Location:** The `### Phase 3: Architectural design` heading and the single line immediately following it ("Produce a detailed architectural plan. The plan should include:"). The numbered list (1. Context and problem statement, 2. Current state analysis, ... 6. De-risking strategy) that follows is NOT replaced — it remains as-is.

**Before:**
```markdown
### Phase 3: Architectural design

Produce a detailed architectural plan. The plan should include:
```

**After:**
```markdown
### Phase 2: Synthesize — architectural design (Opus)

**This is where Opus earns its keep.** You now have structured scan findings from every relevant repo (Phase 1). Your job is to reason across all of these inputs to produce the architectural design. You do NOT need to re-read the raw source files — the scan findings contain the facts you need. If a scan finding is ambiguous or insufficient, you can do targeted reads of specific files directly relevant to a synthesis question (not whole-repo reads).

**Cross-reference and integration mapping (do this FIRST).** Before starting the architectural design, cross-reference the scan findings to map integration points across repos. Match API SURFACE entries from one repo against EXTERNAL DEPENDENCIES entries from other repos. Identify: which service calls which (HTTP, gRPC), shared databases, shared message queue topics, event bus channels, shared libraries. Build a cross-repo integration map — this is the foundation for the integration analysis section of the architectural plan. This step replaces the original Phase 1's "Trace integrations" work, which per-repo scan agents cannot perform because each only sees one repo.

**Web research:** When the problem requires knowledge beyond what's in the codebase, search the web for best practices, design patterns, and known pitfalls with specific technologies. Read external documentation for APIs, frameworks, or services involved. Look at how others have solved similar problems — open source examples, blog posts, conference talks. Check for existing internal patterns — if the codebase already has a way of doing things (error handling, logging, auth), the scan findings will have surfaced them. Web research happens here in the main Opus session because it benefits from the strongest model and is naturally interleaved with synthesis reasoning.

Produce a detailed architectural plan. The plan should include:
```

**Acceptance criteria:**
- New heading reads "Phase 2: Synthesize — architectural design (Opus)"
- Explicit instruction NOT to re-read raw source files (use scan findings instead)
- Cross-repo integration mapping step is explicitly called out as the FIRST action in Phase 2 (before architectural design)
- Targeted-read fallback is documented (specific files only, not whole-repo reads)
- Web research content from old Phase 2 is fully incorporated
- The existing numbered list (1-6) after the intro line is preserved unchanged
- The introductory line "Produce a detailed architectural plan. The plan should include:" is preserved

**Risk:** Low. The numbered list content is unchanged; only the heading and intro paragraph are modified.

**Dependencies:** Must be implemented together with Task 3 (same commit, since Task 3 removes the old Phase 2 whose content is incorporated here).

---

### Task 5: Renumber Phase 4 to Phase 3 ✅ completed

**What:** Rename `### Phase 4: Decomposition into stages` to `### Phase 3: Decomposition into stages`. Content is unchanged — this is purely a renumber to maintain sequential phase numbering after the old Phases 1-4 became Phases 1-3.

**File:** `dev-workflow/skills/architect/SKILL.md`

**Location:** The `### Phase 4: Decomposition into stages` heading.

**Before:**
```markdown
### Phase 4: Decomposition into stages
```

**After:**
```markdown
### Phase 3: Decomposition into stages
```

**Acceptance criteria:**
- Heading reads "Phase 3: Decomposition into stages"
- No content below the heading is changed

**Risk:** None. Pure renumber.

**Dependencies:** Logically follows Tasks 2-4 but can be done independently.

---

### Task 6: Add cost discipline section ✅ completed

**What:** Add a new `## Cost discipline` section at the end of the file, after the `## Important behaviors` section. This codifies the rules that maintain the cost savings of the scan/synthesize split over time.

**File:** `dev-workflow/skills/architect/SKILL.md`

**Location:** After the last line of the `## Important behaviors` section (currently the last section in the file, ending with "Consider the team..." bullet). Add the new section as the final section of the file.

**Before:** (the file ends with the `## Important behaviors` section)
```markdown
- **Consider the team.** Factor in the team's familiarity with technologies. A perfect architecture in an unfamiliar stack may be worse than a good-enough architecture in a known stack.
```

**After:** (append the following after the line above)
```markdown

## Cost discipline

The scan/synthesize split exists to avoid paying Opus rates for bulk file reading. Maintain this discipline:

- **Never read raw source files in the main Opus session for bulk exploration.** That is what scan agents are for. The only exception is targeted reads of specific files directly relevant to a specific synthesis question during Phase 2. Prefer reading individual files over spawning new scan agents for single-file needs.
- **Spawn scan agents per-repo, not per-file.** Each agent pays ~41K tokens of base overhead. A per-file agent for a 200-line file is pure waste.
- **Batch small repos.** If a repo has fewer than ~5 source files, batch it with another small repo into a single scan agent.
- **Use /discover output when available.** If `memory/repos-inventory.md` exists and the repo HEAD has not changed (check `memory/repo-heads.md`), the /discover output IS the scan. Do not re-scan.
- **Targeted re-scans during synthesis.** If Phase 2 reveals a gap in the scan findings (e.g., "I need to see the exact error handling in payment.service.ts"), read that specific file directly in the Opus session. Do NOT spawn a whole new scan agent for one file.
```

**Acceptance criteria:**
- `## Cost discipline` section exists as the final section of the file
- Contains all 5 bullet points (no bulk reads, per-repo agents, batch small repos, use /discover, targeted re-scans)
- The ~41K overhead figure is mentioned
- Targeted reads are scoped to specific files relevant to synthesis questions (no arbitrary line cap)
- The /discover + repo-heads.md integration is referenced

**Risk:** None. Additive change.

**Dependencies:** None, but logically belongs with Tasks 2-4.

---

## Implementation order and dependencies

```
Task 1 (frontmatter)     ─── independent, do first (trivial)
Task 2 (scan phase)      ─┐
Task 3 (remove old Ph2)  ─┼── implement together in one commit
Task 4 (synthesis phase) ─┘
Task 5 (renumber)        ─── do after Tasks 2-4
Task 6 (cost discipline) ─── do after Tasks 2-4
```

**Recommended implementation sequence:**

1. **Single commit:** Apply all 6 tasks in one commit. The file is only 149 lines and all changes are to the same file. There is no benefit to splitting into multiple commits — the intermediate states (e.g., Phase 2 deleted but Phase 3 not yet renamed) would leave the file in a broken state.

**Commit message:**
```
perf(architect): rewrite /architect with scan/synthesize split (C7)

Split the monolithic Opus /architect session into two phases:
Phase 1 scans repos in parallel using Sonnet subagents for structured
fact extraction. Phase 2 synthesizes findings on Opus for architectural
reasoning and design. Integrates with /discover output and repo-heads.md
to skip unchanged repos.

Expected savings: ~$0.95-4.48 per /architect invocation.
```

---

## Integration analysis

### How does this change interact with the rest of the workflow?

| Skill | Interaction | Risk |
|-------|-------------|------|
| `/discover` | **Strong positive.** The scan phase checks for /discover output (`repos-inventory.md`, `architecture-overview.md`, `dependencies-map.md`) and uses `repo-heads.md` to skip unchanged repos. If /discover has been run recently, scan agents are only spawned for changed or task-relevant repos. | Low. If /discover output format changes, the scan integration needs updating. But /discover output is defined in discover/SKILL.md and is stable. |
| `/plan` | **No interaction.** /plan reads `architecture.md` (the OUTPUT of /architect). The output format and structure are unchanged — only HOW it's produced changes. | None. |
| `/critic` | **No interaction.** /critic reviews the plan, not the architecture. It does its own codebase reads independently. | None. |
| `/thorough_plan` | **No interaction.** /thorough_plan orchestrates plan/critic/revise. /architect runs before /thorough_plan. | None. |
| `/review` | **No interaction.** /review examines implementation code, not architecture. | None. |
| `/implement` | **No interaction.** /implement follows the plan, which references architecture.md. No change to the contract. | None. |

### How does this interact with other Stage 1a changes?

| Stage 1a change | Interaction | Risk |
|-----------------|-------------|------|
| C5 (repo-heads.md in /discover) | **Strong positive.** C7 scan phase uses C5's repo-heads.md to skip unchanged repos, saving both the ~41K spawn overhead and the Sonnet scan cost for those repos. | None — C7 reads repo-heads.md in the same format C5 writes it. |
| C3 (skip lessons-learned in critic) | **None.** Different skills, different phases. | None. |
| C4 (diff-only review) | **None.** Different skills, different phases. | None. |
| C6 (lessons-learned pruning) | **Indirect positive.** Smaller lessons-learned means slightly smaller base overhead for scan subagents (lessons-learned is part of CLAUDE.md which is loaded by all agents). | Negligible. |

### How does this interact with Stage 2 (future)?

Stage 2 modifies `thorough_plan/SKILL.md` (B1, B3, E0 fix). This change modifies `architect/SKILL.md`. No file overlap, no merge conflicts. The two stages are independent.

---

## Risk assessment

| ID | Risk | Likelihood | Impact | Mitigation |
|----|------|-----------|--------|------------|
| R1 | Scan agents miss important context that a unified Opus pass would catch | Medium | Medium | (a) Scan template includes task-relevant code section. (b) Phase 2 can do targeted reads if findings are ambiguous. (c) /critic (Opus) runs later with full codebase access and catches scan-phase misses. |
| R2 | Subagent overhead (~41K tokens each) exceeds savings on small projects (1-2 repos) | Medium | Low | Minimum content threshold: only spawn agents for repos with >= 5 source files. For smaller repos, read directly in the main session or batch. On a 1-repo project, the overhead may not be justified — but even then, the scan runs on Sonnet (cheaper per token). |
| R3 | Scan output format inconsistent across agents | Low | Low | Strict numbered template with 5 explicit sections. Sonnet follows structured templates well. |
| R4 | Scan output too verbose, reducing synthesis savings | Low | Medium | Output size constraint (~3K-5K tokens per agent) in scan instructions. Combined findings for 5 repos: ~15-25K tokens vs 60-200K raw content. |
| R5 | Latency increase from spawning parallel agents | Low | Low | Agents run in parallel, so wall-clock time is max(agent_times). Sonnet is faster per token than Opus. Net latency should be similar or better. |
| R6 | /discover output stale but repo-heads.md shows HEAD unchanged (e.g., force-push that resets to same commit) | Very low | Low | Extremely unlikely edge case. User can force re-scan by saying "rescan all repos" or "ignore cached results." |
| R7 | Architecture quality degrades because synthesis lacks raw file context | Medium | High | This is the key quality risk. Mitigations: (a) Targeted reads for specific questions. (b) /critic catches gaps. (c) Quality comparison test (see Testing strategy). (d) Rollback plan if quality drops. |

---

## Testing strategy

Since this is a SKILL.md rewrite (no code, no automated tests), testing is behavioral:

### Test 1: Scan agents spawn on Sonnet
- **How:** Run `/architect` on a project with 3+ repos. Check `--verbose` output or stream-json for model changes between messages.
- **Pass:** Scan agents are spawned as subagents using Sonnet (not Opus). The main session remains on Opus.

### Test 2: Structured scan output
- **How:** Examine the scan agent outputs from Test 1.
- **Pass:** Each scan output has all 5 numbered sections (IDENTITY, STRUCTURE, EXTERNAL DEPENDENCIES, API SURFACE, TASK-RELEVANT CODE). Each output is within ~3K-5K tokens.

### Test 3: Synthesis uses findings, not raw files
- **How:** During the Test 1 run, check whether Phase 2 (synthesis) reads raw source files for repos that were scanned.
- **Pass:** Phase 2 does NOT do bulk file reads. At most, it does targeted reads of specific individual files when scan findings are ambiguous or insufficient for a synthesis question.

### Test 4: /discover integration — skip unchanged repos
- **How:** Run `/discover` first (populating `memory/repo-heads.md`). Then run `/architect` without changing any repo.
- **Pass:** No scan agents are spawned for repos whose HEAD matches `repo-heads.md`. The /discover output is used as scan input.

### Test 5: Quality comparison
- **How:** Run `/architect` on a project where a previous `architecture.md` exists (produced by the old unified approach). Compare the new output against the old.
- **Pass:** No significant information gaps in the new output. If gaps exist, verify they would be caught by a subsequent `/critic` run.

### Test 6: Small-repo batching
- **How:** Run `/architect` on a project that includes small repos (< 5 source files) alongside larger repos.
- **Pass:** Small repos are either batched into a single scan agent with another small repo, or read directly in the main session. They are NOT given their own dedicated scan agent.

---

## Rollback plan

If the scan/synthesize split degrades architecture quality:

1. **Immediate rollback:** Revert the commit. The old `architect/SKILL.md` is restored. Run `bash dev-workflow/install.sh` to push the reverted skill to `~/.claude/skills/`.

2. **Partial rollback — keep scan, increase verbosity:** If the issue is scan agents missing context (not a fundamental flaw), modify the scan agent instructions to increase the output constraint from ~3K-5K to ~8K-10K tokens. This doubles the scan cost but retains the Sonnet-vs-Opus savings.

3. **Diagnostic approach:** Before reverting, run one `/architect` session with `--verbose --output-format stream-json` to capture exactly what the scan agents produced and what the synthesis phase missed. Compare against a full Opus run on the same task. Use the diff to decide whether to fix the scan template or revert entirely.

**Rollback criteria:** If Test 5 (quality comparison) shows that the new approach consistently misses information that the old approach found, AND the misses are not caught by `/critic`, revert.

---

## Cost/benefit summary

**Per-invocation savings (3-5 repo project):**

| Component | Old cost (all Opus) | New cost (scan on Sonnet) | Savings |
|-----------|--------------------:|-------------------------:|--------:|
| File reading (60-200K tokens input) | $0.90-3.00 | $0.18-0.60 (Sonnet rates) | $0.72-2.40 |
| Scan agent overhead (3-5 agents x ~41K tokens) | $0 | $0.37-0.62 (Sonnet base overhead) | -$0.37 to -$0.62 |
| Synthesis input (structured findings vs raw files) | included above | $0.15-0.30 (10-20K tokens at Opus) | $0.60-2.70 (reduced from 60-200K to 10-20K at Opus rates) |
| **Net savings** | | | **~$0.95-4.48** |

**Note on rates:** Dollar figures use published API rates ($15/M Opus, $3/M Sonnet). If the billing tier applies a discount (as observed in Stage 0 baseline -- ~3x lower than published rates), absolute dollar savings would be proportionally lower. The percentage reduction (39-59%) is rate-independent.

**Weekly savings:** For a project running `/architect` 2-3 times/week: ~$2-13/week (at published rates; see note above).

**With /discover integration (C5):** If unchanged repos are skipped entirely, the savings increase further — no scan agent overhead for those repos. On subsequent runs where only 1 of 5 repos changed, the scan cost drops to ~$0.12-0.15 (one agent) instead of ~$0.55-1.22 (five agents).
