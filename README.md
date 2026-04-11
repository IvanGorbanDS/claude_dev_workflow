# Claude Dev Workflow

A structured, multi-agent development workflow for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). It turns Claude into a disciplined engineering partner with planning, architecture review, quality gates, and institutional memory.

## How It Works

The workflow breaks complex development tasks into discrete phases, each handled by a specialized skill with built-in quality gates between them:

```
/discover  -->  /architect  -->  GATE  -->  /thorough_plan  -->  GATE  -->  /implement  -->  GATE  -->  /review  -->  GATE  -->  /end_of_task
```

**You stay in control.** `/implement` and `/end_of_task` never run automatically — you explicitly decide when to write code and when to ship.

## Skills

| Skill | Purpose | Model |
|-------|---------|-------|
| `/init_workflow` | Bootstrap the workflow in a new project | Opus |
| `/discover` | Scan repos, map architecture and dependencies | Opus |
| `/architect` | Design solution architecture for a feature | Opus |
| `/thorough_plan` | Create detailed plan with critic review loop | Opus |
| `/plan` | Generate implementation plan | Opus |
| `/critic` | Review plan against actual codebase | Opus |
| `/revise` | Address critic feedback, update plan | Opus |
| `/implement` | Write code and tests from the plan | Sonnet |
| `/review` | Verify implementation against the plan | Opus |
| `/gate` | Quality checkpoint (runs between phases) | Sonnet |
| `/end_of_task` | Commit, push branch, capture lessons | Sonnet |
| `/rollback` | Safely undo implementation work | Sonnet |
| `/start_of_day` | Restore context, check git state | Sonnet |
| `/end_of_day` | Save session state, consolidate work | Sonnet |
| `/weekly_review` | Aggregate week's progress into a review | Sonnet |
| `/capture_insight` | Log a pattern or gotcha to the daily scratchpad | Sonnet |

## Installation

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- Git
- GitHub CLI (`gh`) — optional, for PR creation

### Step 1 — Clone this repo and run the installer (once per machine)

```bash
git clone https://github.com/IvanGorbanDS/claude_dev_workflow.git
bash claude_dev_workflow/dev-workflow/install.sh
```

This is a one-time user-level setup that:
1. Copies all 16 skills to `~/.claude/skills/` — available in every project
2. Writes workflow rules to `~/.claude/CLAUDE.md` — auto-loaded by Claude Code everywhere

Re-running is safe — it updates skills and rules idempotently.

### Step 2 — Scaffold each project with `/init_workflow`

```bash
cd /path/to/your/project
claude
```

Then type:
```
/init_workflow
```

This handles all project-level setup:
- Creates `memory/` at the project root with sessions, daily, weekly dirs and template files
- Configures `.claude/settings.json` permissions
- Runs `/discover` to scan your repos and populate memory
- Generates `dev-workflow/QUICKSTART.md`

## Scenarios

### New machine — first time setup
```bash
git clone https://github.com/IvanGorbanDS/claude_dev_workflow.git
bash claude_dev_workflow/dev-workflow/install.sh
```
Then for each project: `cd project && claude` → `/init_workflow`

### Update the workflow (new version available)
```bash
cd claude_dev_workflow
git pull
bash dev-workflow/install.sh
```
Skills and `~/.claude/CLAUDE.md` are updated. Project `memory/` is never touched.

### New project
```bash
cd /path/to/new-project
claude
```
Type `/init_workflow`. It creates `memory/`, configures permissions, runs `/discover`, and generates the quickstart.

### Legacy project (old layout: memory inside dev-workflow/)
```bash
cd /path/to/legacy-project
claude
```
Type `/init_workflow`. It detects the old `dev-workflow/memory/` layout, offers to move it to the project root, and cleans up old symlinks in `.claude/skills/`. Your accumulated knowledge is fully preserved.

### New machine, existing projects already set up
```bash
bash claude_dev_workflow/dev-workflow/install.sh
```
That's all. Skills and rules are installed globally. Existing projects already have `memory/` at their root — no further action needed. Just `cd project && claude` and work.

### Team member joining
Same as new machine. Clone the workflow repo, run `install.sh`. Each project's `memory/` is in the project repo (or not — depending on your `.gitignore`). `/init_workflow` can re-scaffold any project that's missing its memory structure.

---

## Typical Flows

**Large feature:**
```
/discover -> /architect -> /thorough_plan -> /implement -> /review -> /end_of_task
```

**Bug fix:**
```
/plan -> /implement -> /review -> /end_of_task
```

**Daily routine:**
```
/start_of_day    # morning — restores context
/end_of_day      # evening — saves state, promotes captured insights
```

## Key Concepts

### Quality Gates

Gates run automatically between phases. They perform automated checks (tests, lint, no debug code, no secrets) and require your explicit approval before proceeding.

### Session Independence

Each skill is designed to work in its own chat session. Context windows fill up — this is expected. File-based artifacts (`current-plan.md`, `architecture.md`, session state) are the shared memory between sessions.

### Three-Tier Memory

The workflow accumulates knowledge at three levels:

- **Tier 1 — Daily scratchpad** (`memory/daily/insights-<date>.md`): Claude writes here automatically during task work — patterns, gotchas, decision rationale. Use `/capture_insight` to log something explicitly.
- **Tier 2 — Project long-term** (`memory/lessons-learned.md`): Promoted from Tier 1 at `/end_of_day` with your confirmation. Planning and review skills read this automatically to avoid repeating past mistakes.
- **Tier 3 — Workflow-wide** (`memory/workflow-suggestions.md`): Insights about the workflow itself. Surfaced at `/end_of_day` for you to apply to the workflow repo manually.

### Plan-Critic-Revise Loop

`/thorough_plan` orchestrates a convergence loop: `/plan` creates the initial plan, `/critic` reviews it against the actual codebase, `/revise` addresses feedback. Repeats up to 5 rounds until the plan is solid.

## Project Structure After Install

```
~/.claude/                       <- user-level (shared across all projects)
├── CLAUDE.md                    <- workflow rules (auto-loaded everywhere)
└── skills/                      <- all 16 workflow skills

your-project/
├── .claude/
│   └── settings.json            <- project permissions
├── CLAUDE.md                    <- project-specific rules
├── memory/                      <- project memory (at project root)
│   ├── sessions/                <- per-session task state
│   ├── daily/                   <- daily rollups + insight scratchpads
│   ├── weekly/                  <- weekly reviews
│   ├── lessons-learned.md       <- accumulated project insights
│   ├── workflow-suggestions.md  <- workflow improvement suggestions
│   └── ...                      <- populated by /discover
├── dev-workflow/
│   ├── QUICKSTART.md            <- command reference
│   ├── SETUP.md                 <- detailed setup guide
│   ├── Workflow-User-Guide.html <- interactive guide
│   └── install.sh               <- the installer
├── service-a/                   <- your repos
├── service-b/
└── frontend/
```

## Updating

Re-run the installer to update skills and rules. Your `memory/` is never touched:

```bash
bash /path/to/claude_dev_workflow/dev-workflow/install.sh
```

## License

MIT
