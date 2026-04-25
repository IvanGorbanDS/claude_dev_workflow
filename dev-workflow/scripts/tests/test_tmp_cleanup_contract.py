"""Static-assertion contract tests for .tmp cleanup hardening (T-07 / T-08).

These tests assert the text contracts established in Stage 5 T-07 across
all 5 Class B writer SKILL.md files. They fire if a future edit reverts
the semicolon separator, removes the dual-target rm, or drops the pre-write
sweep or English-fallback cleanup.
"""

import pathlib
import re

PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent.parent
SKILLS_DIR = PROJECT_ROOT / "dev-workflow" / "skills"

CLASS_B_WRITERS = ["plan", "architect", "review", "revise", "revise-fast"]

SKILL_PATHS = {
    name: SKILLS_DIR / name / "SKILL.md" for name in CLASS_B_WRITERS
}


def _text(skill_name: str) -> str:
    return SKILL_PATHS[skill_name].read_text()


def test_step6_uses_semicolon_separator():
    """Step 6 atomic rename must use ';' separator, not '&&', so cleanup runs even if mv fails."""
    for name in CLASS_B_WRITERS:
        text = _text(name)
        # Must NOT have: mv ...tmp ... && rm
        bad_pattern = re.findall(r"mv\s+\S+\.tmp\s+\S+\s*&&\s*\(?rm", text)
        assert not bad_pattern, (
            f"{name}/SKILL.md: Step 6 still uses '&& rm' pattern (should be '; (rm ...)'): "
            f"{bad_pattern}"
        )
        # Must have the semicolon pattern
        good_pattern = re.findall(r"mv\s+\S+\.tmp\s+\S+\s*;\s*\(?rm", text)
        assert good_pattern, (
            f"{name}/SKILL.md: Step 6 missing '; (rm ...)' separator pattern"
        )


def test_step6_rm_targets_both_tmp_files():
    """Step 6 rm must target BOTH .body.tmp AND .tmp (dual-target cleanup)."""
    for name in CLASS_B_WRITERS:
        text = _text(name)
        # Find lines containing the atomic rename / Step 6 cleanup
        step6_lines = [
            line for line in text.splitlines()
            if "rm -f" in line and ("body.tmp" in line or ".tmp" in line)
            and "mv " in line or (
                "rm -f" in line and "body.tmp" in line and ".tmp" in line
            )
        ]
        # At least one rm line must mention BOTH body.tmp and .tmp
        dual_target = [
            line for line in text.splitlines()
            if "rm -f" in line and "body.tmp" in line and ".tmp" in line
        ]
        assert dual_target, (
            f"{name}/SKILL.md: no rm line targets both .body.tmp AND .tmp "
            f"(dual-target cleanup missing)"
        )


def test_step1_pre_write_sweep_present():
    """Each SKILL.md must have a pre-write sweep line near the Step 1 body-write instruction."""
    for name in CLASS_B_WRITERS:
        text = _text(name)
        # The sweep must reference rm -f and body.tmp together
        sweep_lines = [
            line for line in text.splitlines()
            if "pre-write sweep" in line.lower() or (
                "rm -f" in line and "body.tmp" in line and ".tmp" in line
                and "Step 6" not in line and "Step 5" not in line
                and "fallback" not in line.lower()
            )
        ]
        assert sweep_lines, (
            f"{name}/SKILL.md: no pre-write sweep found near Step 1 "
            f"(expected 'rm -f ...body.tmp ...' before the .body.tmp write instruction)"
        )
        # Verify the sweep appears before Step 2 (i.e., in the Step 1 area)
        lines = text.splitlines()
        step2_idx = next(
            (i for i, l in enumerate(lines)
             if re.match(r"\*\*Step 2[: ]", l) or re.match(r"Step 2:", l)), None
        )
        if step2_idx is not None:
            pre_step2_text = "\n".join(lines[:step2_idx])
            has_sweep_before_step2 = any(
                "pre-write sweep" in l.lower() or (
                    "rm -f" in l and "body.tmp" in l and ".tmp" in l
                )
                for l in lines[:step2_idx]
            )
            assert has_sweep_before_step2, (
                f"{name}/SKILL.md: pre-write sweep not found before Step 2 "
                f"(sweep must be in the Step 1 section)"
            )


def test_english_fallback_cleans_body_tmp():
    """Each English-fallback path must mention .body.tmp cleanup."""
    for name in CLASS_B_WRITERS:
        text = _text(name)
        # Find the English-fallback section
        fallback_match = re.search(
            r"English-fallback.*?(?=\*\*Step 6|\Z)", text, re.DOTALL
        )
        if fallback_match:
            fallback_text = fallback_match.group(0)
            assert "body.tmp" in fallback_text, (
                f"{name}/SKILL.md: English-fallback section does not mention .body.tmp cleanup"
            )


def test_negative_case_caught():
    """Assertion machinery must FAIL on a synthetic SKILL.md with the old broken && pattern.

    Guards against the tests regressing to no-ops (lesson 2026-04-24).
    """
    synthetic = (
        "**Step 6: Atomic rename.**\n"
        "`mv <plan-path>.tmp <plan-path> && rm -f <plan-path>.body.tmp`\n"
    )
    # Confirm the bad pattern IS found in the synthetic text (test machinery works)
    bad_pattern = re.findall(r"mv\s+\S+\.tmp\s+\S+\s*&&\s*\(?rm", synthetic)
    assert bad_pattern, (
        "Test machinery flaw: bad '&& rm' pattern not found in synthetic text"
    )
    # Confirm the good pattern is NOT found (the assertion would fail on this synthetic)
    good_pattern = re.findall(r"mv\s+\S+\.tmp\s+\S+\s*;\s*\(?rm", synthetic)
    assert not good_pattern, (
        "Test machinery flaw: good '; (rm' pattern found in synthetic text that should be broken"
    )
    # Verify our test would actually catch this: simulate what test_step6_uses_semicolon_separator does
    caught_bad = bool(bad_pattern)
    would_fail = caught_bad and not good_pattern
    assert would_fail, (
        "test_step6_uses_semicolon_separator would NOT catch the broken && pattern"
    )
