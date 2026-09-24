# Project CLAUDE.md

- Every project has its own `CLAUDE.md` at project root. Missing on create/open: create it from `~/.claude/templates/project-claude-template.md`.
- Template is a structure, not content: keep section order (title + one-liner, Stack & Architecture, Commands, Quality gates, Conventions, Architectural decisions, Docs, Session continuity & memory), fill every placeholder from the real project, drop sections/bullets that do not apply (e.g. no C# gate in a frontend-only project), add project-specific ones.
- Never copy facts from another project. Unknown item: `TODO:`.
- Keep it short and agent-facing: what to run, what must pass, what not to break. Detail belongs in `README.md` / `capabilities.md` / ADRs; link, don't duplicate.
- Keep it current: stack, commands, gates, or conventions change: update in the same change.
- Global rules already apply everywhere; repeat one in project `CLAUDE.md` only when the project enforces it in a specific way (e.g. how its test gate works).
