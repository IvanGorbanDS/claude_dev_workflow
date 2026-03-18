---
name: thorough_plan
description: "Orchestrates the full plan→critic→revise cycle for thorough implementation planning using the strongest model (Opus). Use this skill for: /thorough_plan, 'plan this thoroughly', 'detailed plan with review', 'plan and critique', 'full planning cycle'. Runs /plan to create the initial plan, then /critic in a fresh session for unbiased review, then /revise to address issues — repeating up to 5 rounds until convergence. Use this when you want the highest-quality plan, not just a quick one."
model: opus
---

# Thorough Plan — Orchestrator

This skill orchestrates the planning convergence loop by invoking three sub-skills in sequence: `/plan`, `/critic`, and `/revise`. It does not do the planning, critiquing, or revising itself — it coordinates the agents that do.

## Setup

### 1. Determine the task subfolder

Before starting the loop, establish the working directory:

- Ask the user for a descriptive name if not obvious
- Use kebab-case: `auth-refactor`, `payment-migration`, `api-v2-endpoints`
- Create the folder: `<project-folder>/<task-name>/`

### 2. Gather initial context

Collect and pass to `/plan`:

- The user's description of what needs to be built
- Path to `architecture.md` if `/architect` was run first
- Paths to all relevant repositories in the project folder
- Any constraints, preferences, or context the user mentioned

## The loop

```
Round 1:
  /plan    → produces current-plan.md
  /critic  → (FRESH SESSION) reads plan + code → produces critic-response-1.md

  If verdict = PASS → done
  If verdict = REVISE → continue

Round 2:
  /revise  → reads critic-response-1.md → updates current-plan.md
  /critic  → (FRESH SESSION) reads updated plan + code → produces critic-response-2.md

  If verdict = PASS → done
  If verdict = REVISE → continue

...repeat up to Round 5
```

### Invoking each agent

**`/plan` (Round 1 only)**
- Invoke with the strongest model (Opus)
- Pass all context: architecture docs, user requirements, repo paths
- Output: `<task-folder>/current-plan.md`

**`/critic` (every round)**
- **MUST spawn as a new agent session** — fresh context is essential for unbiased critique
- Pass: path to `current-plan.md`, path to the project folder (so it can read actual code)
- Output: `<task-folder>/critic-response-<round>.md`

**`/revise` (rounds 2+)**
- Invoke in the original session context (it needs to understand the plan's intent)
- Pass: path to `current-plan.md`, path to latest `critic-response-<N>.md`
- Output: updated `current-plan.md` (in place)

### Convergence rules

The loop stops when ANY of these is true:

1. **Critic gives PASS** — no CRITICAL or MAJOR issues. Plan is ready.
2. **5 rounds reached** — inform the user of remaining issues. The plan may have inherent constraints.
3. **Stuck in a loop** — the critic flags the same issues repeatedly despite revisions. Escalate to the user — this usually means a requirement is ambiguous or there's a genuine tradeoff to decide.

### Between rounds

After each critic round, before continuing:

- Read the critic response yourself (as orchestrator)
- Check if the same issues keep appearing (loop detection)
- Briefly inform the user: "Round N complete — critic found X critical, Y major issues. Proceeding to revise." or "Round N complete — critic passed. Plan is ready."

## Final output

When converged, add a convergence summary to the top of `current-plan.md`:

```markdown
## Convergence Summary
- **Rounds:** <N>
- **Final verdict:** PASS
- **Key revisions:** <what the main themes of revision were across rounds>
- **Remaining concerns:** <any MINOR issues not addressed, or none>
```

Then run `/gate` to present automated checks and a summary to the user.

After the gate, inform the user:
- The plan is ready at `<task-folder>/current-plan.md`
- Summary of what was planned (high-level, 3-5 bullet points)
- How many rounds it took and what the main themes were
- Any remaining concerns or decisions the user needs to make

**STOP HERE.** Do NOT invoke `/implement`. Do NOT offer to start implementing. The user must explicitly type `/implement` to proceed. This is a hard rule — implementation requires a conscious human decision.

## File structure at completion

```
<project-folder>/<task-name>/
├── architecture.md          (from /architect, if exists)
├── current-plan.md          (final converged plan)
├── critic-response-1.md     (round 1 critic)
├── critic-response-2.md     (round 2 critic, if needed)
├── ...
└── critic-response-N.md     (final round critic)
```

## Important behaviors

- **You are the orchestrator, not the planner.** Don't produce plan content yourself — invoke `/plan`, `/critic`, `/revise`.
- **Critic MUST be a fresh session.** This is non-negotiable. Same-agent critique is biased and weak.
- **Keep the user informed.** Brief status updates between rounds. Don't go silent for 10 minutes.
- **Detect loops early.** If round 3's critic response looks like round 1's, stop and involve the user.
- **Pass context explicitly.** Each agent starts with limited knowledge. Give them the file paths and repo locations they need.
