# ADR-0001: One template CLAUDE.md that imports per-topic guides

**Date**: 2026-09-24
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

The same agent rules (verification, diagnosis, git hygiene, docs policy, stack
gotchas) were being repeated by hand in every project and on every machine. The
rules name a person (owner, ADR decider, contact email), a reply language and a
projects directory, so a copy made for one person is wrong for the next. Claude
Code loads `~/.claude/CLAUDE.md` in every session and follows `@path` imports
from it.

Introduced in commit `4df83d3`.

## Decision

- Ship one global `.claude/CLAUDE.md` that holds only the always-on rules and
  imports each topic with `@~/.claude/guides/<topic>.md`. One topic per guide
  file; templates for ADRs and project `CLAUDE.md` files sit in
  `.claude/templates/`.
- Every person-, machine- or path-specific value is a placeholder
  (`{{REPLY_LANGUAGE}}`, `{{OWNER_NAME}}`, `{{OWNER_GITHUB}}`,
  `{{OWNER_EMAIL}}`, `{{PROJECT_ROOT}}`). `install.sh` fills them with `sed` in
  `install_file()` while copying into `~/.claude`, taking defaults from
  `gh api user` with a noreply-email fallback.
- The installer aborts if any `{{` survives substitution.

## Alternatives Considered

### Alternative 1: Publish the rules as a Claude Code plugin
- **Pros**: installs and updates through the same plugin mechanism as the rest
  of the set; no copy step.
- **Cons**: a plugin cannot write the global `CLAUDE.md` or fill in per-person
  values; the rules would still need a separate per-person step.
- **Why not**: the per-person substitution is the core requirement.

### Alternative 2: Symlink `~/.claude` files to a dotfiles checkout
- **Pros**: edits flow both ways; `git pull` updates the live rules.
- **Cons**: placeholders cannot stay unfilled in a live file, so the checkout
  would have to hold one person's values; breaks sharing the pack.
- **Why not**: the pack is meant for more than one person.

### Alternative 3: One large `CLAUDE.md` with every rule inline
- **Pros**: one file, nothing to import.
- **Cons**: every session loads every stack's rules; hard to edit one topic
  without touching the rest.
- **Why not**: per-topic guides keep each change small and reviewable.

## Consequences

### Positive
- A new machine gets the full rule set in one command, with the right names.
- Each topic can be edited, reviewed and cut on its own.

### Negative
- Installed files are copies: a local edit in `~/.claude` is overwritten (after a
  backup) on the next install.
- A new placeholder needs a matching `sed` expression, or the install aborts.

### Risks
- `sed` with `|` as delimiter breaks if a substituted value ever contains `|`.
