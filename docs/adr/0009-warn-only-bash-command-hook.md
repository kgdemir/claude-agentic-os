# ADR-0009: A warn-only hook for shell commands that break core rules

**Date**: 2026-10-15
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

Several core rules are visible in the command line itself: `git add -A`, a plain
`git push --force`, `git reset --hard`, `git clean -f`, a `Co-Authored-By:`
trailer in a commit message, a gate piped into `tail` without `pipefail`, and a
secret in the staged diff. Written rules alone did not stop these: the gate pipe
broke CI twice in one session, and a virtual-environment directory was committed
by a blanket `git add`. ADR-0006 already added a warn-only hook for subagent
briefs, which showed that a reminder at the moment of the call works without
blocking anyone.

Introduced in the commit that adds this ADR, together with the `install_hook`
refactor in `install.sh` and `tools/test-hooks.sh`.

## Decision

- `.claude/hooks/check-bash-command.py` runs as a `PreToolUse` hook on `Bash`.
  It checks git safety (§6, §9), AI attribution in commit/tag/PR/issue/release
  text, gate pipes without `pipefail` (§1), and, on `git commit`, staged added
  lines that look like keys, tokens or passwords (§9).
- It only warns: the reminder is returned as `additionalContext` and the command
  runs. Any unexpected input or internal error lets the command through, with
  a note on stderr.
- A secret warning names the file and the kind of secret, never the value.
- `install.sh` installs and registers it through the same `install_hook`
  function as the brief hook, idempotently, with its own state file.
- `tools/test-hooks.sh` feeds sample events to both hooks; every case that must
  warn has a twin that must not.

## Alternatives Considered

### Alternative 1: Block the command (exit code 2 or `permissionDecision: deny`)
- **Pros**: the rule cannot be broken by accident.
- **Cons**: a pattern match on a command line has false positives (a quoted
  `git add .` inside a heredoc, a deliberate `reset --hard` the person asked
  for); a block then stops legitimate work.
- **Why not**: the person approves destructive steps anyway (§9); a reminder
  keeps that decision with them.

### Alternative 2: Git hooks (`pre-commit`, `pre-push`) in each project
- **Pros**: also catch commands typed by people, not only by Claude.
- **Cons**: need installing per repository; cannot see `git add -A`,
  `reset --hard` or pipes at all.
- **Why not**: the pack is installed once per person, not per project.

## Consequences

### Positive
- The common rule breaks are flagged the moment they happen, with the rule
  number to look up.
- The secret scan runs before every commit Claude makes.

### Negative
- Every Bash call starts a Python process (a few tens of milliseconds); a
  `git commit` also runs `git diff --cached`, bounded by a 5-second timeout.
- The patterns are heuristics: unusual spellings slip through.

### Risks
- A false positive repeated often teaches the model to ignore the hook. Each
  new pattern needs a no-warn twin in `tools/test-hooks.sh`.
