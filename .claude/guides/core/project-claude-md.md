# Project CLAUDE.md

- Every project has its own `CLAUDE.md` at project root. Missing on create/open: create it from `~/.claude/templates/project-claude-template.md`.
- Template is a structure, not content: keep section order (title + one-liner, Stack & Architecture, Commands, Quality gates, Conventions, Architectural decisions, Docs, Session continuity & memory), fill every placeholder from the real project, drop sections/bullets that do not apply (e.g. no C# gate in a frontend-only project), add project-specific ones.
- Never copy facts from another project. Unknown item: `TODO:`.
- Keep it short and agent-facing: what to run, what must pass, what not to break. Detail belongs in `README.md` / `capabilities.md` / ADRs; link, don't duplicate.
- Keep it under 200 lines: a longer file costs context in every session and is followed less well. `@` imports do not lower that cost, because imported files load with the file that imports them. Instructions for one part of the code go in a path-scoped rule (`.claude/rules/` with `paths:`) or a subfolder `CLAUDE.md`.
- Files that load on demand (a subfolder `CLAUDE.md` and its imports, `.claude/rules/` files) are cut off after 40,000 characters on a 200K context window, and the rest is not seen until read by hand. Check with `wc -m <file>`.
- Keep it current: stack, commands, gates, or conventions change: update in the same change.
- Global rules already apply everywhere; repeat one in project `CLAUDE.md` only when the project enforces it in a specific way (e.g. how its test gate works).
