## Convergence Summary
- **Task profile:** Medium
- **Rounds:** 2
- **Final verdict:** PASS
- **Key revisions:** Round 1 fixed two structural issues: (1) Task 3 replaced impossible `_sdk_price_check()` with operationally valid `--list-models` flag; (2) added `--home PATH` CLI flag to enable JSONL test isolation without touching `~/.claude/`. Five mechanical fixes: canary string, write-md path spec, deferred scope note, overview SDK description, fixture JSONL schema.
- **Remaining concerns:** Two MINORs from round 2 — add `limit=100` note for `models.list()` pagination; clarify test 7 patching approach to call `_list_models()` directly rather than just importing the module.

## Implementation status — 2026-05-04 COMPLETE

All 6 tasks implemented and 11/11 tests passing.

| Task | Status | Commit |
|------|--------|--------|
| T1 quoin/.gitignore | DONE | f0e492f |
| T2 analyze_cost_ledger.py core | DONE | f0e492f |
| T3 --list-models flag (lazy anthropic import, limit=100) | DONE | 52d7ff5 |
| T4 tests + fixtures (11/11 pass) | DONE | 52d7ff5 |
| T5 install.sh wiring | DONE | 52d7ff5 |
| T6 git verification | DONE | verified |

**MINORs addressed:**
- `limit=100` included in `_list_models()` docstring and call
- Test 7 patches `sys.modules["anthropic"]` with a blocking module and calls `_list_models()` directly

---

## Overview

Stage 6 of `workflow-isolation-and-hooks` has two parallel scopes:

**Scope A — `analyze_cost_ledger.py`:** A new standalone analytics script that reads `.workflow_artifacts/<task>/cost-ledger.md` files, looks up per-session token counts from `~/.claude/projects/<hash>/*.jsonl`, computes cost using the existing `cost_from_jsonl.py` static price table (primary; no external dependency), and prints a structured summary to stdout. Optional `--write-md` flag saves the report. Does NOT replace `/cost_snapshot`. Pure stdlib by default; the Anthropic SDK is an optional lazy-import used only for the `--list-models` flag (Task 3), never for cost computation.

**Scope B — `quoin/.gitignore`:** The distributable `quoin/` package currently has no root-level `.gitignore`. Three runtime/personal artifact directories exist on disk (`quoin/.workflow_artifacts/`, `quoin/.claude/`, `quoin/.pytest_cache/`) and must be excluded. Git-tracking check confirms none are currently tracked, so `git rm --cached` is not required — a `.gitignore` alone is sufficient.

**Out of scope (deferred):** Model-tier drift detection (sessions where declared tier differed from actual model used) and model-tier downgrade suggestions are deferred. There is no post-S-1/S-2 production data yet to calibrate the Sonnet/Opus crossover threshold; implementing these sections now would require arbitrary hardcoded heuristics. They will be added in a future stage when real usage data is available.

Architecture reference: S-6 section + R-11 (ccusage drift mitigation); reuse `cost_from_jsonl.py` price table per lesson 2026-05-01.

---

## Task 1: Create `quoin/.gitignore`

**Description:**
Create a root-level `.gitignore` inside `quoin/` that permanently excludes runtime/personal artifact directories from ever being committed. The three targets are confirmed untracked (git ls-files --cached shows none of them), so no `git rm --cached` step is needed. The file should also exclude common Python dev artifacts that may appear during testing.

**Files to create:**
- `quoin/.gitignore` (NEW)

**Content:**
```
# Runtime / personal artifacts — never commit to the distributable quoin package
.workflow_artifacts/
.claude/
settings.local.json

# Python test / build artifacts
.pytest_cache/
__pycache__/
*.pyc
*.pyo
*.pyd
dist/
build/
*.egg-info/
```

Note: `quoin/dev/.gitignore` already covers `__pycache__/` and `.pytest_cache/` within `dev/`, but the root `quoin/.gitignore` is needed to cover the root-level `.pytest_cache/` that appears when running pytest from the `quoin/` directory.

**Acceptance criteria:**
- `quoin/.gitignore` exists at the repo root of the `quoin/` directory.
- Running `git -C quoin status` after creating `.gitignore` shows `.workflow_artifacts/`, `.claude/`, and `.pytest_cache/` are no longer listed as untracked.
- `quoin/settings.local.json` is excluded.
- No existing tracked files are affected (git ls-files --cached is unchanged).

**Estimated complexity:** XS

---

## Task 2: Implement `quoin/scripts/analyze_cost_ledger.py` — ledger parser and report engine

**Description:**
Create the core of the analytics script. This task covers: (a) ledger discovery and parsing, (b) JSONL lookup via the existing `cost_from_jsonl.py` logic, (c) static price-table fallback (reuse `PRICES` from `cost_from_jsonl.py`), (d) report generation to stdout. No Anthropic SDK in this task — that's Task 3.

The script is a standalone CLI tool. It follows the same conventions as `path_resolve.py` and `cost_from_jsonl.py`: stdlib-only by default, `argparse`, clean `main()` / `if __name__ == "__main__":` structure, meaningful exit codes (0 success, 1 error, 2 usage error).

**Ledger discovery logic:**
- Default: walk `.workflow_artifacts/` under the project root (cwd or `--project-root`) for all `*/cost-ledger.md` files, excluding `**/finalized/**` paths (per lesson 2026-05-01 — finalized dirs may contain template artifacts with `$(uuidgen)` literal strings).
- `--ledger <path>`: accept a single explicit ledger file path (overrides discovery).

**Ledger row parsing:**
- Tolerate 6-column and 7-column rows. Skip blank lines and `#` comments. Skip non-`task` category rows silently.
- Skip rows with UUID values containing `$(` (template artifacts).
- Warn on malformed rows to stderr, continue.

**JSONL cost lookup:**
- For each ledger row UUID, use `parse_session()` from `cost_from_jsonl.py`'s logic. Import `cost_from_jsonl` by direct path using `importlib.util.spec_from_file_location` pointing to `pathlib.Path(__file__).parent / "cost_from_jsonl.py"`. This works both from source (`quoin/scripts/`) and when deployed (`~/.claude/scripts/`).
- Project hash: use the `project_hash()` function from `cost_from_jsonl.py`.
- JSONL lookup: call `jsonl_path_for(uuid, proj_hash, home=home)` where `home` is derived from the `--home` CLI flag (default: `pathlib.Path.home()`). The `home` parameter already exists in `cost_from_jsonl.jsonl_path_for()` (line 64 of `cost_from_jsonl.py`); wire it through.
- If the JSONL file for a UUID does not exist: record cost as 0.0, mark as `no_jsonl` in the report. Never abort on missing JSONL.

**Report output (stdout):**
```
Cost Analysis — <project-root> — <date>
==========================================================================
Ledgers scanned: N  |  Sessions: M  |  Total cost: $X.XX
--------------------------------------------------------------------------
By phase:
  plan             $X.XX  (N sessions)
  critic           $X.XX  (N sessions)
  implement        $X.XX  (N sessions)
  ...

By model:
  claude-opus-4-7         $X.XX  (N sessions)
  claude-sonnet-4-6       $X.XX  (N sessions)
  ...

Top 10 most expensive sessions:
  1. $X.XX  <task-name>/<phase>  <UUID[:8]>  <date>
  ...

Fallback-fire summary:
  Total fallback fires: N  (sessions with fires: M)

Sessions with no JSONL (cost=0): N
==========================================================================
```

**CLI flags:**
- `--project-root <PATH>`: project root for ledger discovery + JSONL hash computation (default: cwd)
- `--ledger <PATH>`: single ledger file, skip discovery
- `--since <YYYY-MM-DD>`: filter rows to this date or later
- `--write-md`: write report to `<project-root>/.workflow_artifacts/memory/cost-analysis-<date>.md` (always relative to `--project-root`, never relative to cwd)
- `--top N`: how many sessions to show in "Top N" list (default: 10)
- `--home <PATH>`: override base path for JSONL lookup (default: `pathlib.Path.home()`). Used in tests to intercept JSONL lookup without touching `~/.claude/`. The path is passed as `home` to `jsonl_path_for()` so JSONL files are resolved as `<home>/.claude/projects/<hash>/<uuid>.jsonl`.

**Files to create:**
- `quoin/scripts/analyze_cost_ledger.py` (NEW)

**Acceptance criteria:**
- Script runs with `python3 analyze_cost_ledger.py --help` without error and without importing `anthropic`.
- Script parses a synthetic 6-column and 7-column ledger and produces the expected report structure.
- Missing JSONL files result in `cost=0` rows in the report, not crashes.
- Rows from `finalized/` directories are excluded from analysis.
- Rows with `$(uuidgen)` literal strings are skipped without crashing.
- `--write-md` writes to `<project-root>/.workflow_artifacts/memory/cost-analysis-<date>.md`; default mode writes to stdout only.
- `--home <PATH>` overrides the JSONL lookup base; passing `--home /tmp/test` causes the script to look for JSONL at `/tmp/test/.claude/projects/<hash>/<uuid>.jsonl`.
- Exit codes: 0 on success, 1 on IO error, 2 on bad CLI args.

**Estimated complexity:** M

---

## Task 3: Add optional `--list-models` flag (lazy-import Anthropic SDK)

**Description:**
Add a single optional `--list-models` flag to `analyze_cost_ledger.py`. When passed, the script lazy-imports `anthropic`, calls `anthropic.Anthropic().models.list()`, and prints the returned model IDs to stdout (one per line). This is the only operationally useful thing the SDK can do here — the SDK exposes `id`, `display_name`, and `created_at` for each model, but NO pricing data. Therefore the SDK is never used for cost computation; the static price table from `cost_from_jsonl.py` remains the sole source of pricing.

The `--check-sdk` cross-check concept from the original draft is dropped because `models.list()` returns no pricing metadata — there is nothing to cross-check against the static table.

The lazy-import pattern per lesson 2026-04-29:
```python
def _list_models() -> list[str] | None:
    try:
        import anthropic  # lazy-import — only if installed
        client = anthropic.Anthropic()
        return [m.id for m in client.models.list()]
    except ImportError:
        return None
```

**SDK usage scope:**
- Cost computation always uses the static price table from `cost_from_jsonl.py`. The SDK is NEVER used for cost computation.
- `--list-models` flag calls `_list_models()` and prints model IDs (or prints "anthropic SDK not installed" if import fails), then exits 0. It does NOT run the normal ledger analysis.
- If SDK unavailable and `--list-models` is not passed: no warning, no degradation, identical behavior to Task 2.

**Files to modify:**
- `quoin/scripts/analyze_cost_ledger.py` (extend Task 2 implementation)

**Acceptance criteria:**
- Without `anthropic` installed, `python3 analyze_cost_ledger.py` (without `--list-models`) produces identical output to Task 2 behavior.
- With `--list-models` and `anthropic` installed: prints one model ID per line and exits 0.
- With `--list-models` and `anthropic` NOT installed: prints "anthropic SDK not installed" and exits 0 (graceful degradation, not an error).
- `import anthropic` appears INSIDE a function body, never at module top level.
- `grep -n "^import anthropic" analyze_cost_ledger.py` returns no matches.
- `--list-models` does NOT run ledger analysis (it is a standalone informational sub-mode).

**Estimated complexity:** S

---

## Task 4: Write tests for `analyze_cost_ledger.py`

**Description:**
Create the test file at `quoin/scripts/tests/test_analyze_cost_ledger.py`. Tests must run without `anthropic` installed. Follow the pattern of existing tests in `quoin/dev/tests/` and `quoin/scripts/tests/`.

**Test cases:**

1. `test_parse_6col_ledger_row` — 6-column row parsed correctly, `fallback_fires` defaults to 0.
2. `test_parse_7col_ledger_row` — 7-column row parsed with correct `fallback_fires`.
3. `test_template_uuid_skipped` — row containing `$(uuidgen)` is skipped without error.
4. `test_finalized_dir_excluded` — ledger files under `finalized/` paths are excluded from discovery.
5. `test_missing_jsonl_yields_zero_cost` — UUID with no matching JSONL file produces `cost=0`, no crash.
6. `test_report_structure` — synthetic ledger + synthetic JSONL fixture produces expected stdout sections (phase breakdown, model breakdown, top-N list, fallback-fire summary). Pass `--home tmp_path` so the script finds the JSONL fixture at `tmp_path / ".claude" / "projects" / <hash> / <uuid>.jsonl`. Assert `totalCost > 0` for the matched session.
7. `test_no_anthropic_required` — import of `analyze_cost_ledger` module succeeds without `anthropic` in path (use `sys.modules` patching to simulate absence); script produces report.
8. `test_lazy_import_not_at_module_level` — AST inspection confirms `import anthropic` appears only inside a function body, never at module top level.
9. `test_write_md_creates_file` — `--write-md` mode writes a file. Pass `--project-root tmp_path` so the file lands in `tmp_path / ".workflow_artifacts" / "memory" / "cost-analysis-<date>.md"`. Assert the file exists at that path.
10. `test_since_filter` — `--since 2026-05-01` excludes rows with earlier dates.

**Fixtures needed:**
- `quoin/scripts/tests/fixtures/analyze_cost_ledger/sample-ledger.md` — synthetic cost ledger with 6-col and 7-col rows, one template UUID row, dates before and after a test cutoff.
- `quoin/scripts/tests/fixtures/analyze_cost_ledger/sample-session.jsonl` — minimal JSONL for test 6. Must contain at least one row with `{"message": {"model": "claude-sonnet-4-6", "usage": {"input_tokens": 1000, "output_tokens": 200}}}` so `parse_session()` returns a non-zero cost. The fixture UUID must match one of the UUIDs in `sample-ledger.md`. Test 6 must assert `totalCost > 0` for the matched session to confirm the JSONL was found and parsed correctly (not a tautology zero-cost pass).

**Test setup for test 6 (JSONL isolation):**
- Use `tmp_path` (pytest fixture).
- Compute `proj_hash` the same way the script does: `project_hash(str(project_root))`.
- Place the fixture at `tmp_path / ".claude" / "projects" / proj_hash / f"{uuid}.jsonl"`.
- Pass `--home tmp_path` to the script invocation; the script calls `jsonl_path_for(uuid, proj_hash, home=tmp_path)` which resolves to the fixture path without touching `~/.claude/`.

**Files to create:**
- `quoin/scripts/tests/test_analyze_cost_ledger.py` (NEW)
- `quoin/scripts/tests/fixtures/analyze_cost_ledger/sample-ledger.md` (NEW)
- `quoin/scripts/tests/fixtures/analyze_cost_ledger/sample-session.jsonl` (NEW)

**Acceptance criteria:**
- All 10 test cases pass with `python3 -m pytest quoin/scripts/tests/test_analyze_cost_ledger.py -v`.
- Tests pass when `anthropic` is not installed.
- No test modifies `~/.claude/` or any real cost ledger.
- Tests are deterministic.
- Test 6 asserts `totalCost > 0` (non-tautology cost check).
- Test 9 passes `--project-root tmp_path` and confirms the output file is at `tmp_path/.workflow_artifacts/memory/cost-analysis-<date>.md`.

**Estimated complexity:** M

---

## Task 5: Wire `analyze_cost_ledger.py` into `install.sh`

**Description:**
Add `analyze_cost_ledger.py` to the `install.sh` script deployment for-loop so it lands at `~/.claude/scripts/analyze_cost_ledger.py` on `bash install.sh`. Follow the exact same pattern as the existing scripts in the for-loop.

Also add `test_install_sh_deploys_analyze_cost_ledger` as an additional test case in `quoin/scripts/tests/test_analyze_cost_ledger.py` (substring check in `install.sh` for `analyze_cost_ledger.py` in the for-loop).

**Files to modify:**
- `quoin/install.sh` — extend the scripts deployment for-loop to include `analyze_cost_ledger.py`.

**Acceptance criteria:**
- `bash install.sh` copies `analyze_cost_ledger.py` to `~/.claude/scripts/analyze_cost_ledger.py`.
- `bash install.sh` exits 0.
- `test_install_sh_deploys_analyze_cost_ledger` test passes.
- The Stage 5 cleanup canary (`for obsolete in summarize_for_human.py with_env.sh audit_corpus_coverage.py`) remains unchanged (regression guard). The test assertion must use the full canary string including `audit_corpus_coverage.py`.

**Estimated complexity:** XS

---

## Task 6: Verify no undesired paths are git-tracked; finalize `.gitignore`

**Description:**
Verification step + final polish:

1. Run `git -C quoin ls-files --cached | grep -E "^\.(workflow_artifacts|claude|pytest_cache)"` and confirm output is empty. If any files are tracked, add `git rm --cached <file>` steps.
2. Confirm `quoin/.gitignore` covers `settings.local.json`.
3. Confirm `quoin/dev/.gitignore` still works correctly and the root `quoin/.gitignore` does not conflict.
4. Run `git status` in `quoin/` to confirm the three undesired directories no longer appear as untracked.

**Files to verify (no modifications expected):**
- `quoin/.gitignore` (created in Task 1)
- `quoin/dev/.gitignore` (already exists; verify no conflict)

**Acceptance criteria:**
- `git -C quoin ls-files --cached | grep -E "^\.(workflow_artifacts|claude|pytest_cache)"` returns empty.
- `git -C quoin status` does not show `.workflow_artifacts/`, `.claude/`, `.pytest_cache/`, or `settings.local.json` as untracked.
- `quoin/dev/.gitignore` is unchanged.
- No previously-tracked files appear as deleted in `git status`.

**Estimated complexity:** XS

---

## Dependency order

1. Task 1 (`.gitignore`) — no dependencies, can go first.
2. Task 2 (script core) — no dependencies on Task 1; can start in parallel with Task 1.
3. Task 3 (`--list-models` flag) — depends on Task 2.
4. Task 4 (tests) — depends on Tasks 2 and 3.
5. Task 5 (install.sh wiring) — depends on Task 2; can run alongside Task 4.
6. Task 6 (git verification) — depends on Task 1; best run last as confirmation.

---

## Implementation notes

**Reusing `cost_from_jsonl.py` internals:** Import via `importlib.util.spec_from_file_location` pointing to `pathlib.Path(__file__).parent / "cost_from_jsonl.py"`. At runtime (deployed to `~/.claude/scripts/`) and at source time (`quoin/scripts/`) this path works identically.

**Finalized directory exclusion:** Use `pathlib.Path.rglob("*/cost-ledger.md")` then filter with `"finalized" not in p.parts`.

**Lazy-import location:** `import anthropic` goes inside the `_list_models()` function body. The `--list-models` flag gates the call, so even with the SDK installed it is not imported unless the user requests it.

**Test isolation for JSONL lookup:** The `--home PATH` flag overrides the base directory for `jsonl_path_for()`. Tests pass `--home tmp_path` and place fixtures at `tmp_path / ".claude" / "projects" / <hash> / <uuid>.jsonl`. This pattern mirrors the existing `home=` parameter in `cost_from_jsonl.jsonl_path_for()` (line 64 of `cost_from_jsonl.py`). No test ever writes to `~/.claude/`.

**`--write-md` output path:** Always `<project-root>/.workflow_artifacts/memory/cost-analysis-<date>.md`. The `project-root` defaults to cwd but is overridden by `--project-root`. Never relative to cwd when `--project-root` is passed. Test 9 must pass `--project-root tmp_path` to keep writes isolated.

**SDK note:** The Anthropic Python SDK's `models.list()` returns only `id`, `display_name`, and `created_at` — it has no pricing endpoint. The `--list-models` flag is the one operationally useful function the SDK serves here (confirming connectivity and listing known model IDs). Price-table parity is verified statically by `test_cost_parity_with_ccusage.py`, not at runtime.
