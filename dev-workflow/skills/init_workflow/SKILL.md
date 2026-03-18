---
name: init_workflow
description: "Initializes the development workflow in any project folder. Copies all skills, memory structure, and CLAUDE.md, runs /discover to scan the codebase, and generates a quickstart guide. Use this skill for: /init_workflow, 'initialize workflow', 'set up dev workflow', 'install workflow', 'bootstrap workflow'. Run this once when starting to use the workflow in a new project."
model: opus
---

# Initialize Development Workflow

You set up the complete development workflow system in a project folder. This is the one-time bootstrap that makes all workflow commands available for a project.

## When to use

- First time setting up the workflow in a new project
- User says `/init_workflow`, "set up the workflow", "initialize", etc.
- A project folder exists but has no `dev-workflow/` structure yet

## Prerequisites

The workflow skill files must already be installed in Claude Code's skill directories (either globally at `~/.claude/skills/` or locally in the project's `.claude/skills/`). This skill handles project-specific initialization — not Claude Code installation.

## Process

### Step 1: Detect project root

Identify the project root. This is typically:
- The current working directory
- Or the folder the user specified

Confirm with the user if ambiguous:
> "I'll set up the workflow in `<path>`. Is this the right project root?"

### Step 2: Check for existing setup

Look for an existing `dev-workflow/` folder:
- If it exists and has content, warn the user:
  > "This project already has a dev-workflow/ setup. Re-initializing will overwrite CLAUDE.md and skill references but preserve memory/. Continue?"
- If the `memory/` folder exists, **never overwrite it** — it contains accumulated knowledge.

### Step 3: Create the directory structure

Create the full structure:

```
<project-root>/dev-workflow/
├── CLAUDE.md                      ← shared rules (copy from source)
├── memory/
│   ├── sessions/                  ← per-session state files
│   ├── daily/                     ← daily rollup from /end_of_day
│   ├── repos-inventory.md         ← filled by /discover
│   ├── architecture-overview.md   ← filled by /discover
│   ├── dependencies-map.md        ← filled by /discover
│   ├── git-log.md                 ← filled by /discover, updated by /end_of_day
│   ├── lessons-learned.md         ← accumulates over time
│   └── workflow-rules.md          ← workflow memory for Claude
├── skills/                        ← all skill folders (symlinked or copied)
│   ├── discover/SKILL.md
│   ├── architect/SKILL.md
│   ├── plan/SKILL.md
│   ├── critic/SKILL.md
│   ├── revise/SKILL.md
│   ├── thorough_plan/SKILL.md
│   ├── gate/SKILL.md
│   ├── implement/SKILL.md
│   ├── review/SKILL.md
│   ├── rollback/SKILL.md
│   ├── end_of_task/SKILL.md
│   ├── end_of_day/SKILL.md
│   ├── start_of_day/SKILL.md
│   └── init_workflow/SKILL.md
└── Workflow-User-Guide.html       ← interactive guide
```

For files that should start empty but exist as placeholders:
- `memory/lessons-learned.md` — create with the template header:
  ```markdown
  # Lessons Learned

  Accumulated insights from completed tasks. Read by /plan and /critic at the start of every session.

  <!-- Add entries using the format:
  ## <date> — <task-name>
  **What happened:** <the surprise, failure, or insight>
  **Lesson:** <the reusable takeaway>
  **Applies to:** <which skills should pay attention>
  -->
  ```
- `memory/repos-inventory.md` — create empty, will be populated by /discover
- `memory/architecture-overview.md` — create empty, will be populated by /discover
- `memory/dependencies-map.md` — create empty, will be populated by /discover
- `memory/git-log.md` — create empty, will be populated by /discover

### Step 4: Run /discover

Automatically invoke `/discover` to scan all repositories in the project folder. This populates:
- `memory/repos-inventory.md`
- `memory/architecture-overview.md`
- `memory/dependencies-map.md`
- `memory/git-log.md`

Tell the user:
> "Running /discover to scan your codebase..."

If /discover finds no repos (no git repositories in the project folder), that's fine — the memory files stay empty and will be populated when repos are added.

### Step 5: Generate quickstart guide

The `Workflow-User-Guide.html` should already be part of the copied files. Confirm it's in place.

Additionally, generate a concise `QUICKSTART.md` in the `dev-workflow/` folder:

```markdown
# Development Workflow — Quickstart

## Your commands

| Command | What it does |
|---------|-------------|
| `/discover` | Scans all repos, maps architecture and dependencies |
| `/architect` | Designs solution architecture for a feature/change |
| `/thorough_plan` | Creates detailed implementation plan (with critic review) |
| `/implement` | Writes code from the plan (explicit command only) |
| `/review` | Verifies implementation against the plan |
| `/end_of_task` | Pushes branch, captures lessons (explicit command only) |
| `/rollback` | Safely undoes implementation work |
| `/start_of_day` | Morning briefing — restores context |
| `/end_of_day` | Saves session state, consolidates work |
| `/gate` | Quality checkpoint (runs automatically between phases) |

## Typical flows

**Large feature:**
`/discover` → `/architect` → `/thorough_plan` → `/implement` → `/review` → `/end_of_task`

**Bug fix:**
`/plan` → `/implement` → `/review` → `/end_of_task`

**Starting your day:**
`/start_of_day`

**Ending your day:**
`/end_of_day`

## Key rules

1. **`/implement` and `/end_of_task` never run automatically.** You must type them.
2. **Quality gates run between every phase.** Claude stops and asks for your approval.
3. **Each heavy command works best in its own chat session.** Context windows fill up — the file artifacts are the shared memory.
4. **`/end_of_task` pushes the branch only.** Create your PR separately when ready.
5. **Lessons accumulate.** The more you use the workflow, the smarter it gets about your codebase.

## Files

- `CLAUDE.md` — shared rules all skills follow
- `memory/` — accumulated knowledge (repos, architecture, lessons, sessions)
- `skills/` — all workflow skill definitions
- `Workflow-User-Guide.html` — detailed interactive guide with scenarios

## First time?

Open `Workflow-User-Guide.html` in your browser for a full walkthrough with example conversations.
```

### Step 6: Report

Tell the user:

```
Workflow initialized in <project-root>/dev-workflow/

📁 Structure created:
  - CLAUDE.md (shared rules)
  - memory/ (repos, architecture, dependencies, lessons, sessions)
  - skills/ (13 workflow commands)
  - Workflow-User-Guide.html (interactive guide)
  - QUICKSTART.md (command reference)

🔍 /discover completed:
  - Found <N> repositories
  - <brief summary of what was found>

Ready to go. Start with:
  - /start_of_day — if resuming existing work
  - /architect — if starting a new feature
  - /plan or /thorough_plan — if you know what to build
  - Open Workflow-User-Guide.html for full scenarios
```

## Important behaviors

- **Never overwrite memory/.** If re-initializing, preserve all memory files. They contain accumulated knowledge.
- **Run /discover automatically.** Don't ask — just run it as part of init. The user expects a ready-to-use setup.
- **Keep it fast.** This should feel like a quick bootstrap, not a long ceremony.
- **The quickstart goes in the project folder.** Not buried in skills/ — the user should see it immediately.
