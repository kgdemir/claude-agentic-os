# claude-agentic-os — portable Claude Code rules pack

Global rules, guides and templates for Claude Code, plus `install.sh`, which fills in
per-person placeholders and installs them into `~/.claude`.

## Stack & Architecture
- `.claude/` is the **product**, not this repo's own config: `.claude/CLAUDE.md` is the
  template installed as `~/.claude/CLAUDE.md`, with `{{PLACEHOLDERS}}` left unfilled on
  purpose. Never fill them in here.
- `.claude/guides/core/` is `@`-imported into every session; `stacks/`, `tools/`,
  `features/`, `plugins/` and `addons/` are add-ons listed with a trigger and read
  on demand (ADR-0007). One topic per file; a tool or feature never hides inside
  a stack or core guide. `.claude/templates/*.md`,
  `.claude/hooks/check-agent-brief.py` (ADR-0006), `.claude/bin/runclaude`,
  `.claude/statusline-{linux,macos}.sh`.
- `install.sh` — Bash; detection, substitution, plugins, statusline, settings merge,
  hook registration, auth. Inline Python for JSON edits.

## Commands
- `tools/check-values.sh` — fails when `README.md` or the guide quote a settings value
  that differs from `install.sh` (ADR-0005).
- `bash -n install.sh` — syntax check.
- `python3 -m py_compile .claude/hooks/check-agent-brief.py` — hook syntax check.

## Quality gates (must pass before commit)
- All three commands above.
- Installer changes stay idempotent and never overwrite the person's settings (ADR-0002).
- A new placeholder needs a matching `sed` expression in `install_file()` (ADR-0001).
- No magic numbers/strings — values shared with docs live once in `install.sh`.

## Conventions
- Rules are project-agnostic and carry their cost, or a `*Why:*` line when preventive (`CONTRIBUTING.md`, ADR-0008).
- Git: stage named paths only — never `git add -A`/`.`.
- Owner: Kerim Gökhan DEMİR. Never add AI attribution to any file, commit, or PR.

## Architectural decisions
- ADRs in `docs/adr/`, template `~/.claude/templates/adr-template.md`, index
  `docs/adr/README.md`. Significant decision: add an ADR in the same change.

## Docs
- This repo keeps `README.md`, `CONTRIBUTING.md`, `SECURITY.md` and `docs/adr/` only.
  No `capabilities.md`, `docs/user-guides/` or PDF: the pack has no end users or UI.
- Docs change only on request; after a code change, name the doc that needs a line and stop.

## Session continuity & memory
- **Memory index:** `~/.claude/projects/-home-kgdemir-claude-claude-agentic-os/memory/MEMORY.md`.
