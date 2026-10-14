# ADR-0008: Preventive rules carry a Why line until they earn a cost

**Date**: 2026-10-14
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

`CONTRIBUTING.md` admitted only "earned" rules: something went wrong, and the
rule records what it cost. That keeps the pack free of fussiness, but it also
keeps out well-known failures that simply have not happened here yet: leaked
secrets, force pushes, edited migrations, swallowed errors, N+1 queries,
un-type-checked builds. Waiting for each one to cost something first is the
expensive way to learn it.

Introduced in commits `97e60e9` (eight core rules, §9 Safety) and `4014093`
(stack rules for .NET, EF Core, TypeScript, React, ESLint), corrected in
`f00eafb`.

## Decision

- A rule may be added before any incident when it is project-agnostic within
  its scope and names the failure it stops in a `*Why:*` line, where earned
  rules have `*Cost:*`.
- When the failure does happen, the `*Why:*` line is replaced with its
  `*Cost:*`.
- Preventive rules follow the same layout as the rest (ADR-0007): core when they
  apply to every project, otherwise the matching stack, tool or feature guide.
- A preventive rule states only what can be checked against the tool's own
  documentation; an unverifiable claim is left out.

## Alternatives Considered

### Alternative 1: Earned rules only
- **Pros**: every rule has a recorded incident; nothing reads as fussiness.
- **Cons**: each well-known failure has to happen once before the pack guards
  against it.
- **Why not**: the owner asked for these rules up front; the `*Why*` marker
  keeps them distinguishable.

### Alternative 2: Preventive rules in a separate guide
- **Pros**: earned and preventive rules never mix.
- **Cons**: a topic is split across two files, and the preventive file is
  always loaded or never found.
- **Why not**: the marker on each rule gives the same separation without
  splitting topics.

## Consequences

### Positive
- Common failures are covered before they cost anything.
- A reader can still tell which rules have an incident behind them.

### Negative
- The always-loaded core guide is longer, so every session costs more tokens.
- Preventive rules are easier to question and to delete.

### Risks
- A preventive rule can be wrong without an incident to test it against; two
  claims were already corrected in `f00eafb`. Rules citing versions or APIs need
  re-checking after major releases.
