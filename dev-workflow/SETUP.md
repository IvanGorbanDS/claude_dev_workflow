# Development Workflow — Setup Guide

## Install (two steps total)

### Step 1 — User-level setup (once per machine)

```bash
bash /path/to/dev-workflow/install.sh
```

Installs skills to `~/.claude/skills/` and writes workflow rules to `~/.claude/CLAUDE.md`. Safe to re-run — updates everything idempotently.

### Step 2 — Project setup (once per project, no bash needed)

```bash
cd /path/to/your/project
claude
# then type: /init_workflow
```

`/init_workflow` handles all project scaffolding: creates `memory/`, configures `.claude/settings.json` permissions, runs `/discover`, and generates `QUICKSTART.md`.

---

## What the script does

**`install.sh` — user-level, run once per machine:**
1. **Copies skills** — all 16 skills into `~/.claude/skills/` (globally available in every project)
2. **Writes workflow rules** — appends shared rules to `~/.claude/CLAUDE.md` (auto-loaded by Claude Code everywhere)

**`/init_workflow` — run once per project inside Claude:**
3. **Configures permissions** — creates `.claude/settings.json` with allow/deny lists
4. **Creates memory structure** — `memory/` at project root with `sessions/`, `daily/`, `weekly/` and template files
5. **Runs /discover** — scans repos and populates memory
6. **Generates QUICKSTART.md** — command reference card in `dev-workflow/`

## Prerequisites

- **Claude Code** installed (`claude` command available)
- **Git** installed
- **gh** (GitHub CLI) — optional, for PR creation later

## Manual Installation (if you prefer)

The script is the recommended path — it handles idempotent updates and edge cases. For reference, here's what it does manually:

### 1. Install skills (user-level, once)
```bash
mkdir -p ~/.claude/skills
for skill in /path/to/dev-workflow/skills/*/; do
  name=$(basename "$skill")
  cp -r "$skill" ~/.claude/skills/$name
done
```

### 2. Write workflow rules (user-level, once)
```bash
echo "" >> ~/.claude/CLAUDE.md
echo "# === DEV WORKFLOW START ===" >> ~/.claude/CLAUDE.md
cat /path/to/dev-workflow/CLAUDE.md >> ~/.claude/CLAUDE.md
echo "# === DEV WORKFLOW END ===" >> ~/.claude/CLAUDE.md
```

### 3. Create project memory structure
```bash
cd ~/projects/my-app
mkdir -p memory/sessions memory/daily memory/weekly
```

### 4. Initialize
```bash
claude
# then type: /init_workflow
```

## Result

After installation, your project looks like:
```
~/.claude/
├── CLAUDE.md                ← workflow rules (auto-loaded everywhere)
└── skills/                  ← all 16 workflow skills (global)
    ├── discover/
    ├── architect/
    ├── plan/
    ├── critic/
    ├── revise/
    ├── thorough_plan/
    ├── gate/
    ├── implement/
    ├── review/
    ├── rollback/
    ├── end_of_task/
    ├── end_of_day/
    ├── start_of_day/
    ├── init_workflow/
    ├── weekly_review/
    └── capture_insight/

~/projects/my-app/
├── .claude/
│   └── settings.json        ← project permissions
├── CLAUDE.md                ← project-specific rules
├── memory/                  ← project memory (project root)
│   ├── sessions/
│   ├── daily/
│   ├── weekly/
│   ├── lessons-learned.md
│   ├── workflow-rules.md
│   ├── workflow-suggestions.md
│   └── ... (populated by /discover)
├── dev-workflow/
│   ├── QUICKSTART.md        ← command reference
│   ├── SETUP.md             ← this file
│   ├── Workflow-User-Guide.html
│   └── install.sh           ← the installer
├── service-a/               ← your repos
├── service-b/
└── frontend/
```

## Daily Usage

```bash
cd ~/projects/my-app && claude
```

| You want to... | Type |
|---|---|
| Start your day | `/start_of_day` |
| Plan a big feature | `/architect` then `/thorough_plan` |
| Fix a bug | `/plan` then `/implement` |
| Review implementation | `/review` |
| Ship it | `/end_of_task` |
| Wrap up for the day | `/end_of_day` |

## Updating the workflow

```bash
cd /path/to/claude_dev_workflow
git pull
bash dev-workflow/install.sh
```

Skills and `~/.claude/CLAUDE.md` are updated. Project `memory/` is never touched.

## Migrating a legacy project

If your project has the old layout (`dev-workflow/memory/` instead of `memory/` at root):

```bash
cd /path/to/legacy-project
claude
# type: /init_workflow
```

`/init_workflow` detects the legacy layout and offers to migrate automatically. It moves `dev-workflow/memory/` → `memory/`, cleans up old `.claude/skills/` symlinks, and optionally removes the now-unused `dev-workflow/skills/` directory. Your accumulated knowledge is fully preserved.

## Troubleshooting

**Skills not recognized:** check that skills are in `~/.claude/skills/` — `ls ~/.claude/skills/` should list all 16 skills. Re-run `bash install.sh` to reinstall them.

**Claude doesn't follow workflow rules:** check that `~/.claude/CLAUDE.md` contains the dev-workflow section (look for `# === DEV WORKFLOW START ===`). Re-run `bash install.sh` to rewrite it.

**/discover finds nothing:** your repos need to be git repositories (each has a `.git/` folder) inside the project root.

**Context filling up:** normal — each heavy command works best in its own chat session. The file-based memory carries state between sessions.
