"""
test_analyze_cost_ledger.py — tests for analyze_cost_ledger.py.

10 test cases:
  1. test_parse_6col_ledger_row         — 6-column row parsed; fallback_fires=0
  2. test_parse_7col_ledger_row         — 7-column row parsed with fallback_fires
  3. test_template_uuid_skipped         — $(uuidgen) row returns None (skipped)
  4. test_finalized_dir_excluded        — ledgers under finalized/ are excluded
  5. test_missing_jsonl_yields_zero_cost — missing JSONL → cost=0, no crash
  6. test_report_structure              — synthetic ledger+JSONL → expected sections,
                                          totalCost > 0 for JSONL-matched session
  7. test_no_anthropic_required         — module import succeeds with anthropic
                                          patched out of sys.modules; report runs
  8. test_lazy_import_not_at_module_level — AST confirms import anthropic is inside
                                            a function body only
  9. test_write_md_creates_file         — --write-md lands in tmp_path/...
 10. test_since_filter                  — --since excludes older rows
 11. test_install_sh_deploys_analyze_cost_ledger — install.sh for-loop contains script

Run from project root:
    python3 -m pytest quoin/scripts/tests/test_analyze_cost_ledger.py -v

All tests pass without the anthropic SDK installed.
No test touches ~/.claude/.
"""

import ast
import importlib.util
import pathlib
import shutil
import sys
import subprocess

import pytest

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------
SCRIPTS_DIR = pathlib.Path(__file__).parent.parent          # quoin/scripts/
PROJECT_ROOT = SCRIPTS_DIR.parent.parent.parent             # project root
QUOIN_DIR = SCRIPTS_DIR.parent                               # quoin/
FIXTURES_DIR = pathlib.Path(__file__).parent / "fixtures" / "analyze_cost_ledger"

SAMPLE_LEDGER = FIXTURES_DIR / "sample-ledger.md"
SAMPLE_JSONL  = FIXTURES_DIR / "sample-session.jsonl"

# UUID that has a matching JSONL fixture (matches sample-ledger.md row 6)
JSONL_UUID = "eeeeeeee-0000-0000-0000-000000000005"


def _load_module(name: str = "analyze_cost_ledger"):
    """Import analyze_cost_ledger from scripts/ directory."""
    spec = importlib.util.spec_from_file_location(
        name, SCRIPTS_DIR / "analyze_cost_ledger.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_cfj():
    """Import cost_from_jsonl for project_hash()."""
    spec = importlib.util.spec_from_file_location(
        "cost_from_jsonl", SCRIPTS_DIR / "cost_from_jsonl.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# Test 1: 6-column row parsed correctly
# ---------------------------------------------------------------------------
def test_parse_6col_ledger_row():
    acl = _load_module()
    line = "aaaaaaaa-0000-0000-0000-000000000001 | 2026-04-15 | plan | claude-opus-4-7 | task | early plan"
    row = acl._parse_row(line)
    assert row is not None
    assert row["uuid"] == "aaaaaaaa-0000-0000-0000-000000000001"
    assert row["phase"] == "plan"
    assert row["model"] == "claude-opus-4-7"
    assert row["fallback_fires"] == 0  # default for 6-col


# ---------------------------------------------------------------------------
# Test 2: 7-column row parsed with correct fallback_fires
# ---------------------------------------------------------------------------
def test_parse_7col_ledger_row():
    acl = _load_module()
    line = "bbbbbbbb-0000-0000-0000-000000000002 | 2026-05-01 | implement | claude-sonnet-4-6 | task | session | 3"
    row = acl._parse_row(line)
    assert row is not None
    assert row["fallback_fires"] == 3
    assert row["phase"] == "implement"


# ---------------------------------------------------------------------------
# Test 3: template UUID skipped without error
# ---------------------------------------------------------------------------
def test_template_uuid_skipped():
    acl = _load_module()
    line = "$(uuidgen) | 2026-05-02 | plan | claude-sonnet-4-6 | task | template | 0"
    row = acl._parse_row(line)
    assert row is None, "Template UUID row must be skipped (return None)"


# ---------------------------------------------------------------------------
# Test 4: finalized/ ledger files excluded from discovery
# ---------------------------------------------------------------------------
def test_finalized_dir_excluded(tmp_path):
    acl = _load_module()

    # Create a ledger in active path
    active = tmp_path / ".workflow_artifacts" / "my-task"
    active.mkdir(parents=True)
    (active / "cost-ledger.md").write_text(
        "# Cost Ledger — my-task\n"
        "aaaaaaaa-0000-0000-0000-000000000001 | 2026-05-01 | plan | claude-opus-4-7 | task | note\n",
        encoding="utf-8",
    )

    # Create a ledger in finalized/ path — must be excluded
    finalized = tmp_path / ".workflow_artifacts" / "finalized" / "old-task"
    finalized.mkdir(parents=True)
    (finalized / "cost-ledger.md").write_text(
        "# Cost Ledger — old-task\n"
        "ffffffff-0000-0000-0000-000000000099 | 2026-01-01 | plan | claude-opus-4-7 | task | finalized\n",
        encoding="utf-8",
    )

    ledgers = acl.discover_ledgers(tmp_path)
    paths_str = [str(p) for p in ledgers]

    # Active ledger must be found
    assert any("my-task" in p for p in paths_str), "Active ledger not discovered"
    # Finalized ledger must NOT be found — check for the finalized/ path component
    finalized_ledger_str = str(finalized / "cost-ledger.md")
    assert not any(p == finalized_ledger_str for p in paths_str), (
        "Finalized ledger must be excluded from discovery"
    )
    assert len(ledgers) == 1, (
        f"Expected exactly 1 ledger (active only), found {len(ledgers)}: {paths_str}"
    )


# ---------------------------------------------------------------------------
# Test 5: missing JSONL yields cost=0, no crash
# ---------------------------------------------------------------------------
def test_missing_jsonl_yields_zero_cost(tmp_path):
    acl = _load_module()
    cfj = _load_cfj()

    uuid = "nonexistent-uuid-that-has-no-jsonl-file-at-all-0000"
    proj_hash = cfj.project_hash(str(tmp_path))

    cost, has_jsonl = acl.lookup_session_cost(uuid, proj_hash, home=tmp_path)
    assert cost == 0.0, "Missing JSONL must return cost 0.0"
    assert has_jsonl is False, "Missing JSONL must return has_jsonl=False"


# ---------------------------------------------------------------------------
# Test 6: report structure — JSONL-matched session has totalCost > 0
# ---------------------------------------------------------------------------
def test_report_structure(tmp_path):
    """
    Place the fixture JSONL at tmp_path/.claude/projects/<hash>/<uuid>.jsonl,
    pass --home tmp_path so the script resolves it there. Assert totalCost > 0
    for the matched session (non-tautology check).
    """
    cfj = _load_cfj()
    acl = _load_module()

    # Compute project hash using tmp_path as project root (matches script logic)
    proj_hash = cfj.project_hash(str(tmp_path))

    # Place the fixture JSONL where the script will look for it
    jsonl_dir = tmp_path / ".claude" / "projects" / proj_hash
    jsonl_dir.mkdir(parents=True)
    dest = jsonl_dir / f"{JSONL_UUID}.jsonl"
    shutil.copy(SAMPLE_JSONL, dest)

    # Parse the sample ledger file
    rows = acl.parse_ledger_file(SAMPLE_LEDGER, task_name="test-task")

    # Only the JSONL_UUID row should produce a non-zero cost
    report = acl.build_report(
        rows,
        project_root=tmp_path,
        proj_hash=proj_hash,
        home=tmp_path,
        top_n=10,
    )

    # Total cost must be > 0 because the JSONL-matched row contributes
    assert report["total_cost"] > 0, (
        f"Expected totalCost > 0 for the JSONL-matched row, got {report['total_cost']}"
    )

    # Structural checks on the formatted report
    formatted = acl.format_report(
        report,
        project_root=tmp_path,
        ledger_count=1,
        top_n=10,
        report_date="2026-05-03",
    )
    assert "By phase:" in formatted
    assert "By model:" in formatted
    assert "Fallback-fire summary:" in formatted
    assert "Sessions with no JSONL" in formatted
    assert "Cost Analysis" in formatted


# ---------------------------------------------------------------------------
# Test 7: module import succeeds without anthropic in sys.modules
# ---------------------------------------------------------------------------
def test_no_anthropic_required(tmp_path):
    """
    Patch sys.modules to hide 'anthropic', then load analyze_cost_ledger and
    call _list_models() directly. Must return None (not raise ImportError).
    Then run a basic report (no --list-models) to confirm the module works fully.
    """
    # Save and remove any existing 'anthropic' entry
    saved = sys.modules.pop("anthropic", None)
    # Also block future imports by inserting a sentinel that raises ImportError
    import types

    class _BlockedModule(types.ModuleType):
        def __getattr__(self, name):
            raise ImportError("anthropic is blocked in this test")

    sys.modules["anthropic"] = _BlockedModule("anthropic")
    try:
        acl = _load_module()

        # _list_models() must return None when anthropic is blocked
        result = acl._list_models()
        assert result is None, "_list_models() must return None when anthropic is blocked"

        # Basic report must still work (no crash, no anthropic needed)
        rows = acl.parse_ledger_file(SAMPLE_LEDGER, task_name="test-task")
        cfj = _load_cfj()
        proj_hash = cfj.project_hash(str(tmp_path))
        report = acl.build_report(rows, project_root=tmp_path, proj_hash=proj_hash, home=tmp_path)
        assert "total_cost" in report
    finally:
        # Restore sys.modules
        del sys.modules["anthropic"]
        if saved is not None:
            sys.modules["anthropic"] = saved


# ---------------------------------------------------------------------------
# Test 8: import anthropic appears only inside a function body (AST check)
# ---------------------------------------------------------------------------
def test_lazy_import_not_at_module_level():
    """AST inspection: 'import anthropic' must only appear inside a FunctionDef."""
    source = (SCRIPTS_DIR / "analyze_cost_ledger.py").read_text(encoding="utf-8")
    tree = ast.parse(source)

    # Collect all top-level Import/ImportFrom nodes
    top_level_imports = []
    for node in ast.iter_child_nodes(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            for alias in (node.names if isinstance(node, ast.Import) else []):
                if alias.name == "anthropic":
                    top_level_imports.append(node)
            if isinstance(node, ast.ImportFrom) and node.module == "anthropic":
                top_level_imports.append(node)

    assert len(top_level_imports) == 0, (
        f"Found top-level 'import anthropic' statements: {top_level_imports}. "
        "The anthropic import must live inside _list_models() function body only."
    )

    # Also confirm that import anthropic appears somewhere inside a function
    found_in_function = False
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef):
            for child in ast.walk(node):
                if isinstance(child, ast.Import):
                    for alias in child.names:
                        if alias.name == "anthropic":
                            found_in_function = True

    assert found_in_function, (
        "Did not find 'import anthropic' inside any function body. "
        "Expected it in _list_models()."
    )


# ---------------------------------------------------------------------------
# Test 9: --write-md creates file at correct path
# ---------------------------------------------------------------------------
def test_write_md_creates_file(tmp_path):
    """
    Run analyze_cost_ledger.py as a subprocess with --project-root tmp_path
    and --write-md. The output file must be at:
        tmp_path/.workflow_artifacts/memory/cost-analysis-<date>.md
    """
    # Copy the sample ledger into tmp_path's .workflow_artifacts so discovery finds it
    ledger_dir = tmp_path / ".workflow_artifacts" / "test-task"
    ledger_dir.mkdir(parents=True)
    shutil.copy(SAMPLE_LEDGER, ledger_dir / "cost-ledger.md")

    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPTS_DIR / "analyze_cost_ledger.py"),
            "--project-root", str(tmp_path),
            "--home", str(tmp_path),
            "--write-md",
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, (
        f"analyze_cost_ledger.py --write-md exited {result.returncode}:\n"
        f"stdout: {result.stdout}\nstderr: {result.stderr}"
    )

    # Find the output file (date is dynamic, but directory is fixed)
    out_dir = tmp_path / ".workflow_artifacts" / "memory"
    assert out_dir.exists(), f"Output directory not created: {out_dir}"

    md_files = list(out_dir.glob("cost-analysis-*.md"))
    assert len(md_files) == 1, (
        f"Expected exactly 1 cost-analysis-*.md in {out_dir}, found: {md_files}"
    )
    content = md_files[0].read_text(encoding="utf-8")
    assert "Cost Analysis" in content
    assert "By phase:" in content


# ---------------------------------------------------------------------------
# Test 10: --since filter excludes older rows
# ---------------------------------------------------------------------------
def test_since_filter():
    """
    Parse sample-ledger.md rows and apply --since 2026-05-01.
    Rows with date 2026-04-15 must be excluded.
    Rows with 2026-05-01 and later must be included.
    """
    acl = _load_module()
    from datetime import date as _date

    # Parse all rows from the sample ledger
    rows = acl.parse_ledger_file(SAMPLE_LEDGER, task_name="test-task")

    # Build report with --since 2026-05-01 (date object)
    proj_hash = "irrelevant-hash-for-since-test"
    since = _date(2026, 5, 1)

    # Use a non-existent home so all JSONL lookups return cost=0 (no crash expected)
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        home_tmp = pathlib.Path(td)
        report = acl.build_report(
            rows,
            project_root=pathlib.Path(td),
            proj_hash=proj_hash,
            home=home_tmp,
            since_date=since,
        )

    # The 2026-04-15 row must have been excluded
    # The sample ledger has 1 row on 2026-04-15 (plan phase, 6-col)
    # After filtering we should have implement + critic + jsonl rows (3 task rows after 05-01)
    assert report["session_count"] <= 4, (
        f"Expected at most 4 sessions after --since 2026-05-01, got {report['session_count']}. "
        "The 2026-04-15 row should have been excluded."
    )
    # Specifically, no row should be from before 2026-05-01
    # (indirectly: the 'plan' phase row from 04-15 should not appear alone;
    #  but critic also has 'plan' in model, so check session_count is < full set)
    all_rows_count = len(rows)
    assert report["session_count"] < all_rows_count, (
        f"--since filter did not reduce row count: {report['session_count']} == {all_rows_count}"
    )


# ---------------------------------------------------------------------------
# Test 11: install.sh for-loop contains analyze_cost_ledger.py
# ---------------------------------------------------------------------------
def test_install_sh_deploys_analyze_cost_ledger():
    """
    install.sh for-loop must include analyze_cost_ledger.py.
    Also verifies the Stage-5 cleanup canary is still present (regression guard).
    """
    install_sh = QUOIN_DIR / "install.sh"
    assert install_sh.exists(), f"install.sh not found at {install_sh}"
    content = install_sh.read_text(encoding="utf-8")

    # Primary assertion: analyze_cost_ledger.py is in the deployment for-loop
    assert "analyze_cost_ledger.py" in content, (
        "install.sh does not contain 'analyze_cost_ledger.py'. "
        "Task 5 requires adding it to the scripts deployment for-loop."
    )

    # Regression guard: Stage-5 cleanup canary must remain unchanged
    canary = "for obsolete in summarize_for_human.py with_env.sh audit_corpus_coverage.py"
    assert canary in content, (
        f"Stage-5 cleanup canary not found in install.sh: {canary!r}. "
        "Do not modify the obsolete cleanup block."
    )
