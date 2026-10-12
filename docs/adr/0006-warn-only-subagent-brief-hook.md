# ADR-0006: A warn-only hook for subagent briefs

**Date**: 2026-10-12
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

A subagent that has to come back with a question sits idle while it waits, and
once idle past its cache TTL (ADR-0005), its next request re-pays its whole
history. The rule in `agent-working-rules.md` §3 asks every brief for a `Goal:`,
`Files:` and `Done:` line. A rule alone depends on the model remembering it.

Introduced in commit `951dfca`.

## Decision

- `.claude/hooks/check-agent-brief.py` runs as a `PreToolUse` hook on the
  `Agent` tool. When a brief lacks one of the three lines, it lets the call
  through and returns `hookSpecificOutput.additionalContext` with a reminder.
  Verified live: the model receives the reminder and the agent still runs.
- `Explore`, `claude-code-guide`, `statusline-setup` and forks are exempt.
  Unexpected input is let through silently.
- The matcher is the plain list `Agent|Task`. Claude Code splits a plain list on
  `|` and matches each name exactly, including tool aliases.
- `install.sh` copies the script to `~/.claude/hooks/` and registers it once,
  recording the registered command in `check-agent-brief.registered` so a re-run
  replaces only its own earlier entry.

## Alternatives Considered

### Alternative 1: Block the call (exit 2) until the brief is fixed
- **Pros**: the rule cannot be skipped.
- **Cons**: briefs written by skills and plugins (`/code-review`, superpowers,
  ecc and others) do not follow this format and would be blocked, costing a
  retry each time or derailing the workflow.
- **Why not**: the hook must never break tooling the user did not write.

### Alternative 2: Rewrite the brief with `updatedInput`
- **Pros**: the running agent would get the missing instruction ("pick the
  safest reading, do not ask back") without a retry.
- **Cons**: Claude Code 2.1.296 denies the call when a hook from the user's own
  files changes a tool's input in some sessions ("may block or ask about a call
  but not change it").
- **Why not**: it would turn the reminder back into a blocker.

### Alternative 3: An anchored regex matcher `^(Agent|Task)$`
- **Pros**: looks stricter.
- **Cons**: a regex skips Claude Code's exact-name list path and its alias
  expansion; the plain list was already exact.
- **Why not**: no gain and a possible loss.

## Consequences

### Positive
- The model is reminded at the moment it writes a weak brief, and no workflow
  breaks.

### Negative
- The agent already started with the weak brief; the reminder helps the next
  one.
- Each `Agent` call starts a `python3` process.

### Risks
- Hook output fields and matcher semantics are version-specific; re-verify after
  a major Claude Code update.
