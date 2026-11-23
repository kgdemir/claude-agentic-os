# ADR-0017: The LSP guide is a core guide, loaded in every session

**Date**: 2026-11-24
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

ADR-0016 added a one-line core rule ("Code symbols: use the `LSP` tool, not grep") and a
warn-only hook, and kept the detailed guide, `guides/tools/lsp.md`, as an add-on (ADR-0007)
behind its trigger row "Finding where code is defined, used or called".

That guide holds what the one-line rule leaves out: find the position before calling an
operation, the operation for each question (`prepareCallHierarchy` before `incomingCalls`),
what to do when no server answers, and when grep is still right. The one-line rule points to
the guide, so using `LSP` well still depends on the model noticing the trigger and reading the
file. The trigger was missed in the session behind ADR-0016, so a second missed trigger is the
expected failure, not a rare one.

Code lookups happen in almost every coding session in almost every project, so the trigger is
not narrow the way a stack or tool trigger is (`*.csproj`, a `Dockerfile`). On 2026-11-24 the
owner decided the guide must be a ground rule, not read on demand.

## Decision

1. Move `.claude/guides/tools/lsp.md` to `.claude/guides/core/lsp.md` and `@`-import it from
   the core list in `.claude/CLAUDE.md`. Remove its trigger row from the add-on table.
2. Point every reference at the new path: the core rule in `agent-working-rules.md`, `GUIDE` in
   `check-lsp-servers.py` and `check-symbol-search.py`, the comment in `install.sh`, and the
   tree in `README.md`.
3. `install.sh` renames a `guides/tools/lsp.md` left from an earlier install to
   `lsp.md.backup-<timestamp>`, the same way it treats guides from the old flat layout, so no
   stale second copy remains.
4. The core rule and both hooks from ADR-0013 and ADR-0016 stay as they are.

## Alternatives Considered

### Alternative 1: Keep the add-on, widen its trigger row
- **Pros**: no extra context in sessions that never look up code.
- **Cons**: the trigger is still something the model has to notice; a wider wording does not
  change that.
- **Why not**: the missed trigger is the failure being fixed.

### Alternative 2: Copy the key points into the one-line core rule
- **Pros**: smaller than importing the whole guide.
- **Cons**: two places say the same thing and drift apart; the fallbacks and server checks
  still live only in the add-on.
- **Why not**: one topic per file (ADR-0007); the guide is short enough to load whole.

### Alternative 3: Have the symbol-search hook paste the guide into context
- **Pros**: loads only when a symbol search happens.
- **Cons**: it fires only after grep was already chosen, and only for single-identifier
  patterns; the guide also covers how to use `LSP` once chosen.
- **Why not**: too late and too narrow to replace reading the guide.

## Consequences

### Positive
- The `LSP` how-to is in context from the start of every session; nothing depends on noticing
  a trigger.
- The hooks' messages and the core rule name a file that is already loaded.

### Negative
- About 5 KB more context in every session, including sessions with no code at all.
- The core list grows; ADR-0007's line between core and add-on moves for this one guide.

### Risks
- A later edit that grows `core/lsp.md` grows every session; it should stay short and keep its
  detail about one stack in that stack's guide.
- An install that is not re-run keeps the old `tools/lsp.md` and an add-on row in a
  hand-edited `~/.claude/CLAUDE.md`; the next install moves the file aside.
