"""
Regression test: no unsubstituted shell-variable placeholders in active cost-ledger rows.

Checks two things:
1. Active cost ledgers (`.workflow_artifacts/*/cost-ledger.md`, excluding finalized/)
   contain no data rows with the literal substrings `$(` or `$ENV`.
2. `quoin/CLAUDE.md` — the `$(uuidgen)` one-liner appears ONLY inside fenced code
   blocks (triple-backtick), never in a bare prose line.

Run from project root:
    python3 quoin/scripts/tests/test_ledger_no_placeholder.py

Exit 0 on pass, 1 on first failure found.
"""

import argparse
import pathlib
import sys


PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[3]  # three levels up from tests/


def _is_finalized(path: pathlib.Path) -> bool:
    """Return True if the path is inside a finalized/ directory."""
    parts = path.parts
    return "finalized" in parts


def check_active_ledgers():
    """
    Walk .workflow_artifacts/*/cost-ledger.md (excluding finalized/).
    Return a list of failure messages (empty = all clear).
    """
    failures = []
    ledger_glob = PROJECT_ROOT / ".workflow_artifacts"
    if not ledger_glob.exists():
        return []  # nothing to check

    for ledger_path in ledger_glob.rglob("cost-ledger.md"):
        if _is_finalized(ledger_path):
            continue  # historical finalized rows are immutable; skip per D-08
        try:
            lines = ledger_path.read_text(encoding="utf-8").splitlines()
        except OSError as exc:
            failures.append(f"ERROR reading {ledger_path}: {exc}")
            continue

        for lineno, line in enumerate(lines, start=1):
            stripped = line.strip()
            # Skip blank lines, comment lines, and the header line
            if not stripped or stripped.startswith("#") or stripped.startswith("|"):
                continue
            if "$(" in stripped:
                failures.append(
                    f"FAIL: unsubstituted `$(` in {ledger_path}:{lineno}: {stripped!r}"
                )
            if "$ENV" in stripped:
                failures.append(
                    f"FAIL: unsubstituted `$ENV` in {ledger_path}:{lineno}: {stripped!r}"
                )
    return failures


def check_claude_md_one_liner_fenced():
    """
    Assert that `$(uuidgen)` appears in quoin/CLAUDE.md ONLY inside fenced
    code blocks (delimited by triple backticks).

    Returns a list of failure messages (empty = all clear).
    """
    claude_md = PROJECT_ROOT / "quoin" / "CLAUDE.md"
    if not claude_md.exists():
        return [f"FAIL: quoin/CLAUDE.md not found at {claude_md}"]

    lines = claude_md.read_text(encoding="utf-8").splitlines()

    # Collect all text that appears inside triple-backtick fences
    fenced_content_lines = []
    in_fence = False
    fence_marker = ""

    for line in lines:
        stripped = line.strip()
        if not in_fence:
            # Detect opening fence: ``` or ```` (with optional language tag)
            if stripped.startswith("```"):
                in_fence = True
                # Capture fence length so we match the right closing marker
                fence_marker = stripped[:3] if not stripped.startswith("````") else stripped[:4]
            # else: normal prose — do not collect
        else:
            # Inside a fence
            if stripped.startswith(fence_marker) and stripped == stripped[:len(fence_marker)]:
                in_fence = False
                fence_marker = ""
            else:
                fenced_content_lines.append(line)

    fenced_content = "\n".join(fenced_content_lines)

    failures = []
    if "$(uuidgen)" not in fenced_content:
        failures.append(
            "FAIL: `$(uuidgen)` not found inside any fenced code block in quoin/CLAUDE.md. "
            "The one-liner must be documented inside a triple-backtick fence."
        )

    # Also check: $(uuidgen) should NOT appear in prose lines (outside fences)
    prose_lines = []
    in_fence = False
    fence_marker = ""
    for line in lines:
        stripped = line.strip()
        if not in_fence:
            if stripped.startswith("```"):
                in_fence = True
                fence_marker = stripped[:3] if not stripped.startswith("````") else stripped[:4]
            else:
                prose_lines.append(line)
        else:
            if stripped.startswith(fence_marker) and stripped == stripped[:len(fence_marker)]:
                in_fence = False
                fence_marker = ""

    for prose_line in prose_lines:
        if "$(uuidgen)" in prose_line:
            failures.append(
                f"FAIL: `$(uuidgen)` found in prose (outside fence) in quoin/CLAUDE.md: {prose_line!r}"
            )

    return failures


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Regression test: active cost-ledger rows must not contain unsubstituted "
            "shell-variable placeholders; quoin/CLAUDE.md $(uuidgen) must be inside a fence."
        )
    )
    parser.parse_args()  # --help exits here

    failures = []
    failures.extend(check_active_ledgers())
    failures.extend(check_claude_md_one_liner_fenced())

    if failures:
        for msg in failures:
            print(msg, file=sys.stderr)
        return 1

    active_ledger_count = sum(
        1
        for p in (PROJECT_ROOT / ".workflow_artifacts").rglob("cost-ledger.md")
        if not _is_finalized(p)
    ) if (PROJECT_ROOT / ".workflow_artifacts").exists() else 0
    print(
        f"PASS: {active_ledger_count} active ledger(s) checked — no unsubstituted placeholders. "
        f"quoin/CLAUDE.md $(uuidgen) is fence-only."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
