---
name: end_of_day
description: "Saves the current session state and consolidates unfinished work into a daily cache for next-day resumption. Use this skill for: /end_of_day, 'wrapping up', 'done for the day', 'save my progress', 'end of day', 'EOD'. Captures what was worked on, what's unfinished, blockers, decisions made, and recent git activity. The daily cache feeds into /start_of_day for seamless resumption."
model: sonnet
---

# End of Day

You wrap up the current session and consolidate unfinished work into a daily cache that `/start_of_day` can restore tomorrow.

## How sessions and daily caches work

```
memory/
├── sessions/
│   ├── 2026-03-17-auth-refactor.md       ← individual session states
│   ├── 2026-03-17-payment-migration.md
│   └── 2026-03-18-auth-refactor.md
├── daily/
│   ├── 2026-03-17.md                      ← daily rollup (from end_of_day)
│   └── 2026-03-18.md
├── git-log.md                             ← rolling log of recent commits
├── repos-inventory.md
├── architecture-overview.md
└── dependencies-map.md
```

Multiple sessions can run in a day (parallel tasks, or revisiting a task). Each session writes its own state file. `/end_of_day` reads ALL session files for today, picks out the unfinished ones, and rolls them into one daily cache.

## Process

### Step 1: Save current session state

Create or update a session file at:
```
memory/sessions/<date>-<task-name>.md
```

The session file captures:

```markdown
# Session: <task-name>
**Date:** <YYYY-MM-DD>
**Status:** in_progress | completed | blocked

## What was worked on
<Brief description of what this session accomplished>

## Current stage
<Which workflow step we're at: architect / plan / critic / revise / implement / review>
**Round:** <if in critic-revise loop, which round>

## Completed in this session
- <specific things done — tasks implemented, files created, reviews passed>

## Unfinished work
- <what remains — specific tasks, next steps>
- <where exactly to pick up: file paths, task numbers, branch names>

## Decisions made
- <important decisions and their rationale — these are easy to forget overnight>

## Blockers
- <anything blocking progress — waiting on someone, unclear requirement, technical issue>

## Key context
- <branch name>
- <relevant file paths>
- <open PR URLs if any>
- <environment or config notes>

## Recent commits in this session
<list of commits made during this session with their messages and what they did>
```

### Step 2: Update git-log.md

Scan all repos in the project folder and update `memory/git-log.md` with recent commits. This is a rolling window — keep the last ~50 commits across all repos, newest first.

```markdown
# Recent Git Activity

Last updated: <datetime>

## <repo-name>
### <branch-name>
- `<short-hash>` <commit message> — <date>
  <1-line summary of what the commit actually changed and why>
- `<short-hash>` <commit message> — <date>
  <1-line summary>

## <other-repo>
...
```

To build this:
```bash
# For each repo directory
git -C <repo-path> log --all --oneline --date=short --format="%h %s — %ad" -20
```

Then for each commit, briefly describe what it changed (read the diff summary, not the full diff):
```bash
git -C <repo-path> diff-tree --no-commit-id --name-status -r <hash>
```

The goal is to capture the *logic* of recent changes — not just file lists but *why* things changed. This helps `/start_of_day` and `/architect` understand momentum and recent direction.

### Step 3: Produce the daily cache

Read all session files for today from `memory/sessions/<today>-*.md`. For each:
- If status is `completed` → note it as done, no action needed
- If status is `in_progress` or `blocked` → include in the daily cache

Write the daily cache to `memory/daily/<date>.md`:

```markdown
# Daily Cache — <YYYY-MM-DD>

## Summary
<1-2 sentences: what was the day's focus, what got done, what's left>

## Completed today
- **<task-name>**: <what was finished>

## Unfinished — carry forward

### <task-name-1>
**Stage:** <architect / plan round 3 / implement task 4 of 7 / review>
**Branch:** <branch-name>
**Pick up at:** <exactly where to resume — file, task number, next step>
**Key context:**
- <decisions made that affect next steps>
- <blockers to resolve>
- <relevant file paths and PR URLs>
**Remaining work:**
- <specific next actions>

### <task-name-2>
...

## Decisions log
<All decisions made today across all sessions, with rationale>

## Git activity summary
<High-level: N commits across M repos. Key changes: ...>
<Reference memory/git-log.md for details>

## Tomorrow's priorities
<Based on what's unfinished, suggest what to tackle first>
```

### Step 4: Prompt for lessons learned

Before wrapping up, ask the user:

> "Anything that surprised you today, or that should work differently next time?"

If they share something, append it to `memory/lessons-learned.md`:

```markdown
## <date> — <task-name>
**What happened:** <what the user described>
**Lesson:** <the reusable takeaway>
**Applies to:** <relevant skills>
```

If they say "nothing" or skip, that's fine — don't force it.

Also: if any tasks were rolled back today, or if the critic-revise loop ran more than 3 rounds, auto-add a lesson capturing what made it difficult.

### Step 5: Report to user

Tell the user:
- What was saved
- How many sessions were active today, how many completed vs unfinished
- What the daily cache recommends for tomorrow
- Remind them to run `/start_of_day` when they resume

## Important behaviors

- **Capture decisions.** The hardest thing to remember across days isn't *what* you were doing — it's *why* you made certain choices. Always capture decision rationale.
- **Be specific about resumption points.** "Continue implementing" is useless. "Continue with Task 4 (add retry logic to payment.service.ts:processRefund), branch `feat/payment-retry`, tests for Tasks 1-3 passing" is useful.
- **Don't overwrite previous sessions.** If there's already a session file for this task today (from an earlier session), update it rather than replacing it — preserve the history of what was done earlier.
- **Git log captures logic, not just files.** "Modified 3 files" tells you nothing. "Added exponential backoff to payment retries because Stripe recommends it for idempotent requests" tells you everything.
