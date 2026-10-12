# ADR-0005: One-hour subagent cache and a 250k-token compaction window

**Date**: 2026-10-12
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

Two costs grow quietly in long sessions:

- Every request re-sends the whole conversation. Without a lower compaction
  point, a session keeps paying for a context far larger than the work needs.
- Prompt caches for subagents, workflows and background requests expire after 5
  idle minutes by default. A subagent that waits longer, or is woken after a
  pause, pays for its whole history again at full input price — more than a new
  agent with a short brief costs.

Claude Code 2.1.296 exposes both: the `CLAUDE_CODE_AUTO_COMPACT_WINDOW`
environment variable (setting `autoCompactWindow`), and the
`subagentPromptCacheTtl` setting (`"5m"` or `"1h"`; env
`CLAUDE_CODE_SUBAGENT_PROMPT_CACHE_TTL` wins). `1h` is ignored while a Claude
subscription is in overage.

Introduced in commit `951dfca`.

## Decision

- `install.sh` writes `subagentPromptCacheTtl: "1h"` and
  `env.CLAUDE_CODE_AUTO_COMPACT_WINDOW: "250000"` when missing. Both values live
  once, as `SUBAGENT_CACHE_TTL` and `AUTO_COMPACT_WINDOW` in `install.sh`;
  `tools/check-values.sh` fails when `README.md` or the guide quote other values.
- `agent-working-rules.md` §3 ties agent behaviour to the TTL: assume 5 minutes
  unless sure of 1 hour; one command never waits past the TTL (4 minutes on 5m,
  55 on 1h); never message a subagent idle past its TTL — start a fresh one.

## Alternatives Considered

### Alternative 1: Leave the cache at 5 minutes and rely on the rules alone
- **Pros**: cache writes stay at about 1.25x base input instead of about 2x.
- **Cons**: any subagent idle between 5 and 60 minutes re-pays its whole
  history; that happens routinely with long builds and reviews.
- **Why not**: one avoided full re-read pays for many 1h cache writes.

### Alternative 2: Set `ENABLE_PROMPT_CACHING_1H=1` for everything
- **Pros**: the main conversation also keeps a warm cache across long breaks.
- **Cons**: doubles the cache-write cost of every main-loop request too, where
  idle gaps over 5 minutes are rarer.
- **Why not**: subagents are where the idle gaps are.

### Alternative 3: The `autoCompactWindow` setting instead of the env var
- **Pros**: same effect, one fewer `env` entry.
- **Cons**: none of substance.
- **Why not**: the env var was the owner's explicit choice; both are read by the
  same code path.

## Consequences

### Positive
- Long sessions stay bounded in cost; idle subagents keep their cache for an
  hour.

### Negative
- Each subagent cache write costs about 2x base input instead of 1.25x.
- Compaction at 250k drops detail earlier than the model's full window would.

### Risks
- In overage the TTL silently falls back to 5 minutes; the rules therefore
  default to the 5-minute limits when unsure.
- Setting names are version-specific; a Claude Code release could rename them.
