---
name: init_workflow
description: "Initializes the development workflow in a project folder. Creates the memory/ structure, runs /discover to scan the codebase, and generates a quickstart guide. Requires install.sh to have been run first (installs skills to ~/.claude/skills/ and workflow rules to ~/.claude/CLAUDE.md). Use this skill for: /init_workflow, 'initialize workflow', 'set up dev workflow', 'install workflow', 'bootstrap workflow'. Run this once per project."
model: opus
---

# Initialize Development Workflow

You set up the complete development workflow system in a project folder. This is the one-time bootstrap that makes all workflow commands available for a project.

## When to use

- First time setting up the workflow in a new project
- User says `/init_workflow`, "set up the workflow", "initialize", etc.
- A project folder exists but has no `dev-workflow/` structure yet

## Prerequisites

`install.sh` must have been run first. It installs skills to `~/.claude/skills/` and writes workflow rules to `~/.claude/CLAUDE.md`. This skill handles per-project initialization only — not the one-time machine setup.

## Process

### Step 1: Ensure project is initialized with `/init`

Check if the project has a `CLAUDE.md` file at its root. If it does NOT exist:

1. **STOP** and tell the user:
   > "This project hasn't been initialized with Claude Code yet. Please run `/init` first to create a `CLAUDE.md`, then re-run `/init_workflow`."
2. Do not proceed with subsequent steps. The `/init` command sets up the project-level `CLAUDE.md` and `.claude/` directory that the workflow depends on.

If `CLAUDE.md` already exists, skip this step — the project is already initialized. Proceed to Step 2.

This ensures the standard Claude Code foundation is in place before layering on the dev-workflow setup.

### Step 2: Detect project root

Identify the project root. This is typically:
- The current working directory
- Or the folder the user specified

Confirm with the user if ambiguous:
> "I'll set up the workflow in `<path>`. Is this the right project root?"

### Step 3: Check for existing setup and detect legacy layout

**Legacy detection:** Check for `dev-workflow/memory/` — this is the old layout where memory was nested inside dev-workflow. If found:

```
⚠️  Legacy layout detected: dev-workflow/memory/ exists.
    The new layout keeps memory/ at the project root.
    I can migrate it now: move dev-workflow/memory/ → memory/
    Your accumulated knowledge (lessons, sessions, etc.) will be preserved.
    Migrate now? (yes/no)
```

If the user confirms, run:
```bash
mv dev-workflow/memory memory
```

If `memory/` already exists at root (partial migration), merge by copying missing files only — never overwrite existing ones.

**Old symlinks cleanup:** Check for `.claude/skills/` containing symlinks into `dev-workflow/skills/`. If found, remove them — skills are now global at `~/.claude/skills/`:
```bash
for f in .claude/skills/*/; do
  [ -L "${f%/}" ] && rm "${f%/}"
done
```

**Old skills directory:** If `dev-workflow/skills/` exists, it is no longer needed. Offer to remove it:
```
dev-workflow/skills/ is no longer needed (skills live at ~/.claude/skills/).
Remove it? (yes/no)
```

**Re-init of current layout:** If `memory/` already exists at the project root, tell the user:
> "This project already has a memory/ setup. Re-initializing will preserve all memory files. Continue?"

**Never overwrite memory/.** It contains accumulated knowledge.

### Step 4: Configure Claude Code permissions

Create or update `.claude/settings.json` at the project root to allow workflow tool usage and deny destructive commands:

```bash
mkdir -p .claude
```

Then write `.claude/settings.json` using python3 (merge with existing if present):

```python
import json, os

path = ".claude/settings.json"
settings = json.load(open(path)) if os.path.exists(path) else {}

perms = settings.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
deny = perms.setdefault("deny", [])

for p in ["Read", "Glob", "Grep", "Bash(*)", "WebFetch", "WebSearch"]:
    if p not in allow: allow.append(p)

for p in [
    "Bash(rm:*)", "Bash(rm -rf:*)", "Bash(rmdir:*)",
    "Bash(git push --force:*)", "Bash(git push -f:*)",
    "Bash(git reset --hard:*)", "Bash(git clean -f:*)", "Bash(git clean -fd:*)",
    "Bash(git checkout -- .:*)", "Bash(git branch -D:*)",
    "Bash(chmod:*)", "Bash(chown:*)", "Bash(kill -9:*)",
    "Bash(killall:*)", "Bash(mkfs:*)", "Bash(dd:*)"
]:
    if p not in deny: deny.append(p)

json.dump(settings, open(path, "w"), indent=2)
```

Run this with `python3 -c "..."` or write the file directly if python3 is unavailable. Tell the user what was configured.

### Step 5: Create the directory structure

Create the memory structure at the project root (not inside dev-workflow/):

```
<project-root>/
├── memory/
│   ├── sessions/                  ← per-session state files
│   ├── daily/                     ← daily rollup from /end_of_day
│   ├── weekly/                    ← weekly rollup from /weekly_review
│   ├── repos-inventory.md         ← filled by /discover
│   ├── architecture-overview.md   ← filled by /discover
│   ├── dependencies-map.md        ← filled by /discover
│   ├── git-log.md                 ← filled by /discover, updated by /end_of_day
│   ├── lessons-learned.md         ← accumulates over time
│   ├── workflow-rules.md          ← workflow memory for Claude
│   └── workflow-suggestions.md   ← Tier 3 insight suggestions
└── dev-workflow/
    ├── QUICKSTART.md              ← command reference (generated here)
    ├── SETUP.md
    ├── Workflow-User-Guide.html
    └── install.sh
```

Skills are already at `~/.claude/skills/` (installed by `install.sh`). Do not create a `skills/` directory in the project.

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
- `memory/workflow-rules.md` — copy from `dev-workflow/memory/workflow-rules.md` if it exists in the source, or create with header:
  ```markdown
  # Workflow Rules

  Reference summary of the dev-workflow system for Claude.
  See ~/.claude/CLAUDE.md for the full rules.
  ```
- `memory/workflow-suggestions.md` — create with the template header:
  ```markdown
  # Workflow Suggestions

  Suggestions for improvements to the dev-workflow itself, surfaced during project work.
  These are Tier 3 insights — things that would benefit the workflow repo, not just this project.

  **Claude writes here automatically.** You decide whether to apply changes to the workflow repo manually.
  Review suggestions, then update the Status field: `accepted | rejected | deferred`.

  <!-- Entry format:
  ## <YYYY-MM-DD> — <source-task>
  **Suggestion:** <what should change in the workflow>
  **Why:** <the observation that triggered this>
  **Affects:** <which SKILL.md file or CLAUDE.md section>
  **Status:** surfaced
  -->
  ```
- `memory/repos-inventory.md` — create empty, will be populated by /discover
- `memory/architecture-overview.md` — create empty, will be populated by /discover
- `memory/dependencies-map.md` — create empty, will be populated by /discover
- `memory/git-log.md` — create empty, will be populated by /discover

### Step 6: Run /discover

Automatically invoke `/discover` to scan all repositories in the project folder. This populates:
- `memory/repos-inventory.md`
- `memory/architecture-overview.md`
- `memory/dependencies-map.md`
- `memory/git-log.md`

Tell the user:
> "Running /discover to scan your codebase..."

If /discover finds no repos (no git repositories in the project folder), that's fine — the memory files stay empty and will be populated when repos are added.

### Step 7: Generate quickstart guide

The `Workflow-User-Guide.html` should already be part of the copied files. Confirm it's in place.

Additionally, generate a concise `QUICKSTART.md` in the `dev-workflow/` folder:

```markdown
# Development Workflow — Quickstart

## Your commands

| Command | What it does |
|---------|-------------|
| `/init_workflow` | One-time project bootstrap — creates memory/, configures permissions, runs /discover |
| `/discover` | Scans all repos, maps architecture and dependencies |
| `/architect` | Designs solution architecture for a feature/change |
| `/thorough_plan` | Creates detailed implementation plan (with critic review) |
| `/implement` | Writes code from the plan (explicit command only) |
| `/review` | Verifies implementation against the plan |
| `/end_of_task` | Pushes branch, captures lessons (explicit command only) |
| `/rollback` | Safely undoes implementation work |
| `/gate` | Quality checkpoint (runs automatically between phases) |
| `/start_of_day` | Morning briefing — restores context |
| `/end_of_day` | Saves session state, promotes captured insights |
| `/weekly_review` | Aggregates the week's progress into a structured review |
| `/capture_insight` | Logs a pattern or gotcha to the daily scratchpad |

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

- `~/.claude/CLAUDE.md` — shared rules all skills follow (user-level)
- `memory/` — accumulated knowledge (repos, architecture, lessons, sessions)
- `~/.claude/skills/` — all workflow skill definitions (user-level)
- `Workflow-User-Guide.html` — detailed interactive guide with scenarios

## First time?

Open `Workflow-User-Guide.html` in your browser for a full walkthrough with example conversations.
```

### Step 8: Report

Tell the user:

```
Workflow initialized in <project-root>/dev-workflow/

📁 Structure created:
  - memory/ (repos, architecture, dependencies, lessons, sessions)
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
