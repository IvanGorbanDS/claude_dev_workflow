"""
Static test: verify that /implement SKILL.md contains the large-tool-result
gating subsection with correct literal constants and fail-OPEN warning.

This is a STATIC test — the dispatch behavior of /implement is runtime-only
(it is a skill prompt, not a Python module). Static substring checks catch
documentation drift. Runtime behavior is verified via the soak in T-13 AC-3.

Run from project root:
    python3 quoin/scripts/tests/test_implement_large_result_gate.py

Exit 0 on pass, 1 on failure.
"""

import argparse
import pathlib
import sys

PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[3]
SKILL_MD = PROJECT_ROOT / "quoin" / "skills" / "implement" / "SKILL.md"

# Required literal substrings in SKILL.md
REQUIRED_LITERALS = [
    "LARGE_TOOL_RESULT_THRESHOLD_BYTES = 5120",
    "5120",
    "5 KB",
    '"sonnet"',
    "[implement-stage-5: large-result summarizer unavailable;",
]

# Forbidden patterns: SKILL.md must NOT use a Python subprocess for the summarizer
# (per lesson 2026-04-29 — dispatch is via Agent tool, not Python subprocess)
FORBIDDEN_IN_SUBSECTION = [
    "subprocess.run",
    "subprocess.call",
    "subprocess.Popen",
]


def _read_skill_md():
    if not SKILL_MD.exists():
        return None, [f"FAIL: {SKILL_MD} not found"]
    return SKILL_MD.read_text(encoding="utf-8"), []


def _extract_subsection(content, heading):
    """
    Extract text between the given H3 heading and the next H3 or H2 heading.
    Returns the subsection text or empty string if not found.
    """
    lines = content.splitlines()
    in_section = False
    section_lines = []
    for line in lines:
        if line.strip() == heading:
            in_section = True
            continue
        if in_section:
            if line.startswith("### ") or line.startswith("## "):
                break
            section_lines.append(line)
    return "\n".join(section_lines)


def check_required_literals(content):
    failures = []
    for literal in REQUIRED_LITERALS:
        if literal not in content:
            failures.append(
                f"FAIL: SKILL.md missing required literal: {literal!r}"
            )
    return failures


def check_no_subprocess_in_subsection(content):
    subsection = _extract_subsection(
        content, "### Large tool-result gating (cache-preservation)"
    )
    failures = []
    for pattern in FORBIDDEN_IN_SUBSECTION:
        if pattern in subsection:
            failures.append(
                f"FAIL: SKILL.md subsection contains forbidden subprocess pattern: {pattern!r}. "
                f"Dispatch must use the Agent tool, not subprocess (per lesson 2026-04-29)."
            )
    return failures


def check_subsection_present(content):
    heading = "### Large tool-result gating (cache-preservation)"
    if heading not in content:
        return [f"FAIL: SKILL.md missing subsection heading: {heading!r}"]
    return []


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Static test: /implement SKILL.md must contain the large-tool-result "
            "gating subsection with required constant literals and fail-OPEN warning, "
            "and must NOT use subprocess for the summarizer dispatch."
        )
    )
    parser.parse_args()

    content, init_failures = _read_skill_md()
    if init_failures:
        for msg in init_failures:
            print(msg, file=sys.stderr)
        return 1

    failures = []
    failures.extend(check_subsection_present(content))
    failures.extend(check_required_literals(content))
    failures.extend(check_no_subprocess_in_subsection(content))

    if failures:
        for msg in failures:
            print(msg, file=sys.stderr)
        return 1

    print(
        "PASS: /implement SKILL.md has large-tool-result gating subsection with "
        "required constants, fail-OPEN warning, and no subprocess dispatch."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
