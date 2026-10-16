# ADR-0003: Install every plugin from five marketplaces, with auto-update on

**Date**: 2026-09-24
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

The rules assume tools that come from plugins: caveman (reply style),
context-mode (sandboxed search/execute), drywall (duplicate detection), ecc
(agents, skills, hooks) and memsearch (per-project memory). Setting them up by
hand on each machine drifts: different plugins, different versions.

Introduced in commit `4df83d3`.

## Decision

- With `--with-plugins` (the interactive default), add five marketplaces:
  `JuliusBrussee/caveman`, `mksglu/context-mode`, `nikhaldi/drywall`,
  `https://github.com/affaan-m/ECC.git`, `zilliztech/memsearch`.
- Read each marketplace's catalog and install every plugin it publishes, rather
  than a hard-coded list, so a plugin added upstream arrives without a change
  here.
- Enable them and set `autoUpdate` for each marketplace in `settings.json`.
- Write `CAVEMAN_DEFAULT_MODE=ultra`, and offer `ECC_DISABLED_HOOKS` to turn off
  the ECC gateguard hooks.

## Alternatives Considered

### Alternative 1: Pin a fixed list of plugins and versions
- **Pros**: reproducible; nothing changes without a commit here.
- **Cons**: every upstream fix needs a pack release; the list goes stale.
- **Why not**: the maintainer would rather track upstream than curate versions.

### Alternative 2: Leave plugins to each person
- **Pros**: no third-party code installed by the pack.
- **Cons**: rules that reference plugin tools fail on machines without them.
- **Why not**: the rules and the tools are meant to arrive together.

## Consequences

### Positive
- One command gives the same tool set everywhere, kept current.

### Negative
- Plugins nobody asked for get installed if a marketplace publishes them.
- Behaviour can change between sessions without any change in this repo.

### Risks
- Supply chain: a compromised or careless upstream release runs on every
  machine with auto-update on. `SECURITY.md` states this; the mitigation is that
  the step is asked about and can be skipped with `--no-plugins`.

## Amendment 2026-10-16

A `PLUGIN_SOURCES` line may now name plugins, and then only those are
installed. The five marketplaces above still install whole; the official
marketplace is added with 16 named plugins (ADR-0011).
