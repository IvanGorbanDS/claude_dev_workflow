# Critic Response -- Round 1

## Verdict: REVISE

One MAJOR issue needs addressing before implementation; the rest are minor.

## Issues Found

### MAJOR -- "Stay factual" guidance conflicts with existing "Capture the narrative" instruction in `/weekly_review`

**Location in plan:** Task 4, change #4 (adding "Stay factual" to Important behaviors)

**What's wrong:** The plan adds a new bullet to the Important behaviors section: "Stay factual. Report what happened based on the data sources. Do not infer intent, mood, or momentum unless the data explicitly says so." However, the existing bullet immediately above it (line 145) says: "Capture the narrative. The weekly review tells the story of the week. Connect the dots between tasks." These two instructions directly contradict each other -- "capture the narrative" and "connect the dots" requires inference and synthesis, while "stay factual" and "do not infer" forbids it. Sonnet can navigate this ambiguity; Haiku is more likely to freeze up or follow whichever instruction it reads last, producing inconsistent output. On a Haiku model, contradictory instructions are a real quality risk.

**Suggested fix:** Either (a) remove the "Capture the narrative" bullet when adding "Stay factual," replacing narrative synthesis with a simpler instruction like "If tasks are related, note the connection factually (e.g., 'Task B was created as a follow-up to Task A')," or (b) soften the "Stay factual" addition to say "Prefer factual reporting over narrative interpretation. When connecting tasks, state the observable relationship rather than inferring intent or momentum." This removes the contradiction while still steering Haiku away from speculation.

### MINOR -- Line number off-by-one in Task 4 "Next Week" section

**Location in plan:** Task 4, change #3

**What's wrong:** The plan says the "Next Week" text to replace is at "line 98." The actual `<Based on in-progress work, blockers, and momentum...>` text is at line 97. The closing ``` of the template is at line 98. An implementer following the plan literally would look at line 98 and find the wrong content.

**Suggested fix:** Change "line 98" to "line 97" or simply say "in the 'Next Week' section of the template" without specifying a line number, since the text to match is unambiguous.

### MINOR -- Plan does not mention the `~/.claude/CLAUDE.md` model table explicitly enough

**Location in plan:** Scope section ("Out of scope") and Task 5

**What's wrong:** The plan says `~/.claude/CLAUDE.md` changes are "Out of scope" because install.sh handles propagation. This is technically correct -- install.sh replaces the dev-workflow section between markers, so updating `dev-workflow/CLAUDE.md` and running `install.sh` does update `~/.claude/CLAUDE.md`. However, the plan never explicitly states this propagation mechanism. An implementer unfamiliar with the install.sh marker system might worry that `~/.claude/CLAUDE.md` has a separate, manually-maintained model table. A one-sentence note in Task 5 or DD1 clarifying that `install.sh` replaces the full `# === DEV WORKFLOW START ===` to `# === DEV WORKFLOW END ===` block would prevent confusion.

**Suggested fix:** Add a sentence to Task 5 like: "The `~/.claude/CLAUDE.md` model assignments table lives inside the `# === DEV WORKFLOW START/END ===` markers and is replaced wholesale by `install.sh` from `dev-workflow/CLAUDE.md` -- no separate update is needed."

### MINOR -- Task 2 Step 4 replacement removes the "Stale PRs" check's connection to the briefing

**Location in plan:** Task 2, change #2

**What's wrong:** The original Step 4 mentions "Stale PRs -- any open PRs that might have reviews or CI results overnight?" as one of the reconciliation checks. The replacement version includes a PR check (item 4) that runs `gh pr list`, which is good. However, the replacement says to report under a "## Git State" section, while the Step 5 briefing template (lines 58-83) has a "## Since last session" section that expects PR reviews and CI results. There is no instruction connecting the "## Git State" output from Step 4 to the "## Since last session" section in Step 5. Haiku might create both sections with overlapping content, or put PR info only in Git State and leave "Since last session" empty.

**Suggested fix:** In the Step 4 replacement text, either (a) say the checks should be reported in the "## Since last session" section of the briefing (matching the existing template), or (b) explicitly say "## Git State" replaces the "## Since last session" section in the template. Consistency between the reconciliation output and the briefing template matters more for Haiku than it does for Sonnet.

### MINOR -- `end_of_day` Step 2 git-log update asks Haiku to infer "why" from diffs

**Location in plan:** Task 3, change #4 (adding "Keep commit descriptions to one sentence")

**What's wrong:** The plan adds a constraint ("Keep commit descriptions to one sentence. Do not analyze or interpret the changes beyond what the diff summary shows.") but the surrounding text (line 109) still says "The goal is to capture the *logic* of recent changes -- not just file lists but *why* things changed." The new instruction and the existing instruction partially conflict. Haiku is told both to "capture the *why*" and to "not interpret beyond what the diff summary shows." These can coexist if read charitably, but for Haiku, explicit consistency matters.

**Suggested fix:** Either adjust the existing line 109 to match ("The goal is to capture *what* changed at a glance") or soften the addition to say "Keep commit descriptions to one sentence. Base them on the commit message and diff summary -- do not speculate about intent beyond what the message states."

## What the plan gets right

- The scoping is well-judged: `/gate`, `/rollback`, and `/end_of_task` are correctly kept on Sonnet with clear reasoning.
- The task dependency ordering (1-4 parallel, then 5, then 6) is correct and reflects the actual independence of the changes.
- DD1 (install.sh needs no changes) is verified correct -- install.sh copies SKILL.md files generically with no model-specific logic.
- The validation strategy (sequential comparison against existing Sonnet artifacts) is practical and avoids the cost of running both models simultaneously.
- The rollback plan is clean, per-skill and full-stage, with a sensible "2 or more skills fail = revert all" threshold.
- The `/capture_insight` assessment (no content adjustments needed) is correct -- that skill is genuinely template-fill-in.
- The `/start_of_day` Step 4 restructuring into an explicit command checklist is a solid Haiku-proofing approach.

## Summary

The plan is well-structured and the overall approach is sound. The one MAJOR issue is a direct contradiction between the new "Stay factual" instruction and the existing "Capture the narrative" instruction in `/weekly_review` -- Haiku will struggle with contradictory guidance more than Sonnet does. Several MINOR issues involve similar contradictions between new additions and existing text (in `end_of_day` Step 2 and `start_of_day` Step 4-5 section naming). Resolving these contradictions before implementation will produce cleaner, more Haiku-compatible instructions. The line number discrepancy in Task 4 is trivial but worth fixing to avoid implementer confusion.
