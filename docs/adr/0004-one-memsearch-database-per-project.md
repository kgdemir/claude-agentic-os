# ADR-0004: One memsearch database per project

**Date**: 2026-09-24
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

Claude keeps facts it learns between sessions in two places: file memory under
`~/.claude/projects/<project>/memory/` and the memsearch plugin's searchable
database. One person works on many unrelated repositories. A search over a
shared store returns the best textual match, whichever repository it came from.

Introduced in commit `4df83d3`.

## Decision

- Each project Claude runs for uses its own memsearch database. One project's
  memory is never searched or written from another.
- File memory follows the same split: one fact per `name.md` under that
  project's `memory/` directory, with a one-line pointer in `MEMORY.md`. The
  index holds pointers, never content, and no file is left unreferenced.
- Memory is context, not truth: anything a note claims about the code is checked
  against the code before acting on it.

## Alternatives Considered

### Alternative 1: One shared database for all projects
- **Pros**: knowledge learned in one repository (a tool quirk, a preference)
  is available everywhere; one index to maintain.
- **Cons**: answers a question about one codebase with a fact from another,
  with nothing in the result showing it came from elsewhere.
- **Why not**: a wrong-repository fact is worse than no fact. Cross-project
  knowledge belongs in the global guides instead.

## Consequences

### Positive
- Recall stays relevant to the code in front of the agent.

### Negative
- A lesson learned in one project is not recalled in another until it is
  promoted into a guide.

### Risks
- A session started outside a project directory could create or read the wrong
  database; the project-location rule in `CLAUDE.md` makes every session pick a
  project first.
