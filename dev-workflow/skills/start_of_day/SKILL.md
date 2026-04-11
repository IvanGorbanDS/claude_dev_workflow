---
name: start_of_day
description: "Restores context from the daily cache and unfinished sessions so you can resume where you left off. Use this skill for: /start_of_day, 'what was I working on', 'resume', 'pick up where I left off', 'morning standup', 'SOD', 'start of day'. Reads the latest daily cache, checks git state, and presents a clear picture of what to do next."
model: sonnet
---

# Start of Day

You restore context from the previous session(s) so the user can seamlessly resume work. You read the daily cache, check current git state, and present a clear action plan.

## Process

### Step 1: Check for un-promoted insights

Look for `memory/daily/insights-<yesterday>.md` (yesterday's date). If it exists:
- Count entries tagged `Promote?: yes` or `Promote?: maybe`
- If any exist, tell the user at the start of the briefing:
  > "Yesterday's insight scratchpad has N un-promoted entries — looks like `/end_of_day` wasn't run. Want to review them now or skip?"
  - If they want to review: run the promotion flow from `/end_of_day` Step 3b inline before continuing
  - If they skip: proceed normally (entries stay in the file for next time)

If the file doesn't exist or has no promotable entries, skip this step silently.

### Step 2: Find the latest daily cache

Look in `memory/daily/` for the most recent `.md` file. This is what `/end_of_day` saved. If there's no daily cache, check `memory/sessions/` for any session files and work from those directly.

If neither exists, tell the user there's no saved state and suggest running `/discover` to set up fresh context.

### Step 3: Read context

Read these files in parallel:

1. **Daily cache** — `memory/daily/<latest>.md` — the consolidated state
2. **Git log** — `memory/git-log.md` — recent commit history and logic
3. **Active session files** — any `memory/sessions/*` files with status `in_progress` or `blocked`
4. **Current git state** — for each repo in the project folder:
   ```bash
   git -C <repo> status --short
   git -C <repo> branch --show-current
   git -C <repo> log --oneline -5
   ```
   Check for uncommitted changes, stale branches, open PRs.

### Step 4: Reconcile

Compare what the daily cache says should be happening with what git actually shows. Look for:

- **Drift** — did someone else push commits to a branch you're working on?
- **Uncommitted work** — files changed but not committed (maybe the user started something after `/end_of_day`)
- **Branch state** — are you on the right branch for the unfinished task?
- **Stale PRs** — any open PRs that might have reviews or CI results overnight?

### Step 5: Present the briefing

Output a clear, concise briefing:

```markdown
# Good morning 👋

## Since last session
- <any new commits from others, PR reviews, CI results>
- <any drift or changes to note>

## Unfinished work

### 1. <task-name> — <stage>
**Branch:** `<branch-name>`
**Resume at:** <exactly where to pick up>
**Context:** <key decisions and rationale from last session>
**Next steps:**
1. <first thing to do>
2. <second thing>

### 2. <task-name-2> — <stage>
...

## Blocked items
- <task>: <blocker> — <suggested resolution>

## Suggested priority
<Based on urgency, dependencies, and momentum — what to tackle first and why>
```

### Step 6: Offer to resume

After presenting the briefing, ask the user what they want to work on:
- Resume a specific unfinished task (invoke the appropriate skill — `/implement`, `/review`, etc.)
- Start something new
- Check on a blocked item

## Handling multiple unfinished sessions

If the daily cache has multiple unfinished tasks:
- Present them all, ordered by suggested priority
- Note any dependencies between them (e.g., "Task B depends on Task A's review passing")
- Let the user pick which to resume

## No daily cache found

If there's no daily cache but the project has session files or git history:
- Read the most recent session files
- Read git-log.md if it exists
- Reconstruct what was likely happening
- Present what you found and suggest next steps

If nothing exists at all:
- Suggest `/discover` to index the repos
- Ask the user what they'd like to work on

## Important behaviors

- **Be concise.** This is a morning briefing, not a novel. The user wants to know what to do, not re-read everything.
- **Surface surprises.** If overnight CI broke, or someone force-pushed to a branch, or a PR got rejected — lead with that.
- **Respect the user's time.** Don't make them re-read the entire plan. Summarize the resumption point in 2-3 sentences with the exact file/task/line to start at.
- **Check git for real.** The daily cache is what *should* be true. Git state is what *is* true. Always reconcile.
