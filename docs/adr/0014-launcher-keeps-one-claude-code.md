# ADR-0014: The launcher keeps one Claude Code, the native one, first on PATH

**Date**: 2026-11-10
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

Claude Code can be installed two ways: the native installer, which puts
`claude` in `~/.local/bin` and updates it by itself, and the npm package
`@anthropic-ai/claude-code`. On the owner's machine both were present. The
launcher loads nvm (step 7) and Homebrew after `~/.local/bin` was added, so
their bin folders landed ahead of it. `claude` then started the npm copy, whose
`bin/claude.exe` was a stub ("native binary for this platform was not
downloaded"). The two copies also fight over updates.

Introduced in commit `53a3209`.

## Decision

- `runclaude` adds `~/.local/bin` to `PATH` once, then in step 9 moves it to
  the front, after nvm and Homebrew have loaded.
- When the native `claude` exists and `type -ap claude` shows another one, the
  launcher asks the first `npm` on `PATH` for its global root. If
  `@anthropic-ai/claude-code` is there, it is uninstalled with
  `npm uninstall -g`. The native copy stays.
- The npm copy is kept while a process runs from it (`running_from()` checks
  `ps` and `/proc/*/exe`), because removing it deletes files a session still
  loads.
- When the npm root is not writable, only the `sudo npm uninstall -g` command
  is printed; the launcher never runs `sudo` for this.
- `npm` is not started on a normal launch, only when a second `claude` is on
  `PATH`.

## Alternatives Considered

### Alternative 1: Only fix the PATH order
- **Pros**: nothing is removed.
- **Cons**: the npm copy stays, keeps updating and comes back to the front in
  any shell that loads nvm after the launcher's order.
- **Why not**: it treats the symptom; two installs remain.

### Alternative 2: Warn and print the uninstall command
- **Pros**: the owner decides each time.
- **Cons**: the same warning on every launch, and a broken `claude` until
  someone acts.
- **Why not**: the launcher already installs tools without a prompt (it is
  opt-in for that reason); removing a known duplicate fits the same contract.

### Alternative 3: Remove the native copy and keep npm
- **Pros**: one copy, managed with the other Node tools.
- **Cons**: npm installs depend on the active Node version and need a manual
  update; the native one updates itself.
- **Why not**: Claude Code recommends the native installer.

## Consequences

### Positive
- `claude` always starts the native, self-updating copy.
- A stale npm copy is cleaned up once, without a manual step.

### Negative
- The launcher now removes software, not only installs it.
- `ps` and a walk over `/proc` run when a second `claude` is found.

### Risks
- Someone who wants the npm copy on purpose loses it on the next launch; they
  have to skip the launcher or remove the native copy.
- A session started from the npm copy by a path `ps` does not show could be
  missed, and its files removed under it.
