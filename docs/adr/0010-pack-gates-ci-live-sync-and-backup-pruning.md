# ADR-0010: Pack gates in one script, CI, a live-sync script and opt-in backup pruning

**Date**: 2026-10-15
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

Gates were run by hand from a list in `CLAUDE.md`, and structural mistakes in
the guides (a rule without its `*Cost:*`/`*Why:*` line, a guide with no trigger
row, a path that does not resolve, YAML that does not parse, a project name
leaking in) were caught only by review. Nothing ran on push. Bringing the live
`~/.claude` up to date meant rendering into a scratch folder and copying files
by hand. Every installer run left `.backup-*` copies, including of files that
had not changed, and nothing ever removed them; the live folder held 14 backup
stamps.

Introduced in the commit that adds this ADR.

## Decision

- `tools/check.sh` runs every gate: shell syntax, hook syntax, `check-values.sh`,
  `test-hooks.sh`, `check-guides.sh`, and a trial install that must leave no
  `{{PLACEHOLDER}}`. CI runs the same script.
- `tools/check-guides.sh` checks the guide structure listed above. Older rules
  without a reason line are listed in `tools/check-guides.baseline`; a new rule
  can never be added there. The leak check reads names from the gitignored
  `tools/leak-names.local` and is skipped without it, so the names themselves
  never reach the repository.
- `.github/workflows/ci.yml` runs `tools/check.sh` on push to `main` and on pull
  requests, with a SHA-pinned checkout, `contents: read`, a concurrency block and
  a job timeout.
- `tools/sync-live.sh` renders the pack with the person's answers from the
  gitignored `tools/sync-live.local`, then copies only changed `CLAUDE.md`,
  guide, template and hook files into the live folder, backing up each one. It
  never edits `settings.json`; it reports unregistered hooks and files the pack
  no longer ships.
- `install.sh` backs up a file only when the rendered content differs from the
  installed one, and drops a `settings.json` backup that equals the result.
- `install.sh --prune-backups <N>` keeps the newest N backup stamps and deletes
  the rest, only in the pack's own folders, only after "yes" is typed in a
  terminal, never under `-y`. This amends ADR-0002, under which the installer
  never deleted anything.

## Alternatives Considered

### Alternative 1: Keep gates as a list in `CLAUDE.md`, no CI
- **Pros**: nothing new to maintain.
- **Cons**: a skipped gate is only noticed by the next reader; pushes are
  unchecked.
- **Why not**: §1 "never claim a gate is green without having run it" is easier
  to keep with one command.

### Alternative 2: Run the full installer on the live folder to sync
- **Pros**: one code path; hooks get registered.
- **Cons**: it also touches plugins, statusline, launcher and settings, and asks
  questions; more than a guide edit needs.
- **Why not**: the owner prefers direct file updates for day-to-day syncs;
  `install.sh` stays the way to register new hooks.

### Alternative 3: Prune backups automatically on every install
- **Pros**: no clutter without any action.
- **Cons**: deletes files the person may still want, without asking.
- **Why not**: deletion stays opt-in and confirmed (core §9).

## Consequences

### Positive
- One command answers "do all gates pass", locally and in CI.
- Guide-structure mistakes fail a gate instead of waiting for review.
- Re-running the installer no longer piles up identical backups.

### Negative
- The baseline file has to be kept in step when an older rule gains a reason.
- The YAML check needs PyYAML; it prints SKIP without it.

### Risks
- The leak check only knows the names in the local list; CI never runs it.
- Pruning deletes files; a wrong stamp pattern would delete the wrong ones. It
  matches only `.backup-YYYYMMDD-HHMMSS` names and lists them before asking.
