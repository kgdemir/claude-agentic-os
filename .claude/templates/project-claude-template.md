# <project-name> — <one-line product type>

<One sentence: what the app does, main features.>

## Stack & Architecture
- **Backend:** <runtime + version, architecture style> — <project/folder> (<responsibility>)
  → <next layer> (<responsibility>) → ... Solution: `<solution file>`.
- **Frontend:** <framework + build tool + language> in `<folder>`. State via <approach, key file>.
- **<Other component, e.g. media/worker/realtime>:** `<folder>` — <responsibility, transport>.
- <Anything out of scope unless explicitly requested.>

## Commands
Run through `tools/` scripts (see global rules); raw commands listed for reference.
- `tools/<script>.sh` — <what it does>
- ...

<Per-part raw commands: dev, build, lint, test, run.>
<Platform limits, e.g. projects that do not build on some OS and the workaround.>
<One-time per-clone setup, e.g. git hooks install, and why it is needed.>

## Quality gates (must pass before commit)
- **C#:** `TreatWarningsAsErrors=true`, `Nullable=enable` — zero warnings.
- **C# tests gate builds/publish:** <how the gate is enforced (script or MSBuild target), emergency skip if any, ADR ref>.
- **TS/React:** all ESLint rules are errors; `--max-warnings=0`. No `eslint-disable` —
  fix root cause (only proven false positives, with explanation).
- <Project-specific gates: contract checks, evals, type-check, etc.>
- No magic numbers/strings — extract named constants.

## Conventions
- <UI language / i18n rules.>
- Git: stage named paths only — never `git add -A`/`.`; no dotfiles/dot-dirs unless told.
- Owner: {{OWNER_NAME}}. Never add AI attribution (`Co-Authored-By:`, "by Claude", "Generated with Claude Code") to any file, commit, or PR.
- <Canonical files/patterns: "X is the single place that does Y".>

## Architectural decisions
- Recorded as ADRs in `docs/adr/`, template `~/.claude/templates/adr-template.md`, index `docs/adr/README.md`.
- Significant architectural decision: add an ADR in the same change.

## Docs
- `README.md` — overview, architecture, commands, quality gates.
- Docs change only on request (`~/.claude/guides/docs-updates.md`); after a code change, name the doc that needs a line and stop.
- `capabilities.md` — authoritative feature + tech-stack reference; ends with the `DOC-BASELINE` marker.
- `SECURITY.md` — security policy and posture.
- User guide in `docs/user-guides/`. When asked to edit: update `PROGRESS.md`, regenerate `combined.md` / `combined.pdf` via `tools/<guide script>` (PDF only if a guide page changed; always A4).

## Session continuity & memory
- **Handoff:** <handoff file location, if the project uses one>. Read on resume.
- **Memory index:** `~/.claude/projects/<project>/memory/MEMORY.md` — one fact per
  `name.md` file with a one-line pointer in the index.
- When updating any index, create a dedicated `.md` file then add the reference line —
  never inline content into the index; no orphan files.
