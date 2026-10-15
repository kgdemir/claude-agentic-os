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
  `.claude/hooks/check-agent-brief.py` (ADR-0006),
  `.claude/hooks/check-bash-command.py` (ADR-0009), `.claude/bin/runclaude`,
  `.claude/statusline-{linux,macos}.sh`.
- `install.sh` — Bash; detection, substitution, plugins, statusline, settings merge,
  hook registration, auth. Inline Python for JSON edits.

## Commands
- `tools/check.sh` — every gate below plus a trial install; CI runs it too.
- `tools/test-hooks.sh` — sample events through both hooks (ADR-0009).
- `tools/check-guides.sh` — guide structure: reason lines (baseline
  `tools/check-guides.baseline`), paths, trigger rows, YAML, leak names from the
  gitignored `tools/leak-names.local`.
- `tools/sync-live.sh [--dry-run]` — copy changed pack files into the live
  `~/.claude`, answers from the gitignored `tools/sync-live.local` (ADR-0010).
- `tools/check-values.sh` — fails when `README.md` or the guide quote a settings value
  that differs from `install.sh` (ADR-0005).
- `bash -n install.sh` — syntax check.
- `python3 -m py_compile .claude/hooks/*.py` — hook syntax check (remove the
  `__pycache__` it leaves; `tools/check.sh` does not leave one).

## Quality gates (must pass before commit)
- `tools/check.sh` passes; with `tools/leak-names.local` present locally, so the
  leak check runs (CI skips it).
- Every warn case added to a hook gets a no-warn twin in `tools/test-hooks.sh`.
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
