# ADR-0015: The statusline saves the usage limits, and new agents are blocked near them

**Date**: 2026-11-16
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

On a Pro or Max login, Claude Code sends the plan's 5-hour and weekly usage
(`rate_limits.five_hour` and `rate_limits.seven_day`: percent used and reset
time) to the statusline only. Neither the model nor a hook sees it. A
subagent spends the same limit as the main session. In one session an
implementer agent hit the limit mid-task: its work stopped half done, and a
note sent to it had not arrived, because a message reaches a running agent
only at its next tool call. The main session had no way to know the limit was
near when it started the agent.

ADR-0006 made `check-agent-brief.py` warn-only. This ADR adds the first case
where it blocks.

## Decision

- Both statusline scripts write `rate_limits.five_hour` and `seven_day` to
  `usage/limits.json` in the config folder on every refresh: a temp file
  moved into place, so a reader never sees half a file. Nothing is written
  when Claude Code sends no `rate_limits` (API key, Bedrock, Vertex).
- `check-agent-brief.py` reads it on every Agent call, for every agent type.
  A window whose reset time has passed is ignored.
  - From `LIMIT_WARN_PERCENT` (75) it adds the windows that are high, with
    their reset times, to the model's context, plus the order to keep the
    agent small and to stop a running one at its next checkpoint.
  - From `LIMIT_BLOCK_PERCENT` (90) it denies the call, with the numbers and
    the advice to work on in the main session or wait for the reset.
- The core rules say the main session briefs agents as orders, with limits,
  stop points and commit points in the first brief.

## Alternatives Considered

### Alternative 1: A rule only, no hook
- **Pros**: no new file, no blocking.
- **Cons**: the model cannot see the limits, so it cannot follow a rule about
  them.
- **Why not**: the rule would read as followed while nothing checks it.

### Alternative 2: Warn only, never block
- **Pros**: keeps ADR-0006's warn-only contract.
- **Cons**: near the limit, a warning still lets an agent start that will be
  cut off, which is the failure this ADR exists for.
- **Why not**: the warning band from 75% already covers the cases where the
  model should decide.

### Alternative 3: Ask the usage API from the hook
- **Pros**: fresh numbers, no file.
- **Cons**: a network call on every Agent call, with the person's token, from
  a hook.
- **Why not**: the statusline already has the numbers for free.

## Consequences

### Positive
- The main session learns the limits when it starts an agent, and no agent
  starts that would be cut off near the limit.
- Saving the numbers costs one small local file write per statusline refresh,
  no request and no tokens.

### Negative
- The numbers are as old as the last statusline refresh.
- Above 90%, agents are blocked even when the task is tiny; the main session
  has to do it itself.

### Risks
- Without a statusline (`--no-statusline`, or a custom one) no file is
  written, and the hook only checks briefs.
- A stale file from before a reset is ignored only by its reset time; a
  wrong clock could block or allow wrongly.
