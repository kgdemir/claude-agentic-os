# ADR-0002: The installer merges, backs up and asks before changing anything outside ~/.claude

**Date**: 2026-09-24
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

`install.sh` runs on machines that already have a Claude Code setup: an existing
`settings.json`, hooks, a statusline, shell rc files and a global git identity.
It is also run unattended (CI, `-y`, piped from `curl`). An installer that
overwrites a working setup, or edits a shell rc without asking, costs more than
it saves.

Introduced in commit `4df83d3`.

## Decision

- `settings.json` is merged, never overwritten. A default is only written when
  the key is missing, so the person's own values win.
- Every file the installer replaces is backed up first as
  `<file>.backup-<timestamp>`; a malformed `settings.json` is left alone with a
  "set this by hand" message instead of being rewritten.
- Nothing outside `~/.claude` changes without an explicit yes: Claude Code and
  GitHub sign-in, the global git identity, and the shell rc block (written
  between `# >>> claude rules pack` markers). With `-y` or no terminal, each of
  those answers **no** and prints the exact command instead.
- Re-running is safe: nothing is installed or registered twice.

## Alternatives Considered

### Alternative 1: Write a complete `settings.json` from the pack
- **Pros**: simple and fully predictable.
- **Cons**: destroys the person's permissions, hooks, model and plugin choices.
- **Why not**: most machines already have a tuned settings file.

### Alternative 2: `-y` means yes to everything
- **Pros**: one flag gives a fully unattended setup.
- **Cons**: an unattended run would edit shell rc files, git identity and
  sign-in state with no one watching.
- **Why not**: changes outside `~/.claude` must be a conscious choice.

## Consequences

### Positive
- Safe to run on an existing machine and to re-run after every update.
- Every change can be undone by moving a backup back.

### Negative
- Backups accumulate in `~/.claude` across runs.
- An unattended run leaves the outside-`~/.claude` steps for the person to do by
  hand.

### Risks
- Merge logic must handle every shape a hand-edited `settings.json` can take;
  an unhandled shape would abort the install under `set -e`.

## Amendment 2026-10-15

The installer now has one deleting path, `--prune-backups <N>`, which removes
old `.backup-*` copies only after "yes" is typed in a terminal (ADR-0010). It
also backs up a file only when its content would change.
