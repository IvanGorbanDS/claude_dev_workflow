# Rollback Playbook — Stage 2 (workflow-isolation-and-hooks)

**When to use this:** Something went wrong after merging the S-2 branch
(`feat/workflow-isolation-and-hooks-stage-2`) and you need to fully undo
the deployment. This covers both the live deployed files (`~/.claude/`) and
the repo changes.

---

## Before you start

1. **Identify the severity.** Not all problems require a full rollback.
   - Hook fires unexpectedly or produces wrong output → fix the hook script, re-run `bash install.sh`.
   - A SKILL.md §0c block causes an issue in one skill → edit that SKILL.md, re-run `bash install.sh`.
   - install.sh is corrupted or produces invalid settings.json → restore from `.bak` (Step 1 below).
   - Hooks cause systematic session breakage → full rollback (all steps below).

2. **Note the last-known-good commit** before S-2 was merged:
   ```
   git log --oneline main | grep -v "feat/workflow-isolation"
   ```
   The merge-base is `26ec72c` (the last commit on `main` before the S-2 PR merge).

---

## Step 1 — Restore settings.json from backup

`install.sh` creates a timestamped backup before every run:

```sh
ls -lt ~/.claude/settings.json.bak-* | head -5
```

Restore the most recent pre-S2 backup (choose the one dated before the S-2 install):

```sh
cp ~/.claude/settings.json.bak-<TIMESTAMP> ~/.claude/settings.json
# Verify it parses cleanly:
jq empty ~/.claude/settings.json && echo "OK"
```

If no backup is available, manually remove the four quoin hook stanzas:

```sh
jq 'del(.hooks.UserPromptSubmit[] | select(.hooks[]?.command | endswith("userpromptsubmit.sh")))
  | del(.hooks.PreCompact[] | select(.hooks[]?.command | endswith("precompact.sh")))
  | del(.hooks.SessionStart[] | select(.hooks[]?.command | endswith("sessionstart.sh")))' \
  ~/.claude/settings.json > /tmp/settings-clean.json \
  && jq empty /tmp/settings-clean.json \
  && cp /tmp/settings-clean.json ~/.claude/settings.json
echo "Hook stanzas removed"
```

---

## Step 2 — Remove deployed hook scripts

```sh
rm -f ~/.claude/hooks/userpromptsubmit.sh
rm -f ~/.claude/hooks/precompact.sh
rm -f ~/.claude/hooks/sessionstart.sh
rm -f ~/.claude/hooks/_lib.sh
# Optionally remove the directory if now empty:
rmdir ~/.claude/hooks 2>/dev/null || true
echo "Hook scripts removed"
```

---

## Step 3 — Remove pidfile_helpers.sh (if deployed)

```sh
rm -f ~/.claude/scripts/pidfile_helpers.sh
echo "pidfile_helpers.sh removed"
```

If other quoin scripts were deployed to `~/.claude/scripts/`, you can verify by comparing
against what install.sh should have deployed. Only remove `pidfile_helpers.sh` — the other
scripts (`path_resolve.py`, `cost_from_jsonl.py`, `validate_artifact.py`,
`session_age_guard.py`) are pre-S2 and should be left in place.

---

## Step 4 — Revert §0c pidfile blocks from SKILL.md files

S-2 added `## §0c Pidfile lifecycle` blocks to 9 SKILL.md files. If you want to
revert the deployed `~/.claude/skills/` copies to pre-S2 state, re-run install.sh
from the pre-S2 commit (Step 6 below) **after** reverting the repo source files.

Alternatively, manually remove the §0c blocks from each deployed skill. The affected
files in `~/.claude/skills/` are:

```
~/.claude/skills/architect/SKILL.md
~/.claude/skills/end_of_day/SKILL.md
~/.claude/skills/end_of_task/SKILL.md
~/.claude/skills/implement/SKILL.md
~/.claude/skills/review/SKILL.md
~/.claude/skills/run/SKILL.md
~/.claude/skills/sleep/SKILL.md
~/.claude/skills/thorough_plan/SKILL.md
~/.claude/skills/checkpoint/SKILL.md  ← entire skill; delete this
```

For each file (except checkpoint), the §0c block looks like:

```markdown
## §0c Pidfile lifecycle
...
```

Remove the entire block up to the next `## ` heading.

For `checkpoint/SKILL.md`: this skill did not exist before S-2. Delete the entire
deployed file:

```sh
rm -f ~/.claude/skills/checkpoint/SKILL.md
rmdir ~/.claude/skills/checkpoint 2>/dev/null || true
```

---

## Step 5 — Revert quoin/CLAUDE.md sections (repo source)

S-2 added three sections to `quoin/CLAUDE.md`:

1. `checkpoint` in the Phase values enumeration (one word appended to a list).
2. `### Hooks deployed by quoin` section.
3. `### Lifecycle skills (checkpoint / end_of_day / sleep)` section.

These are documentation changes and do not affect runtime behaviour. You can leave
them in place unless you need a byte-for-byte match with the pre-S2 state.

To revert the CLAUDE.md changes in the repo source:

```sh
git checkout 26ec72c -- quoin/CLAUDE.md
```

---

## Step 6 — Full repo revert to pre-S2 (nuclear option)

If all else fails, revert the entire repo to the merge-base commit:

```sh
git checkout 26ec72c
bash quoin/install.sh
```

This reinstalls all pre-S2 skills, scripts, and CLAUDE.md without any S-2 changes.
After re-running install.sh from the pre-S2 checkout, your `~/.claude/` will be
in the pre-S2 state.

**Caution:** this puts you in a detached HEAD state. To return to a branch:

```sh
git checkout main
# or
git checkout feat/workflow-isolation-and-hooks-stage-2
```

---

## Step 7 — Clean up HOOK_MERGE_TODO.md (if created)

If jq was absent at install time, install.sh may have written:

```sh
rm -f ~/.claude/HOOK_MERGE_TODO.md
```

---

## Step 8 — Verify the rollback

```sh
# No hook stanzas in settings.json:
jq '.hooks' ~/.claude/settings.json
# Should be null or only contain user-defined (non-quoin) hooks.

# No hook scripts:
ls ~/.claude/hooks/ 2>/dev/null || echo "hooks dir absent (expected)"

# Run the soak harness — should report hook files missing:
# (only run this if S-2 branch is still checked out)
# bash quoin/dev/verify_hooks_soak.sh
```

---

## Partial rollback: hooks only, keep docs

If you want to disable runtime hooks but keep the CLAUDE.md documentation:

1. Do Steps 1, 2, 3 (remove deployed hooks and settings.json stanzas).
2. Skip Steps 4, 5, 6 (leave SKILL.md and CLAUDE.md changes in place).
3. Do NOT re-run `bash install.sh` (which would re-deploy the hooks).

This leaves the session-isolation skills (`/checkpoint`, pidfile §0c) active but
the hook event triggers inactive (UserPromptSubmit, PreCompact, SessionStart will
not fire quoin scripts).

---

## Contact

If something is not covered by this playbook, check:

- `quoin/dev/spikes/idempotency_spike.sh` — test the jq merge logic in isolation
- `quoin/dev/verify_hooks_soak.sh` — live hook health checks
- `.workflow_artifacts/workflow-isolation-and-hooks/architecture.md` — S-2 decisions
- `.workflow_artifacts/memory/lessons-learned.md` — post-incident lessons
