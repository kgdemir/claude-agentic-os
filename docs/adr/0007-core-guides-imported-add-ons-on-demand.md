# ADR-0007: Core guides imported, add-on guides read on demand

**Date**: 2026-10-14
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

ADR-0001 imported every guide into every session. That had two costs:

- Rules for one stack, tool or feature (.NET, React, Vite, ffmpeg, child
  processes, EF Core, realtime media, PDF export) loaded into every session of
  every project, whether the project used them or not.
- Topics hid inside unrelated files: ffmpeg traps sat in `dotnet-gotchas.md`,
  chunk grouping in `react.md`, PDF rebuild steps in `docs-updates.md`, realtime
  and AI sections in `project-docs.md`. A person without that stack never found
  them, and a person with it could not drop them.
- Rules that only make sense with one plugin (caveman, context-mode, memsearch)
  or for one person's habits (every project under one root) were written as if
  every user had them.

Introduced in the commit that adds this ADR. Partly supersedes ADR-0001
(see its amendment).

## Decision

- `.claude/guides/` is split by when a rule applies:
  - `core/` — every project: agent working rules, `tools/` scripts, project
    `CLAUDE.md`, project docs, doc updates, `docs/` layout. `@`-imported from
    `~/.claude/CLAUDE.md`.
  - `stacks/` — one language or framework per file (`dotnet`,
    `dotnet-gotchas`, `dotnet-ef-core`, `react`).
  - `tools/` — one tool per file (`vite`, `child-processes`, `ffmpeg`,
    `pdf-export`).
  - `features/` — one product feature per file (`realtime-media`,
    `ai-models`).
  - `plugins/` — rules for one plugin (`caveman`, `context-mode`,
    `memsearch`).
  - `addons/` — personal preferences the installer asks about
    (`project-location`).
- Everything outside `core/` is listed in `~/.claude/CLAUDE.md` in a table of
  trigger and file. Claude reads the file with the Read tool when the trigger
  matches, not before.
- `addons/project-location.md` is imported only when the person chooses it
  (`--with-project-location`, default on under `-y` so existing behaviour
  holds). `install.sh` fills `{{PROJECT_LOCATION_IMPORT}}` with the import
  line or with nothing.
- `install.sh` moves the old flat `guides/<name>.md` files aside as
  `.backup-<stamp>`, so no stale copy keeps loading.
- Rules moved verbatim, apart from links to the new paths, with two
  exceptions: `core/project-docs.md` lost its realtime, AI and stack-specific
  bullets (now pointers to `features/` and the stack guides), and the gate
  bullets in `project-claude-template.md` became one per-stack placeholder.
- Links between guides use the full `~/.claude/guides/...` path, so
  `guides/tools/` is never mistaken for a project's own `tools/` folder.

## Alternatives Considered

### Alternative 1: Keep importing every guide
- **Pros**: no trigger can be missed; nothing depends on Claude deciding to read
  a file.
- **Cons**: every session pays for every stack's rules; a new stack or tool
  guide makes every session longer.
- **Why not**: the pack is meant for any person and any project; the always-on
  part has to stay small.

### Alternative 2: Leave add-ons out of the template; let each project `CLAUDE.md` import them
- **Pros**: loading is exact per project.
- **Cons**: every project has to know the add-on exists and add the import by
  hand; a new project starts without them.
- **Why not**: the trigger table finds them without per-project setup. A project
  can still `@`-import an add-on it always needs.

### Alternative 3: One installer question per add-on
- **Pros**: each person picks exactly the stacks they use.
- **Cons**: a long questionnaire; a person who starts a React project later has
  to re-run the installer.
- **Why not**: on-demand reading already costs nothing until used. Only a
  rule that changes behaviour in every session (project location) is asked.

## Consequences

### Positive
- Sessions load only core rules; stack, tool and feature rules arrive when the
  project needs them.
- A new stack, tool, feature or plugin gets a new file and one table row; no
  core guide grows.

### Negative
- An add-on applies only if Claude notices its trigger and reads the file.
- Paths changed; anything outside the pack that pointed at
  `~/.claude/guides/<name>.md` must be updated.

### Risks
- A trigger written too narrowly leaves its rules unread. Triggers name files or
  signals Claude can see (`*.csproj`, `ffmpeg` calls, `CAVEMAN MODE`).
