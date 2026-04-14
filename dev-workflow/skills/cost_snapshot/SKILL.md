---
name: cost_snapshot
description: "Returns a live cost summary showing today's cost, project lifetime cost, and per-open-task breakdown. Use for: /cost_snapshot, 'how much have I spent', 'cost report', 'show costs', 'what's the project cost', 'how much has this task cost'. Read-only — no file artifacts produced."
model: haiku
---

# Cost Snapshot

You return a live cost summary for the current project. You read cost ledger files to identify sessions, call `ccusage` to get dollar amounts, and print a concise terminal-friendly report.

## Session bootstrap

Cost tracking note: `/cost_snapshot` is a read-only reporting skill. Append to the cost ledger only if a task context is clearly active (e.g., you were invoked mid-task and the task name is unambiguous). If in doubt, skip cost recording. Phase: `cost-snapshot`.

## Process

### Step 1: Collect ledger data

Determine the project root (the directory containing `.workflow_artifacts/`). Then:

- **Active tasks:** scan `.workflow_artifacts/*/cost-ledger.md` (non-finalized task folders)
- **Finalized tasks:** scan `.workflow_artifacts/finalized/*/cost-ledger.md`

For each ledger file found, parse every data line (skip lines starting with `#` and blank lines). Each line has the format:

```
<uuid> | <date> | <phase> | <model> | <category> | <notes>
```

Build three collections:

- **`today_entries`** — entries where `date` matches today's date (YYYY-MM-DD), from ALL ledgers
- **`all_entries`** — every entry from ALL ledgers (active + finalized), deduplicated by UUID
- **`open_task_entries`** — entries grouped by task name, from active (non-finalized) ledgers only

If no ledger files are found anywhere, print:

```
No cost ledgers found.
Cost tracking starts when skills record sessions to .workflow_artifacts/<task>/cost-ledger.md
```

Then stop.

### Step 2: Run ccusage for each unique UUID

Collect all unique UUIDs from all three collections. Skip any UUID starting with `unknown-` (these are fallback entries with no real session to look up).

**For fewer than 5 unique UUIDs**, run sequentially with a 15-second timeout per call:

```bash
timeout 15 npx ccusage session -i <UUID> --json
```

**For 5 or more unique UUIDs**, use a single bulk call to reduce overhead:

```bash
timeout 30 npx ccusage session --json --since <earliest-date-across-all-entries>
```

Then filter the returned results to only the UUIDs present in your collections.

Parse each JSON response: `{"sessionId": "...", "totalCost": 1.23, "totalTokens": 123456, "entries": [...]}`. Extract `totalCost` per UUID.

If `npx` or `ccusage` is not available, or all calls fail, print:

```
ccusage not available — cannot retrieve dollar amounts.
Install Node.js (https://nodejs.org) to enable cost tracking.
Session counts: <N> total sessions across <M> tasks
```

Then stop.

For individual call timeouts or errors, record cost as `null` for that UUID and continue — do not abort.

### Step 3: Print summary

Using the UUID-to-cost map from Step 2, compute:

- **Today total** — sum costs for UUIDs in `today_entries` (skip nulls and unknown- entries)
- **Lifetime total** — sum costs for all UUIDs in `all_entries` (skip nulls and unknown- entries)
- **Per open task** — for each task in `open_task_entries`, sum costs for that task's UUIDs

Print in this format:

```
Cost Snapshot — <YYYY-MM-DD>

Today:            $X.XX  (<N> sessions)
Project lifetime: $X.XX  (<N> sessions, <M> tasks)

Open tasks:
  <task-name-1>    $X.XX  (<N> sessions)
  <task-name-2>    $X.XX  (<N> sessions)

[<K> sessions with unknown cost — ccusage lookup failed or timed out]
```

Formatting rules:
- Right-align the dollar amounts (pad task names to consistent width)
- Omit the "Open tasks" section entirely if there are no active tasks
- Omit the `[K sessions with unknown cost]` line if all lookups succeeded
- Show `$0.00` if a total is zero (not blank)

## Important behaviors

- **Read-only.** Never write files (except optionally appending to the cost ledger per bootstrap rules). This is a reporting tool only.
- **Fast.** Aim for under 30 seconds. Use the bulk ccusage call when 5+ UUIDs are needed.
- **Graceful degradation.** If ccusage fails or is unavailable, print what you can (session counts, task names) with a clear explanation of what's missing. Do not error out silently.
- **No double-counting.** Deduplicate UUIDs before summing. A UUID appearing in both active and finalized ledgers (shouldn't happen, but possible) counts only once toward the lifetime total.
- **Project root detection.** If invoked from a subdirectory, walk up to find the directory containing `.workflow_artifacts/`. If not found, tell the user and stop.
