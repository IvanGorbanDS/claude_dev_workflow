---
path: .workflow_artifacts/workflow-isolation-and-hooks/stage-3/current-plan.md
hash: HEAD
updated: 2026-05-04T15:30:00Z
updated_by: /revise
tokens: 7200
---

## For human

**Status:** Stage 3 round-4 revised plan, 18 tasks (T-00..T-16 plus T-06.5), addressing 2 MAJ and 4 MIN issues from critic round 3. The `collect_entries()` algorithm now uses a two-pass approach that correctly parses both real insights file formats: heading-based (`### Insight N:` headings, canonical, matching `insights-2026-04-25.md`) and separator-based (`\n\n---\n\n`, fallback, matching `insights-2026-05-01.md`). The `score_entries()` API now accepts `list[RawEntry]` directly and computes `source_lines` internally — no manual conversion step needed.

**Biggest open risk:** T-12 P-0 spike corpus is likely smaller than 5 entries (only 2 real insights files exist today), triggering the corpus-size guard and deferring rate-threshold validation to the post-merge 30-day dry-run. The corpus-too-thin path writes a TODO comment to lessons-learned.md as a durable post-merge reminder. The 30-day dry-run clock is protected from reset by a conditional install.sh write guard.

**What's needed to make progress:** T-00 feasibility smoke must run first (BLOCKS all other tasks), then T-01 CLAUDE.md edits plus an intermediate `bash install.sh` run; T-06.5 `sleep_score.py` must be written before T-07 fixtures, T-08/T-09 tests, T-12 spike, and T-15 deploy.

**What comes next:** After T-00 PASS acknowledged, T-01 through T-06 in sequence; T-06.5 immediately follows T-06; T-07 fixtures unlock T-08..T-13; T-15 install.sh (second distinct run) and T-16 gate the merge.

## State

```yaml
task: workflow-isolation-and-hooks
stage: 3
stage_name: "sleep-skill-bidirectional-memory"
profile: Large
strict_mode: true
model: opus
session_uuid: 1D789E26-A80C-437D-BF4B-11BC1CDDA944
revise_round: 4
architecture_rev: "6.1"
status: draft
sleep_tier: haiku
sleep_stub_exists: true
stub_location: "quoin/skills/sleep/SKILL.md"
prerequisite_stages: "S-1 merged (2026-05-04); S-2 merged (2026-05-03)"
dry_run_first_30_days: true
```

## Tasks

Stage 3 ships the full `/sleep` skill body (replacing the S-2 stub), edits `/end_of_day` to auto-invoke `/sleep`, adds importance-weight YAML to `quoin/CLAUDE.md`, creates the `forgotten/` archive directory, writes and deploys `sleep_score.py`, builds the fixture corpus and tests, and adds documentation sections. Tasks are grouped: T-00 smoke (feasibility pre-check, BLOCKS rest); T-01 core CLAUDE.md edits; T-02..T-06 SKILL.md deliverables; T-06.5 write `sleep_score.py` (MUST precede T-07/T-08/T-09/T-12/T-15); T-07..T-09 test corpus; T-10..T-12 integration + chaining tests; T-13 drift-detection (includes stage-1 preamble update); T-14 CLAUDE.md doc sections; T-15 install.sh + deploy; T-16 final validation (merge gate).

1. ✓ T-00: P-MINUS-1 feasibility smoke — verify `/sleep` invocation mechanism from `/end_of_day` (BLOCKS rest of stage)
   - Files: `quoin/dev/spikes/v00_sleep_chain_smoke.md` (results record)
   - Rationale: lessons-learned 2026-04-29 mandates verifying any transport before committing to a multi-task plan. The architecture calls for `/end_of_day` to auto-invoke `/sleep` as its final step. Two plausible mechanisms exist:
     - **Option A (preferred):** `/end_of_day` body instructs the skill to spawn a Haiku Agent subagent using the same `Agent` tool already used for Step 2 Haiku summaries — the harness subagent-spawn tool IS available in the skill body (no subprocess involved). `/sleep` runs as that subagent.
     - **Option B (fallback):** `/end_of_day` appends a plain-text instruction at the end of its user-visible output telling the user to run `/sleep`; no auto-dispatch. Effectively `--skip-sleep` is the only mode, and `/sleep` is always standalone.
   - The lesson from 2026-04-29 is about PYTHON SUBPROCESSES not being able to reach the harness Agent tool. Skill bodies (running directly as Claude) CAN use the Agent tool — this is the same mechanism that already works for the Step 2 Haiku summary spawn in every Class B writer. So Option A is very likely to work; the smoke confirms it.
   - Procedure:
     1. In a fresh session, invoke `/end_of_day` with a minimal mock session-state. Observe whether the Agent tool fires for the Haiku summary step (Step 2) — if yes, the harness subagent-spawn tool is available.
     2. Confirm that an Agent subagent spawned from `/end_of_day`'s body with `model: "haiku"` can write to disk (append a single test line to a scratch file under `.workflow_artifacts/memory/`). Read the scratch file back.
     3. Record CASE A (Agent tool fires, disk write succeeds → Option A viable) or CASE B (Agent tool unavailable → Option B fallback).
   - Pre-spike outcome procedure:
     - **CASE A:** all task specs proceed with Option A (Agent subagent dispatch from `/end_of_day` body). T-05 (end_of_day edit) uses subagent dispatch. No design changes.
     - **CASE B:** T-05 is revised to Option B (plain-text instruction to user; no dispatch). T-06 `/sleep` SKILL.md drops §0 dispatch from inside-chain-context (standalone invocation still works). Document in plan revision.
   - Pass criterion: CASE branch determined and documented; no tasks start until T-00 PASS acknowledged.
   - Acceptance: `v00_sleep_chain_smoke.md` present and records CASE A or CASE B with evidence; user acknowledges branch before T-01 begins.

2. ✓ T-01: extend `quoin/CLAUDE.md` Phase values with `sleep` and add `QUOIN_POLLUTION_THRESHOLD` constant entry
   - File: `quoin/CLAUDE.md`
   - Edit 1: In `### Cost tracking` "Phase values" line, append `sleep` to the comma-separated list. (Companion to S-2's `checkpoint` addition — both required before any `/sleep` ledger row is written.)
   - Edit 2: In `### Hooks deployed by quoin` tunable-constants table, add row for `POLLUTION_THRESHOLD` (default 5000; env var `QUOIN_POLLUTION_THRESHOLD`) if not already present from S-1 merge. Check before editing — S-1 may have shipped this already.
   - Tier 1 carve-out: `quoin/CLAUDE.md` is hand-edited Tier 1 — keep edits as plain English; do NOT compress.
   - Order constraint: this MUST be done AND `bash install.sh` run BEFORE the first `/sleep` ledger row is written; otherwise `cost_from_jsonl.py` and analyzers see an unrecognized phase.
   - NOTE — two separate `bash install.sh` runs required: This intermediate run (after T-01) deploys the updated `quoin/CLAUDE.md` (Phase values + POLLUTION_THRESHOLD row) but NOT `sleep_score.py` (the install.sh edit task, T-15, hasn't run yet). The final install.sh run at T-15 deploys `sleep_score.py` and writes the dry-run marker. Both runs serve distinct purposes; do not conflate them.
   - Acceptance: `grep '\bsleep\b' quoin/CLAUDE.md` matches the Phase values line; `bash install.sh` copies updated `quoin/CLAUDE.md` → `~/.claude/CLAUDE.md`; test in T-15.

3. ✓ T-02: add importance-weight YAML block to `quoin/CLAUDE.md`
   - File: `quoin/CLAUDE.md` — add new `### /sleep importance signals` section
   - Content: the YAML config block that `/sleep` reads at runtime for threshold tuning. Two sub-blocks: `promote_signals` and `forget_signals`, each mapping signal name to weight (integer 0..10). Default weights from architecture:
     ```yaml
     sleep_importance_signals:
       promote:
         frequency_3plus: 3       # appears in ≥3 daily/session entries in scan window
         cross_task_2plus: 2      # keywords in sessions for ≥2 different task names
         cost_bearing: 2          # entry within ±2h of high-cost-ledger row
         user_marked_yes: 5       # Promote?: yes in insights file
         structural_fit: 1        # matches known taxonomy (V-04..V-07, integration, etc.)
         survival: 1              # still relevant N days later (re-mentioned or unresolved)
       forget:
         one_shot: 2              # appears exactly once in dailies
         resolved_and_shipped: 2  # tied to cleanly-closed task with no recurrence
         sub_threshold_cost: 1    # no cost-ledger row above $0.50 floor within ±2h
         stale_30days: 2          # older than 30 days with no new mentions
         user_marked_no: 5        # Promote?: no
         duplicate: 3             # ≥3-keyword overlap with existing lessons-learned entry
       thresholds:
         promote_min_score: 3     # sum of matched promote weights to qualify as Promote
         promote_max_forget: 0    # max forget signals allowed for Promote decision
         forget_min_score: 2      # sum of matched forget weights to qualify as Soft-Forget
         forget_max_promote: 0    # max promote signals allowed for Forget decision
         forget_quiet_floor: 4    # score at which --quiet-forget suppresses per-entry confirmation
         scan_window_days: 30     # how far back /sleep scans daily files
         cost_bearing_floor_usd: 0.50  # cost-ledger row threshold for cost_bearing signal
         stale_days: 30           # days threshold for stale signal
         _source: claude_md       # sentinel: distinguishes live YAML parse from hardcoded defaults (T-08 test_default_weights_present uses this)
     ```
   - NOTE — `_source: claude_md` sentinel behavior: this key is present in the parsed `thresholds` dict at runtime. `sleep_score.py` ignores it at runtime — `load_config()` uses `.get()` for all threshold key lookups, so unknown keys (including `_source`) produce no error and are silently skipped. The sentinel is purely for the T-08 `test_default_weights_present` test to distinguish a live YAML parse from hardcoded defaults; it has no runtime effect.
   - Env var override pattern: document that each key maps to env var `QUOIN_SLEEP_<KEY>` (e.g., `QUOIN_SLEEP_PROMOTE_MIN_SCORE=3`) for runtime tuning without editing CLAUDE.md.
   - Tier 1 carve-out: CLAUDE.md is Tier 1 — the YAML block is documentation, not compressed artifact.
   - Acceptance: `grep 'sleep_importance_signals' quoin/CLAUDE.md` matches; env var override pattern documented; block is copy-paste-safe for `/sleep` SKILL.md's bootstrap read.

4. ✓ T-03: create `forgotten/` archive directory and update project structure description
   - Action: create empty `.workflow_artifacts/memory/forgotten/.gitkeep` to make the directory exist in git.
   - File: `quoin/CLAUDE.md` (or the appropriate project-structure section) — add `forgotten/<date>.md` entry in the memory directory tree diagram alongside `daily/`, `sessions/`, etc.
   - Content of `forgotten/<date>.md` format: append-only, one block per soft-forgotten entry. Each block:
     ```
     > Source: <absolute-path-to-source-file>:<start-line>..<end-line>
     > Forgotten: <ISO timestamp>
     > Score: forget=<N>, promote=<N>

     <original entry text verbatim>

     ---
     ```
   - The `> Source:` line is the restore anchor for `--restore`.
   - Acceptance: `ls .workflow_artifacts/memory/forgotten/` returns (empty or .gitkeep); project-structure description updated in CLAUDE.md; forgotten format spec checked in to `quoin/dev/tests/fixtures/sleep/` as a reference fixture.

5. ✓ T-04: add "Workflow memory layers" section to `quoin/CLAUDE.md`
   - File: `quoin/CLAUDE.md` — add `### Workflow memory layers` H3 section near the Lifecycle skills section
   - Content: the boundary table from the architecture:
     | Memory layer | Purpose | Today's mechanism |
     | auto-memory | user/feedback/project facts | written ad-hoc |
     | lessons-learned.md | reusable engineering takeaways | /end_of_task + /sleep promote |
     | daily/insights-<date>.md | in-session insight scratchpad | written ad-hoc |
     | daily/<date>.md | rendered daily briefing | written by /end_of_day |
     | weekly/<iso-week>.md | rendered weekly review | written by /weekly_review |
     | forgotten/<date>.md (NEW) | soft-forget archive | written by /sleep |
   - Hard boundary statement: `/sleep` writes ONLY to `lessons-learned.md` and `forgotten/`. It does NOT touch `~/.claude/projects/<hash>/memory/` (auto-memory). Enforced by write-target restriction in T-06 SKILL.md and tested in T-09.
   - Tier 1 — plain English.
   - Acceptance: section present; boundary table enumerates all 6 layers; auto-memory boundary explicitly called out; `forgotten/` noted as new in S-3.

6. ✓ T-05: edit `quoin/skills/end_of_day/SKILL.md` to auto-invoke `/sleep` as final step (gated on T-00 PASS, CASE A assumed)
   - File: `quoin/skills/end_of_day/SKILL.md`
   - Edit: add a new `### Step 6: Invoke /sleep (memory consolidation)` section after the existing Step 5 "Report to user" section.
   - Content (Option A — Agent subagent dispatch, per T-00 CASE A):
     ```
     ### Step 6: Invoke /sleep (memory consolidation)

     After Step 5 completes and the user has been shown the report, check for `--skip-sleep` flag:
     - If `--skip-sleep` was passed in the invocation: print "Skipping /sleep (--skip-sleep passed). Run /sleep standalone to consolidate memory." and stop.
     - Otherwise: spawn a Haiku Agent subagent:
         model: "haiku"
         description: "sleep — memory consolidation after end_of_day"
         prompt: "[no-redispatch]\n/sleep\ncontext:\n- daily briefing: .workflow_artifacts/memory/daily/<today>.md\n- lessons: .workflow_artifacts/memory/lessons-learned.md\n- forgotten: .workflow_artifacts/memory/forgotten/\n- scan window: <QUOIN_SLEEP_SCAN_WINDOW_DAYS or 30> days"
       Wait for the subagent. Print the subagent's output inline.
       If the subagent fails (tool error, dispatch unavailable): print "[quoin-S-3: /sleep invocation failed; daily briefing is durable; run /sleep standalone to retry]" and exit 0. DO NOT roll back the daily briefing — /sleep is the LAST step and the briefing is already written.
     ```
   - If T-00 returns CASE B: this step becomes: "Print: 'Memory consolidation: run /sleep to promote insights and soft-forget stale entries.' (auto-dispatch unavailable — see spike results).". No subagent spawn.
   - Also add `--skip-sleep` flag documentation to the `/end_of_day` SKILL.md description frontmatter and the "Important behaviors" section.
   - Acceptance: `grep 'Step 6' quoin/skills/end_of_day/SKILL.md` matches; `--skip-sleep` documented in two places; subagent dispatch uses `[no-redispatch]` sentinel; failure path does NOT roll back daily briefing; test in T-11.

7. ✓ T-06: write `quoin/skills/sleep/SKILL.md` — replace stub with full skill body (Haiku-tier)
   - File: `quoin/skills/sleep/SKILL.md` (currently the S-2 stub; this task replaces body, preserving §0c block placement)
   - Tier: Haiku (§0 Model dispatch block required; same pattern as `/end_of_day`)
   - Structure (in order):
     - Frontmatter YAML (`model: haiku`; updated description)
     - `## §0 Model dispatch` block (same pattern as end_of_day — Haiku tier, `[no-redispatch]` guard, dispatch to haiku if invoked from opus/sonnet session)
     - `## §0c Pidfile lifecycle` block (PRESERVE exactly from stub; placement rule: last §0-class block)
     - `## Overview` — one paragraph: what /sleep does, when it runs, what it touches
     - `## Invocation modes` — list the four modes: (a) auto-chain from /end_of_day, (b) standalone, (c) `--dry-run`, (d) `--escalate` (borderline Opus re-run); plus subcommands `--restore <pattern>` and `--purge --older-than 90d`
     - `## Scan scope` — what files /sleep reads: `daily/insights-<date>.md` files within the scan window, `sessions/<date>-<task>.md` files within the window, `lessons-learned.md`, `cost-ledger.md` files (for cost_bearing signal). Does NOT read: `forgotten/`, `~/.claude/projects/<hash>/memory/` (auto-memory), `daily/<date>.md` briefings (those are rendered output, not raw insights).
     - `## Importance scoring` — read the `sleep_importance_signals` YAML block from `~/.claude/CLAUDE.md` (or `~/.claude/memory/` deployed copy if CLAUDE.md not found). For each candidate entry, compute promote_score and forget_score by checking which signals fire. Three-bucket decision: Promote (promote_score ≥ promote_min_score AND forget_score ≤ promote_max_forget); Soft-Forget (forget_score ≥ forget_min_score AND promote_score ≤ forget_max_promote); Middle-Band (everything else).
     - `## Process (default mode)` — sequential steps:
       - **Step 0: Check prerequisites** — verify `daily/<today>.md` exists at `.workflow_artifacts/memory/daily/<today>.md`. If absent: emit "Error: /sleep requires today's daily briefing (daily/<today>.md) — run /end_of_day first." and exit non-zero. (Standalone invocation without /end_of_day must fail cleanly. In the auto-chain path the daily briefing is written before /sleep is invoked, so this guard fires only in standalone context.)
       - Step 1: Read CLAUDE.md importance-weight config (fail gracefully if missing → use hardcoded defaults).
       - Step 2: Invoke `python3 ~/.claude/scripts/sleep_score.py --scan-dir .workflow_artifacts/memory/daily/ --lessons-file .workflow_artifacts/memory/lessons-learned.md` to collect candidate entries and compute bucket decisions. Capture output as JSON lines.
       - Step 3: Dedup Promote candidates against existing `lessons-learned.md` entries (handled inside `sleep_score.py`).
       - Step 4: Present promote candidates to user (max 10 at a time). For each: "Promote this pattern? [y / n / edit]". On `y`: append to `lessons-learned.md` in standard format. On `edit`: user types revised text; append revised version.
       - Step 5: Present soft-forget candidates to user (max 10 at a time). For each: "Soft-forget this entry? [y / n]" (unless score ≥ forget_quiet_floor AND `--quiet-forget` passed). On `y`: move entry block to `forgotten/<today>.md` with `> Source:` prefix.
       - Step 6: Print summary: "N promoted; M soft-forgotten; K deferred to middle band."
     - `## --dry-run mode` — runs all scoring and dedup passes via `sleep_score.py --dry-run`; prints the three-bucket decision for each candidate. Makes NO writes. Useful for the first 30 days calibration.
     - `## --restore <pattern>` subcommand — search `forgotten/` for entries matching pattern. For each match: read `> Source:` anchor. Apply restore target precedence: (1) original source exists → restore there; (2) original source gone → restore to `daily/insights-<today>.md` with prefix; (3) neither writable → abort. Confirm with user before each restore.
     - `## --purge --older-than 90d` subcommand — list `forgotten/<date>.md` files older than threshold. For each: print summary; ask "Permanently delete? [y / n]". On `y`: `rm forgotten/<date>.md`. Warn: "This is a true delete." Never auto-run.
     - `## --escalate flag` — after scoring, collect middle-band candidates. Spawn Opus Agent subagent for deeper reasoning. Opus subagent returns revised decisions; user confirms each. NOTE: `[no-redispatch]` guards the parent /sleep invocation from being re-dispatched by §0; it does NOT prevent /sleep from spawning Opus children via `--escalate`. The Opus subagent spawned by `--escalate` is an explicit forward dispatch, not a tier-switch of the current session.
     - `## Write-target restriction` — HARD RULE: /sleep ONLY writes to `.workflow_artifacts/memory/lessons-learned.md` AND `.workflow_artifacts/memory/forgotten/<date>.md`. Any other write path is a bug. This restriction is tested by T-09.
     - `## Cost ledger` — at session start, append a row to task cost ledger (phase: `sleep`, model: `haiku`). Skip if no task context active.
   - §0c placement rule: §0c MUST remain the LAST §0-class block. Verify: `grep -n '## §0' quoin/skills/sleep/SKILL.md` confirms §0 precedes §0c.
   - Acceptance: stub body replaced; §0 and §0c blocks present in correct order; all modes documented; write-target restriction states literal "ONLY writes to"; `--dry-run` note says "Makes NO writes"; `## Process (default mode)` starts with Step 0 prerequisite guard; test in T-08, T-09, T-10, T-11, T-12.

8. ✓ T-06.5: write `quoin/scripts/sleep_score.py` — scoring module (MUST precede T-07, T-08, T-09, T-12, T-15)
   - File: `quoin/scripts/sleep_score.py` (new file — does not exist today; verify: `quoin/scripts/` currently contains build_preambles.py, classify_critic_issues.py, cost_from_jsonl.py, measure_revise_crossover_cost.py, measure_v_trip_rate.py, path_resolve.py, pidfile_helpers.sh, session_age_guard.py, validate_artifact.py)
   - Constraint: stdlib preferred; pyyaml used for YAML parsing if installed (soft dependency, same pattern as `validate_artifact.py`), hardcoded defaults otherwise. No other external packages. Plain Python 3, importable and runnable as CLI.
   - CLI interface:
     ```
     python3 sleep_score.py [--dry-run] [--scan-dir PATH] [--scan-days N]
                            [--lessons-file PATH] [--output json|text]
     ```
     - `--dry-run`: read and score all candidates, print decisions, make NO file writes.
     - `--scan-dir PATH`: root directory to scan for `insights-*.md` files (default: `.workflow_artifacts/memory/daily/`).
     - `--scan-days N`: only consider files dated within last N days (default: 30; reads from config if available).
     - `--lessons-file PATH`: path to `lessons-learned.md` for dedup check (default: `.workflow_artifacts/memory/lessons-learned.md`).
     - `--output json|text`: stdout format (default: `json`).
     - `--help`: print usage and exit 0.
   - Importable API (for test imports via `sys.path`):
     - `load_config(claude_md_path: str) -> dict` — extracts and parses the `sleep_importance_signals` YAML block from the given CLAUDE.md path using this algorithm:
       1. Read the file as text.
       2. Find the fenced block starting with ` ```yaml ` (on its own line) that appears after the `### /sleep importance signals` heading.
       3. Extract text between ` ```yaml ` and the closing ` ``` ` delimiter.
       4. Try `import yaml; yaml.safe_load(extracted)` — if pyyaml is installed, use it.
       5. On `ImportError`: fall back to hardcoded defaults (the same weights from T-02 YAML block) and emit one-line warning to stderr: `[sleep_score: pyyaml not installed; using hardcoded default weights]`.
       Returns dict with keys `promote`, `forget`, `thresholds`. If block missing or parse fails, returns hardcoded defaults matching the T-02 YAML.
       NOTE — unknown keys in `thresholds`: `load_config()` uses `.get()` for all threshold key lookups. Unknown keys in the parsed `thresholds` dict (including `_source: claude_md`) are silently ignored — they produce no error, no warning, and no behavior change.
     - `collect_entries(scan_dir: str, scan_days: int) -> list[RawEntry]` — scans insights files and parses individual entries using a two-pass algorithm:
       **Pass 1 (heading-based — canonical format):**
       1. Glob `insights-*.md` files in `scan_dir` (and subdirs one level deep) modified within `scan_days` days.
       2. For each file: scan for lines matching `^### ` (H3 headings). If the file contains ≥2 such lines, treat each `### ` heading as the start of a new entry block. Split the file on `^### ` boundaries — each heading line plus the text until the next heading (or EOF) is one entry block. Include the heading line in the block.
       3. For each block: strip leading/trailing whitespace; skip if fewer than 10 chars.
       4. Track `source_start_line` = 1-based line number of heading line in the file; `source_end_line` = last line of the block.
       5. Extract `promote_tag`: `True` if block contains a line matching `Promote?: yes` (case-insensitive); `no_tag`: `True` if block contains a line matching `Promote?: no` (case-insensitive).
       **Pass 2 (separator-based — fallback for files with <2 `### ` headings):**
       1. For files where Pass 1 found <2 heading lines: split on `---` separator lines. A separator line is any line matching `^---\s*$` after stripping surrounding blank lines from the split. Blank lines immediately before or after a `---` line are consumed as part of the separator (i.e., `\n\n---\n\n` and `\n---\n` both produce the same split points).
       2. For each block: strip leading/trailing whitespace; skip if fewer than 10 chars.
       3. Track line numbers and extract tags as in Pass 1 steps 4–5.
       Returns a list of `RawEntry` objects.
     - `RawEntry` is a dataclass or namedtuple with fields:
       - `text: str` — full entry text (verbatim block content, including the `### ` heading if heading-based)
       - `source_path: str` — absolute path to source file
       - `source_start_line: int` — 1-based line number of entry start in source file
       - `source_end_line: int` — 1-based line number of entry end in source file
       - `promote_tag: bool` — True if block contains `Promote?: yes` (case-insensitive)
       - `no_tag: bool` — True if block contains `Promote?: no` (case-insensitive)
     - `score_entries(entries: list[RawEntry], config: dict) -> list[ScoredEntry]` — takes a list of `RawEntry` objects (as returned by `collect_entries`) and a config dict (from `load_config`). Internally converts each `RawEntry` to a `ScoredEntry` by:
       - Computing `source_lines = f"{entry.source_start_line}..{entry.source_end_line}"`.
       - Scoring `promote_score` and `forget_score` from entry text and signals.
       - Assigning `bucket` based on threshold comparisons.
       Returns a list of `ScoredEntry` objects. No separate conversion function is needed — the conversion is internal to `score_entries`.
     - `ScoredEntry` is a dataclass or namedtuple with fields:
       - `text: str` — original entry text
       - `source_path: str` — absolute path to source file
       - `source_lines: str` — line range formatted as `f"{source_start_line}..{source_end_line}"` (derived from `RawEntry.source_start_line` and `source_end_line`)
       - `promote_score: int` — sum of matched promote signal weights
       - `forget_score: int` — sum of matched forget signal weights
       - `bucket: str` — one of `"promote"`, `"forget"`, `"middle"`
   - Public API summary table (both types, all fields):

     | Type | Field | Type | Source |
     |------|-------|------|--------|
     | `RawEntry` | `text` | `str` | verbatim block |
     | `RawEntry` | `source_path` | `str` | absolute path |
     | `RawEntry` | `source_start_line` | `int` | 1-based line number |
     | `RawEntry` | `source_end_line` | `int` | 1-based line number |
     | `RawEntry` | `promote_tag` | `bool` | `Promote?: yes` present |
     | `RawEntry` | `no_tag` | `bool` | `Promote?: no` present |
     | `ScoredEntry` | `text` | `str` | from `RawEntry.text` |
     | `ScoredEntry` | `source_path` | `str` | from `RawEntry.source_path` |
     | `ScoredEntry` | `source_lines` | `str` | `f"{source_start_line}..{source_end_line}"` |
     | `ScoredEntry` | `promote_score` | `int` | sum of matched promote weights |
     | `ScoredEntry` | `forget_score` | `int` | sum of matched forget weights |
     | `ScoredEntry` | `bucket` | `str` | `"promote"` / `"forget"` / `"middle"` |

   - Dry-run stdout format: NDJSON (one JSON object per line). Each line is a ScoredEntry dict with all fields. Example:
     ```
     {"text": "...", "source_path": "/abs/path/insights-2026-04-25.md", "source_lines": "5..12", "promote_score": 4, "forget_score": 0, "bucket": "promote"}
     ```
   - Corpus-size guard:
     - Count total candidate entries found across all scanned files.
     - If fewer than 5 entries: emit to stderr: `[sleep_score: corpus too small (N entries); calibration deferred — run after 30 days of production --dry-run accumulation]`
     - Still produce output for existing entries; mark as potentially unreliable.
   - Internal helper functions: `score_entry(text, signals, thresholds)`, `dedup_against_lessons(entries, lessons_path)`, `bucket_entry(promote_score, forget_score, thresholds)`. Note: `collect_entries`, `RawEntry`, `score_entries`, and `ScoredEntry` are part of the public importable API (listed above), not private helpers.
   - Error handling: if `--scan-dir` does not exist → print warning to stderr, exit 0 with empty output (not a hard error — directory may not exist in fresh projects).
   - Acceptance: `python3 quoin/scripts/sleep_score.py --help` exits 0; `python3 quoin/scripts/sleep_score.py --dry-run --scan-dir quoin/dev/tests/fixtures/sleep/promote_hit/ --output json` exits 0 and prints NDJSON; importable as `from sleep_score import load_config, collect_entries, score_entries, ScoredEntry, RawEntry`; no external imports at module scope (pyyaml imported inside `load_config()` body only, not at top level); `grep '^import\|^from' quoin/scripts/sleep_score.py` shows only stdlib modules at top level; `collect_entries` correctly parses both `insights-2026-04-25.md` (heading-based, ≥2 `### ` lines → Pass 1) and `insights-2026-05-01.md` (separator-based with surrounding blank lines, <2 `### ` lines → Pass 2) returning non-empty entry lists for both.

9. ✓ T-07: build fixture corpus at `quoin/dev/tests/fixtures/sleep/`
   - Directory: `quoin/dev/tests/fixtures/sleep/`
   - Required fixtures (one subdirectory each):
     - `promote_hit/`: THREE separate insights files required for `frequency_3plus` signal (signal counts distinct files, not occurrences within one file):
       - `insights-2026-04-01.md` — contains the target pattern
       - `insights-2026-03-15.md` — contains the same pattern (second distinct file)
       - `insights-2026-03-01.md` — contains the same pattern (third distinct file — triggers `frequency_3plus`)
       - Shared pattern example across all 3 files: "jq must be installed before hooks can parse stdin — hooks fail-OPEN silently if jq is absent". Plus matching `sessions/` stubs. Expected decision: Promote.
     - `forget_hit/`: an `insights-2026-03-01.md` file (>30 days old) with a one-shot entry firing `one_shot` + `stale_30days`. Expected decision: Soft-Forget.
     - `middle_band/`: an entry with one promote signal and one forget signal. Expected decision: Middle-Band.
     - `dedup_suppress/`: a candidate whose text overlaps ≥3 keywords with a fixture `lessons-learned.md` entry. Expected decision: dropped (not in promote list after dedup).
     - `restore_original_exists/`: a `forgotten/2026-03-15.md` file with `> Source:` pointing to a fixture insights file that EXISTS in the test directory. `--restore` should append to that file.
     - `restore_original_gone/`: a `forgotten/2026-03-10.md` file with `> Source:` pointing to a path that does NOT exist. `--restore` should redirect to today's insights file.
     - `no_auto_memory_bleed/`: a fixture that would naively write to `~/.claude/projects/<hash>/memory/` if the write-target restriction were absent. Used by T-09 Layer 1 assertion.
     - `forgotten_format.md`: canonical reference fixture for the `forgotten/<date>.md` block format (from T-03).
   - Fixture format requirement: each `insights-*.md` fixture file MUST use the heading-based format (`### Insight N:` headings) as the canonical fixture format — this matches the actual format used by real insights files (as confirmed by reading `.workflow_artifacts/memory/daily/insights-2026-04-25.md`). Each `### ` heading starts a new entry block. Separator-based format (`---`) is supported by `collect_entries()` for backward compat but fixtures should use headings. Any fixture using a `### ` heading-based format with ≥2 headings will be parsed by Pass 1.
   - Acceptance: all 7 subdirectories present; each has a `README.md` explaining expected outcome; `promote_hit/` has exactly 3 separate `insights-*.md` files with a shared named pattern; at least one fixture exercises the `--quiet-forget` floor (score ≥ 4 forget signals); every fixture insights file uses the `### Insight N:` heading-based format with ≥2 headings.

10. ✓ T-08: write `quoin/dev/tests/test_sleep_scoring.py` — unit tests for importance scoring
    - File: `quoin/dev/tests/test_sleep_scoring.py`
    - Prerequisite: T-06.5 (`sleep_score.py`) must exist. Import via `sys.path.insert(0, str(Path(__file__).parent.parent.parent / "scripts"))`.
    - Tests:
      - `test_promote_hit`: loads `promote_hit/` fixture; calls `collect_entries(...)` then `score_entries(entries, config)`; asserts result contains at least one entry with `bucket == "promote"`.
      - `test_forget_hit`: loads `forget_hit/` fixture; asserts result contains entry with `bucket == "forget"`.
      - `test_middle_band`: loads `middle_band/` fixture; asserts result contains entry with `bucket == "middle"`.
      - `test_dedup_suppress`: loads `dedup_suppress/` fixture; calls `score_entries` then `dedup_against_lessons`; asserts candidate is NOT in promote list after dedup.
      - `test_weight_override`: creates config with `thresholds.promote_min_score = 99`; asserts `score_entries` returns no entries with `bucket == "promote"`.
      - `test_default_weights_present`: calls `load_config("quoin/CLAUDE.md")` against the live CLAUDE.md file (not a fixture); asserts returned dict has keys `promote`, `forget`, `thresholds` with expected sub-keys (e.g., `frequency_3plus` in `promote`, `one_shot` in `forget`, `promote_min_score` in `thresholds`). To distinguish live YAML parse from hardcoded fallback: the T-02 YAML block in CLAUDE.md must include a sentinel key `_source: claude_md` under `thresholds` that is absent from the hardcoded defaults; the test asserts `config["thresholds"].get("_source") == "claude_md"`. If pyyaml is not installed, the test should skip with `pytest.skip("pyyaml not installed — skipping live-parse verification")`.
    - Acceptance: `python3 quoin/dev/tests/test_sleep_scoring.py` exits 0 with all tests passing or skipping (no failures); pyyaml-dependent test (`test_default_weights_present`) skips gracefully when pyyaml absent; no hardcoded paths to user home.

11. ✓ T-09: write `quoin/dev/tests/test_sleep_write_boundary.py` — auto-memory bleed test
    - File: `quoin/dev/tests/test_sleep_write_boundary.py`
    - Purpose: assert `/sleep` NEVER writes outside `lessons-learned.md` and `forgotten/`. This is the R-05 mitigation test.
    - Design (MAJ-3 fix — dual-layer approach):
      - **Layer 1 (module purity):** run `python3 quoin/scripts/sleep_score.py --dry-run --scan-dir quoin/dev/tests/fixtures/sleep/no_auto_memory_bleed/ --output json` (subprocess call from within the test); assert exit code 0; assert NO output line contains any path matching `~/.claude/projects/`; assert the module produces output and exits without writing any files (by checking that no new files were created in any temp directory during the run).
      - **Layer 2 (SKILL.md body text):** open `quoin/skills/sleep/SKILL.md`; grep for the literal string `"ONLY writes to"`; assert the grep matches; assert the surrounding context names only `lessons-learned.md` and `forgotten/` as write targets; assert no `~/.claude/projects/` path appears as a write target in the `## Write-target restriction` section.
    - Acceptance: `python3 quoin/dev/tests/test_sleep_write_boundary.py` exits 0; both layers pass; no auto-memory path appears in dry-run output.

12. ✓ T-10: write `quoin/dev/tests/test_sleep_restore_roundtrip.py` — restore round-trip test
    - File: `quoin/dev/tests/test_sleep_restore_roundtrip.py`
    - Tests (three cases per architecture MAJ-5):
      - **Case 1 — original path exists:** soft-forget 1 entry from `restore_original_exists/` fixture (write to temp `forgotten/` dir); run `--restore <pattern>` → assert entry text appears verbatim in the original source file.
      - **Case 2 — original path gone:** soft-forget 1 entry from `restore_original_gone/` fixture; run `--restore <pattern>` → assert entry text appears in a temp `daily/insights-<today>.md` file with `> Restored from forgotten/<orig-date>.md` prefix line.
      - **Case 3 — neither writable:** soft-forget 1 entry; chmod 000 all candidate write targets; assert `--restore` exits non-zero and prints entry text to stderr.
    - All three cases use a temp directory sandbox; no writes to real `.workflow_artifacts/`.
    - Acceptance: `python3 quoin/dev/tests/test_sleep_restore_roundtrip.py` exits 0; all 3 cases pass.

13. ✓ T-11: write `quoin/dev/tests/test_sleep_chaining.sh` — /end_of_day → /sleep integration tests
    - File: `quoin/dev/tests/test_sleep_chaining.sh`
    - Tests (all are static SKILL.md body text checks — grep + pattern-matching):
      - **test_skip_sleep_flag:** grep `quoin/skills/end_of_day/SKILL.md` for "Skipping /sleep" and "Run /sleep standalone"; also grep frontmatter description for `--skip-sleep`. Assert all matches found. (Verifies the flag is wired into both the body and the description.)
      - **test_sleep_failure_no_rollback:** grep `quoin/skills/end_of_day/SKILL.md` Step 6 body for `[quoin-S-3: /sleep invocation failed`; assert it appears BEFORE any `exit 0` clause in Step 6; assert "DO NOT roll back" appears in Step 6 block. (Verifies ordering and rollback guard are written in.)
      - **test_default_chain_fires:** grep `quoin/skills/end_of_day/SKILL.md` Step 6 body for the `[no-redispatch]` sentinel in the subagent dispatch prompt text. Assert sentinel is present. NOTE: runtime verification that the Haiku subagent actually fires is manual and is covered in T-16 Sub-task B smoke.
    - Acceptance: `bash quoin/dev/tests/test_sleep_chaining.sh` exits 0; 3/3 subtests pass.

14. ✓ T-12: write `quoin/dev/tests/test_sleep_dry_run_spike.sh` — dual false-positive rate spike (P-0, BLOCKS MERGE)
    - File: `quoin/dev/tests/test_sleep_dry_run_spike.sh`
    - This is the S-3 P-0 de-risking spike from the architecture.
    - Corpus design (CRIT-2 fix):
      - Primary source: `.workflow_artifacts/memory/daily/` (actual location of real insights files — 2 files as of 2026-05-04).
      - Supplement: `quoin/dev/tests/fixtures/sleep/` synthetic fixtures.
      - Combined for calibration signal.
    - Corpus-size guard (run FIRST):
      - Count total candidate entries across both sources.
      - If fewer than 5 entries found: emit "corpus too small (N entries); skipping rate-threshold pass criteria — real calibration happens during post-merge 30-day dry-run"; write finding to `quoin/dev/spikes/v00_sleep_dry_run_results.md` with status "DEFERRED — corpus too thin"; add a TODO comment to `.workflow_artifacts/memory/lessons-learned.md`: `<!-- TODO: Run /sleep --dry-run --spike after 30 days of production accumulation to complete P-0 calibration. -->` appended as a trailing comment; exit 0. (Corpus-too-thin is an acceptable spike outcome — the 30-day production dry-run is the real calibration gate.)
    - Measurement procedure (when corpus ≥ 5 entries):
      1. `python3 quoin/scripts/sleep_score.py --dry-run --scan-dir .workflow_artifacts/memory/daily/ --output json` → capture NDJSON.
      2. Supplement: `python3 quoin/scripts/sleep_score.py --dry-run --scan-dir quoin/dev/tests/fixtures/sleep/ --output json` → append to candidate list.
      3. For each Promote candidate: check if proposed text is new (not in lessons-learned) → `would_accept = true` if new, `would_reject = true` if duplicate/noise.
      4. For each Forget candidate: check if entry text appears in any session file dated AFTER candidate date → `would_override = true` (pattern survived, shouldn't forget).
      5. For up to 5 randomly-selected Forget candidates: simulate soft-forget, confirm `> Source:` anchor parseable.
      6. Write results to `quoin/dev/spikes/v00_sleep_dry_run_results.md`.
    - Pass criteria (only when corpus ≥ 5 entries):
      - Promote proposed-but-rejected rate ≤ 50%.
      - Forget user-override rate ≤ 25%.
    - Acceptance: `v00_sleep_dry_run_results.md` present; either (a) both rate criteria met with ≥5-entry corpus, OR (b) corpus-too-small finding documented with "calibration deferred to post-merge 30-day dry-run". Restore round-trip confirmed for ≥3 of 5 candidates (when applicable). BLOCKS MERGE until results documented.

15. ⏳ T-13: write `quoin/dev/tests/test_sleep_skill_structure.py` + update `test_quoin_stage1_preamble.py`
    - **File A (update): `quoin/dev/tests/test_quoin_stage1_preamble.py`** — add `"sleep"` to `CHEAP_TIER_SKILLS` list (one-line change; list grows from 12 to 13 skills). This maintains the canonical cheap-tier enumeration invariant — if a future edit removes §0 from sleep's SKILL.md, the stage-1 test now catches it.
    - **File B (new): `quoin/dev/tests/test_sleep_skill_structure.py`** — sleep-specific drift-detection, mirroring the stage-1 preamble test pattern:
      - `test_model_declared_haiku`: frontmatter `model: haiku`.
      - `test_sec0_present`: `## §0 Model dispatch` heading exists.
      - `test_sec0c_present`: `## §0c Pidfile lifecycle` heading exists.
      - `test_sec0c_after_sec0`: line number of `§0c` > line number of `§0`.
      - `test_pidfile_acquire_sleep`: SKILL.md contains `pidfile_acquire sleep`.
      - `test_pidfile_release_sleep`: SKILL.md contains `pidfile_release sleep`.
      - `test_write_target_restriction_present`: SKILL.md contains literal `"ONLY writes to"`.
      - `test_dry_run_no_write`: SKILL.md contains `"Makes NO writes"` in the `--dry-run mode` section.
      - `test_deployed_copy_sync`: `pytest.skip("deployed-copy-sync check requires install.sh (T-15) to have run first — assertion moved to T-16 Sub-task A")`. Documents the ordering dependency explicitly; prevents silent false-negative.
    - Acceptance: `python3 quoin/dev/tests/test_sleep_skill_structure.py` exits 0; all non-skipped tests pass; `test_deployed_copy_sync` skips with the documented message; `python3 quoin/dev/tests/test_quoin_stage1_preamble.py` exits 0 (now enumerating 13 cheap-tier skills, `sleep` included).

16. ⏳ T-14: update `quoin/CLAUDE.md` lifecycle skills section for S-3 completeness
    - File: `quoin/CLAUDE.md` — `### Lifecycle skills (checkpoint / end_of_day / sleep)` section
    - Edit: replace the forward-link placeholder for `/sleep` with the full description:
      - `/sleep` is Haiku-tier. Auto-invoked by `/end_of_day` as its final step (opt-out via `--skip-sleep`). Scans daily insights + session files within 30-day window. Three-bucket decisions: Promote → lessons-learned.md (per-entry user confirmation); Soft-Forget → `forgotten/YYYY-MM-DD.md` archive (per-entry confirmation, or skipped above quiet_floor with `--quiet-forget`); Middle-Band → deferred.
      - First 30 days of production: `/sleep --dry-run` mode enforced by `~/.claude/memory/sleep_dryrun_start.txt` marker (written by install.sh); no actual writes until marker is 30+ days old.
      - `/sleep --restore <pattern>`: moves entries back from forgotten/ to their source.
      - `/sleep --purge --older-than 90d`: true-deletes archive files; per-file confirmation; never auto-run.
    - Tier 1 — plain English.
    - Acceptance: all /sleep invocation modes described; dry-run marker file mentioned; boundary with `/checkpoint` clear.

17. ⏳ T-15: update `install.sh` to deploy `sleep_score.py`, write dry-run start marker, and verify skills deploy
    - File: `quoin/install.sh`
    - Edit 1: add `sleep_score.py` to the scripts deploy step — `quoin/scripts/sleep_score.py` → `~/.claude/scripts/sleep_score.py`.
    - Edit 2: after skills deploy step, write the dry-run start marker on FIRST DEPLOY ONLY: `[ -f ~/.claude/memory/sleep_dryrun_start.txt ] || echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > ~/.claude/memory/sleep_dryrun_start.txt`. The `[ -f ... ] ||` guard ensures re-running install.sh does NOT reset the dry-run clock. After the conditional write, emit the current marker date: `echo "sleep dry-run start: $(cat ~/.claude/memory/sleep_dryrun_start.txt 2>/dev/null || echo 'not yet written')"`. `/sleep` reads this at startup and emits "Dry-run mode active until `<start + 30 days>`: no writes will occur" if within 30 days.
    - Edit 3: add note comment: `# NOTE: run bash install.sh BEFORE first /sleep session after editing quoin/CLAUDE.md (per S-3 T-01 order constraint)`.
    - Edit 4: verify `quoin/skills/sleep/SKILL.md` is already in the skills deploy pattern (`grep 'sleep' quoin/install.sh` — from S-2 T-19.5). No change if present.
    - Run `bash install.sh` after edits.
    - Acceptance: `ls ~/.claude/scripts/sleep_score.py` succeeds; `ls ~/.claude/memory/sleep_dryrun_start.txt` succeeds and contains an ISO timestamp; `bash install.sh` exits 0; `~/.claude/skills/sleep/SKILL.md` matches `quoin/skills/sleep/SKILL.md`. Re-run `bash install.sh` a second time and confirm `sleep_dryrun_start.txt` still contains the FIRST timestamp (not updated) — verifies the conditional write guard. "re-running install.sh does NOT reset the dry-run clock."

18. ⏳ T-16: final validation — pre-merge gate + manual smoke (BLOCKS MERGE)
    - **Sub-task A — automated:**
      - Run all S-3 unit tests: `python3 quoin/dev/tests/test_sleep_scoring.py` + `test_sleep_write_boundary.py` + `test_sleep_restore_roundtrip.py` + `test_sleep_skill_structure.py` + `bash quoin/dev/tests/test_sleep_chaining.sh`. All must exit 0.
      - Run `python3 quoin/dev/tests/test_quoin_stage1_preamble.py` — confirm 13-skill enumeration passes.
      - Run **deployed-copy-sync assertion** (moved from T-13): `python3 -c "import pathlib; src=pathlib.Path('quoin/skills/sleep/SKILL.md'); dst=pathlib.Path.home()/'.claude'/'skills'/'sleep'/'SKILL.md'; assert src.read_bytes()==dst.read_bytes(), 'deployed copy mismatch'"`. Requires T-15 install.sh to have run — guaranteed because T-16 follows T-15.
      - Confirm T-12 dry-run spike results documented (accepts corpus-too-small finding as valid).
      - Run `bash install.sh`; confirm deployed files byte-identical to source.
      - Validate CLAUDE.md edits: Phase values includes `sleep`; `sleep_importance_signals` YAML parseable; lifecycle section complete; `sleep_dryrun_start.txt` written.
    - **Sub-task B — manual smoke:**
      - Run `/sleep --dry-run` against real `.workflow_artifacts/memory/`. Observe proposed decisions. Confirm no writes occurred.
      - Run `/sleep --dry-run` in fresh session; confirm abort with clear error if no `daily/<today>.md` exists.
      - Confirm `--skip-sleep` on `/end_of_day` suppresses Step 6.
      - Confirm auto-chain fires: run `/end_of_day` without `--skip-sleep`; observe Step 6 Haiku subagent (CASE A) or plain-text message (CASE B).
    - Acceptance: all automated tests pass; dry-run smoke observed; no writes to auto-memory; spike documented; deployed-copy-sync confirmed.

## Decisions

D-01: Scoring logic extracted into `quoin/scripts/sleep_score.py` (stdlib preferred; pyyaml soft dependency for YAML parsing only, matching `validate_artifact.py` pattern).
Rationale: SKILL.md bodies cannot be unit-tested directly. Extracting scoring into a testable module lets T-08 and T-09 test the logic without spawning a full Claude session. The module reads files, computes scores, and returns decisions. It does NOT write anything — all writes are performed by the SKILL.md body (on user confirmation). Subprocess call from SKILL.md body (via `python3 ~/.claude/scripts/sleep_score.py`) is valid per lessons-learned (only Agent-tool access is blocked for subprocesses, not plain Python execution). pyyaml is imported inside `load_config()` body only (never at module scope), so the module loads cleanly in environments without pyyaml — it just falls back to hardcoded defaults for config parsing.
Consequences:
- T-06 SKILL.md body invokes `sleep_score.py` via subprocess for the scoring pass; body does ALL writes.
- T-06.5 is the write task for `sleep_score.py`; it must precede T-07 fixtures, T-08 tests, T-09 boundary test, T-12 spike, and T-15 deploy.
- T-15 deploys `sleep_score.py` alongside the SKILL.md.
- Unit tests import `sleep_score.py` directly via `sys.path`.
- Write-boundary test (T-09) tests two layers: module purity (no auto-memory paths in --dry-run output) AND SKILL.md body text grep for "ONLY writes to".

D-02: `/sleep` is Haiku-tier only; `--escalate` re-runs borderline subset on Opus separately.
Rationale: per architecture MAJ-2 decision (rev-4). User-confirmation prompts are simple yes/no/edit. For the rare case Opus reasoning is needed, `--escalate` flag spawns a second Opus subagent — an explicit second invocation, NOT mid-skill tier-switching. Keeps /sleep lightweight and predictable.

D-03: First 30 days of production run `/sleep --dry-run` only; start date written to `~/.claude/memory/sleep_dryrun_start.txt` by install.sh on first deploy ONLY.
Rationale: R-03 (importance weights misjudge context) is rated High likelihood, Medium impact. Dry-run mode for the first 30 days gives calibration data before any actual promotes or forgets occur. T-12 P-0 spike is the pre-merge calibration gate; the 30-day dry-run is the production calibration. The `sleep_dryrun_start.txt` marker provides a durable, greppable end-date anchor so the flip to production mode is not left to memory. Conditional write (`[ -f ... ] || echo ...`) ensures re-installs for unrelated CLAUDE.md or skill edits do NOT reset the 30-day clock.

D-04: Auto-chain from `/end_of_day` uses Agent subagent dispatch (Option A), not a standalone subprocess.
Rationale: T-00 smoke verifies feasibility. The Agent subagent tool is available in SKILL.md bodies (same mechanism as Haiku Step 2 summary spawn in every Class B writer). Python subprocess cannot reach the harness Agent tool (lessons-learned 2026-04-29) but the SKILL.md body can. Option B (plain-text instruction) is the fallback if T-00 returns CASE B.

D-05: `/sleep` failure in the auto-chain does NOT roll back the daily briefing.
Rationale: the daily briefing is written in Step 3 of `/end_of_day`; `/sleep` is Step 6. By the time /sleep runs, the briefing is durable. Failure of the optional consolidation step must not undo the mandatory daily rollup.

D-06: Write-boundary test (T-09) tests SKILL.md body via grep, not module return values.
Rationale: per MAJ-3 fix. The module (`sleep_score.py`) is pure-scoring with no write path — grepping its output for auto-memory paths vacuously passes. The actual write risk is in the SKILL.md body. The correct test is a grep for "ONLY writes to" in the body text, combined with confirmation that only the two allowed targets are named. This makes the boundary test guard the real execution path.

D-07: `collect_entries()` uses a two-pass algorithm: Pass 1 heading-based (`### ` headings as delimiters, canonical), Pass 2 separator-based (lines matching `^---\s*$` with surrounding blank-line consumption, fallback for files with <2 headings).
Rationale: the real insights files use two different formats. `insights-2026-04-25.md` uses `### Insight N:` sub-headings (≥2 headings → Pass 1). `insights-2026-05-01.md` uses `\n\n---\n\n` (blank lines surrounding `---`, <2 `### ` headings → Pass 2). A single-pass `\n---\n` split produces zero entries from both files. The two-pass approach ensures both real formats parse correctly without breaking the public API contract. Fixtures use heading-based format (canonical) because that is the production format.

D-08: `score_entries()` accepts `list[RawEntry]` (not `list[dict]`); `source_lines: str` is computed internally.
Rationale: returning `RawEntry` from `collect_entries()` and then requiring callers to manually convert to dict before calling `score_entries()` creates an undocumented impedance mismatch (identified in round-3 critic MAJ-2). Making `score_entries()` accept `list[RawEntry]` directly and compute `source_lines = f"{entry.source_start_line}..{entry.source_end_line}"` internally eliminates the conversion step, removes the undocumented conversion contract, and makes the API consistent: `entries = collect_entries(...); scored = score_entries(entries, config)` Just Works.

## Risks

| ID | Risk | Likelihood | Impact | Mitigation | Rollback |
|----|------|-----------|--------|-----------|---------|
| R-01 | T-00 CASE B fires — Agent subagent dispatch unavailable from /end_of_day body | Low | Medium | Option B fallback: plain-text instruction; /sleep works standalone. T-05 covers both options. | Use Option B; /sleep standalone only. |
| R-02 | sleep_score.py subprocess call fails at runtime (Python not on PATH, stdlib import error) | Low | Medium | T-15 smoke (`python3 ~/.claude/scripts/sleep_score.py --help` exit 0). SKILL.md body has fail-OPEN: emit "[quoin-S-3: scoring unavailable]" and stop gracefully. | Fix Python env; run /sleep --dry-run. |
| R-03 | Importance weights misjudge real data (R-14 from architecture) | High | Medium | T-12 P-0 spike against real + fixture data before merge. First 30 days: --dry-run only (D-03). Weights tunable via CLAUDE.md. | Adjust weights; rerun spike. |
| R-04 | Soft-forget archives entry user later wishes had stayed visible (R-13 from architecture) | Medium | Low | `forgotten/` is archive not delete. `--restore` recovers. `--quiet-forget` only above floor score. | `--restore <pattern>`. |
| R-05 | /sleep bleeds into auto-memory (R-06 from architecture) | Medium | Medium | "ONLY writes to" restriction in T-06. Dual-layer T-09 test. | Revert SKILL.md; delete erroneous writes. |
| R-06 | /sleep output hidden when chained from /end_of_day (R-15 from architecture) | Medium | Low | Output printed inline. --skip-sleep for standalone run. | Use --skip-sleep; run /sleep standalone. |
| R-07 | Dry-run mode accidentally writes | Low | High | "Makes NO writes" gate in SKILL.md. T-09 catches. sleep_dryrun_start.txt forces dry-run for 30 days. | Check git status; revert writes; fix gate. |
| R-08 | T-12 spike reveals promote rejection rate > 50% | Medium | High | Block merge. Tune weights in T-02 YAML. | Adjust weights; repeat spike. |
| R-09 | T-12 spike reveals forget override rate > 25% | Medium | High | Block merge. Increase `forget_min_score`. | Adjust threshold; repeat spike. |
| R-10 | /end_of_day Step 6 failure message masked (user doesn't see it) | Low | Low | Message emitted BEFORE exit 0. T-11 static-text check verifies ordering. | Fix message ordering in T-05 edit. |
| R-11 | `forgotten/<date>.md` grows unbounded if --purge never run | Medium | Low | `--purge --older-than 90d` documented in T-06 and T-14. Requires explicit user invocation. | Run `--purge --older-than 90d`. |
| R-12 | sleep_score.py hard-codes wrong path for CLAUDE.md config read | Low | Medium | T-08 test_default_weights_present covers this. T-16 Sub-task B confirms live config read. | Fix path; redeploy via install.sh. |
| R-13 | T-12 corpus too small for meaningful calibration pre-merge | Medium | Medium | Corpus-size guard: < 5 entries → deferred-calibration finding accepted as valid spike result. Real calibration is 30-day production dry-run. | Document corpus size; accept deferred verdict. |
| R-14 | T-13 deployed-copy-sync test fails because T-15 install.sh not yet run | Low | Low | Assertion moved to T-16 Sub-task A (post-install.sh). T-13 has pytest.skip placeholder with explanatory message. | Correct ordering: T-15 before T-16 as specified. |
| R-15 | dry-run clock reset if conditional install.sh guard accidentally uses `>` instead of `||` | Low | High | Acceptance criterion for T-15 explicitly verifies two-run idempotency (second run must not update the timestamp). Code review the guard before merge. | Re-write marker date with the original timestamp (from spike results file); fix the guard. |
| R-16 | collect_entries() passes zero entries for real insights files if two-pass algorithm not implemented | Medium | High | D-07 specifies two-pass algorithm; T-06.5 acceptance explicitly verifies both real-file formats produce non-empty entry lists. T-16 Sub-task B manual smoke also confirms. | Fix algorithm; retest T-12 spike against real daily/ files. |

## References

- Architecture: `.workflow_artifacts/workflow-isolation-and-hooks/architecture.md` (S-3 section lines 527–534)
- Lessons learned: `.workflow_artifacts/memory/lessons-learned.md` (2026-04-29 lesson on subprocess transport)
- /end_of_day source: `quoin/skills/end_of_day/SKILL.md`
- /sleep stub (current): `quoin/skills/sleep/SKILL.md`
- Stage 2 plan (reference): `.workflow_artifacts/workflow-isolation-and-hooks/finalized/stage-2/current-plan.md`
- Architecture risks: auto-memory bleed, hidden /sleep output, weight misjudgment, user regret on forgotten entries, /sleep output hidden in chain (see architecture risk register)
- Existing scripts directory: `quoin/scripts/` (sleep_score.py does not yet exist; path_resolve.py is a useful stdlib-only reference)
- Real insights files location: `.workflow_artifacts/memory/daily/` (contains `insights-2026-04-25.md` using `### Insight N:` heading-based format and `insights-2026-05-01.md` using `\n\n---\n\n` separator-based format — 2 files as of 2026-05-04)
- Stage-1 preamble test: `quoin/dev/tests/test_quoin_stage1_preamble.py` (CHEAP_TIER_SKILLS list updated in T-13; grows from 12 to 13 skills)

## Revision history

Round 1 — 2026-05-04
Critic verdict: REVISE
Issues addressed: none (this was the initial /plan output)
Changes: initial plan produced by /plan, 17 tasks T-00..T-16.

Round 2 — 2026-05-04
Critic verdict: REVISE
Issues addressed:
  [CRIT-1] Missing write task for sleep_score.py — added T-06.5 (new task 8 in sequence) with full CLI interface, importable API (load_config/score_entries/ScoredEntry), NDJSON dry-run stdout format, corpus-size guard, and ordering constraint BEFORE T-07/T-08/T-09/T-12/T-15.
  [CRIT-2] Spike corpus pointed at empty finalized/ dir — changed primary scan-dir to .workflow_artifacts/memory/daily/ supplemented by fixture corpus; added 5-entry corpus-size guard with deferred-calibration exit path; updated T-12 acceptance criteria to accept corpus-too-small finding.
  [MAJ-1] Importable API undefined — resolved by CRIT-1 fix; T-08 now references load_config/score_entries/ScoredEntry by name with exact signatures.
  [MAJ-2] sleep missing from test_quoin_stage1_preamble.py CHEAP_TIER_SKILLS — T-13 now updates File A (test_quoin_stage1_preamble.py, one-line addition, list grows to 13 skills) in addition to creating File B (test_sleep_skill_structure.py).
  [MAJ-3] Write-boundary ambiguity — added D-06; T-09 redesigned as dual-layer test: Layer 1 (module purity — no auto-memory paths in --dry-run NDJSON output) + Layer 2 (SKILL.md body grep for "ONLY writes to"); T-06 acceptance updated to require that literal string.
  [MIN-1] No durable dry-run end-date marker — added sleep_dryrun_start.txt write to T-15 install.sh; /sleep reads at startup and emits dry-run-active banner with end date; D-03 updated.
  [MIN-2] test_default_chain_fires cannot be a grep test for runtime behavior — revised T-11 to grep for [no-redispatch] sentinel in Step 6 static text; explicit NOTE that runtime verification is T-16 Sub-task B manual smoke.
  [MIN-3] promote_hit/ underspecified — T-07 now names all 3 files explicitly (insights-2026-04-01.md, insights-2026-03-15.md, insights-2026-03-01.md) with shared pattern example ("jq must be installed before hooks can parse stdin").
  [MIN-4] test_deployed_copy_sync ordering conflict — moved to T-16 Sub-task A; T-13 has pytest.skip placeholder with explanatory message; added R-14 to risk table.
Issues deferred: none — all 2 CRIT, 3 MAJ, 4 MIN addressed.
Changes: 18 tasks (T-00..T-16 plus T-06.5); 6 decisions; 14 risks; write-boundary design fully clarified.

Round 3 — 2026-05-04
Critic verdict: REVISE
Issues addressed:
  [MAJ-1] load_config() parsing strategy unspecified / stdlib-only constraint violated — replaced stdlib-only constraint with "stdlib preferred; pyyaml soft dependency for YAML parsing (same pattern as validate_artifact.py)"; added 5-step parsing algorithm to load_config() spec in T-06.5 (find heading, extract fenced block, try yaml.safe_load, ImportError fallback to hardcoded defaults + stderr warning); updated T-06.5 acceptance to require pyyaml import inside load_config() body only (not at module scope); updated D-01 to reflect pyyaml soft-dependency rationale.
  [MAJ-2] collect_entries() parsing algorithm unspecified — added RawEntry dataclass spec (6 fields: text, source_path, source_start_line, source_end_line, promote_tag, no_tag) and 5-step collect_entries() parsing algorithm (glob, split on \n---\n, skip blocks <10 chars, track line numbers, extract Promote? tags) to T-06.5 importable API section; moved collect_entries/RawEntry from internal helpers to public API; updated T-06.5 acceptance to include RawEntry in import check; updated T-07 to add fixture format requirement (\n---\n entry separator mandatory); updated T-08 test_default_weights_present to use sentinel key _source: claude_md in T-02 YAML block to distinguish live parse from hardcoded fallback, with pyyaml-absent skip path.
  [MAJ-3] sleep_dryrun_start.txt unconditional overwrite resets 30-day clock on every re-install — changed T-15 Edit 2 command from unconditional > to conditional [ -f ... ] || write; added success echo showing current marker date; updated T-15 acceptance to verify two-run idempotency (second bash install.sh must NOT update timestamp); updated D-03 to document conditional behavior; added R-15 to risk table.
  [MIN-1] Corpus-too-thin spike outcome has no compensating post-merge review trigger — added TODO comment write to .workflow_artifacts/memory/lessons-learned.md on corpus-too-thin guard in T-12.
  [MIN-2] Two sequential bash install.sh runs not explained — added NOTE to T-01 clarifying that the intermediate install.sh run (after T-01) deploys CLAUDE.md only, not sleep_score.py; the T-15 run is the second distinct run.
Issues deferred: none — all 3 MAJ and 2 MIN from round 2 addressed.
Changes: 18 tasks (unchanged count); RawEntry + collect_entries() added to public API; conditional dry-run marker write; sentinel key in T-02 YAML; 15 risks (R-15 added).

Round 4 — 2026-05-04
Critic verdict: REVISE
Issues addressed:
  [MAJ-1] collect_entries() split algorithm does not match real insights file format — replaced single-pass \n---\n split with two-pass algorithm: Pass 1 heading-based (split on lines matching `^### `, ≥2 such lines → canonical format matching insights-2026-04-25.md); Pass 2 separator-based (split on `^---\s*$` lines with surrounding blank-line consumption, fallback for <2 headings → matches insights-2026-05-01.md \n\n---\n\n format). Updated T-06.5 collect_entries() spec with both passes and their decision rule. Updated T-07 fixture format requirement: canonical format is now heading-based (`### Insight N:` with ≥2 headings), separator-based is backward-compat only. Added D-07 documenting the two-pass rationale. Updated T-06.5 acceptance to explicitly verify both real-file formats produce non-empty entry lists. Added R-16 to risk table.
  [MAJ-2] RawEntry → ScoredEntry field transformation unspecified — changed score_entries() signature from list[dict] to list[RawEntry]; added explicit statement that source_lines = f"{entry.source_start_line}..{entry.source_end_line}" is computed internally by score_entries(); added public API summary table showing all fields of both RawEntry and ScoredEntry with source column; added D-08 documenting rationale. Updated T-08 test_promote_hit to call collect_entries() then score_entries(entries, config) in sequence (no manual conversion step).
  [MIN-1] _source: claude_md sentinel runtime behavior undocumented — added NOTE to T-02 stating that _source is ignored at runtime (load_config() uses .get() for all threshold key lookups; unknown keys silently skipped). Added NOTE to T-06.5 load_config() spec that unknown keys in thresholds produce no error.
  [MIN-2] --escalate [no-redispatch] interaction not stated — added NOTE to T-06 ## --escalate flag spec: "[no-redispatch] guards the parent /sleep invocation from being re-dispatched; it does NOT prevent /sleep from spawning Opus children. The Opus subagent spawned by --escalate is an explicit forward dispatch, not a tier-switch of the current session."
  [MIN-3] T-08 acceptance criterion hardcodes "8 tests pass, 1 skipped" — replaced with "all non-skipped tests pass; pyyaml-dependent test skips gracefully when pyyaml absent; no hardcoded paths to user home."
  [MIN-4] /sleep SKILL.md process steps missing daily/<today>.md abort guard — added Step 0 to ## Process (default mode) spec in T-06: verify daily/<today>.md exists; if absent emit "Error: /sleep requires today's daily briefing (daily/<today>.md) — run /end_of_day first." and exit non-zero. Added note that guard fires only in standalone context (auto-chain path writes briefing before invoking /sleep). Updated T-06 acceptance to include prerequisite guard check.
Issues deferred: none — all 2 MAJ and 4 MIN addressed.
Changes: 18 tasks (unchanged count); two-pass collect_entries algorithm; score_entries API fix; sentinel documentation; --escalate clarification; test acceptance de-hardcoded; process Step 0 prerequisite guard; 16 risks (R-16 added); 2 new decisions (D-07, D-08).
