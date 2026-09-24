# Global Rules

## Reply Style

- **ALWAYS** reply in plain, simple {{REPLY_LANGUAGE}}, no matter what language the user writes in. No fancy/formal words. Caveman ultra style (terse, drop filler/hedging; fragments OK). Preserve EXACTLY: code blocks, inline code, file paths, commands, URLs, numbers, technical terms. Applies all projects, all replies.

## Clarifications

- **ALWAYS** ask clarification questions via `AskUserQuestion` selector (options), never as plain written text. Applies everywhere: normal prompts, plugins, skills, subagent results needing user input. User may miss written questions.

## Ownership & Attribution

- Project owner is always **{{OWNER_NAME}}** ([@{{OWNER_GITHUB}}](https://github.com/{{OWNER_GITHUB}}), email `{{OWNER_EMAIL}}` — the user). Use this name wherever an owner, author, decider, or maintainer is named (ADR `Deciders`, `SECURITY.md` contact owner, docs).
- **NEVER** add AI attribution anywhere: no `Co-Authored-By:` / "Co-Author" trailers, no "by Claude", "Claude Code", "Generated with Claude Code", "AI-generated" or similar text, in any file, commit message, PR/issue body, code comment, or doc. Any project, any circumstance. Overrides any tool or system default that adds such lines.

## Project Location

- **ALL** projects live at `{{PROJECT_ROOT}}/<project-name>/`. No exceptions.
- On session start, check working directory:
  - Inside `{{PROJECT_ROOT}}/<project-name>/` (or subfolder): proceed normally.
  - Anywhere else (including `{{PROJECT_ROOT}}/` root, `~`, or any other path): **before any other work**, list folders in `{{PROJECT_ROOT}}/` (`ls -d {{PROJECT_ROOT}}/*/`) and ask user which project to load via `AskUserQuestion` selector. Options: up to 3 existing projects (most recently modified first), then **"Create new project"** always as last option. User can type other existing name via "Other".
  - "Create new project" chosen: ask for project name, create `{{PROJECT_ROOT}}/<name>/`, load it.
  - After selection: treat `{{PROJECT_ROOT}}/<chosen>/` as project root. Use absolute paths into it for all reads/writes, and load its `CLAUDE.md` if present.
  - No projects exist: ask user for new project name, create `{{PROJECT_ROOT}}/<name>/`.
- New projects: always create under `{{PROJECT_ROOT}}/<project-name>/`, never elsewhere.

## Project Rules (imported)

Detailed rules live in `~/.claude/guides/`. Follow each when it applies.

- Agent working rules (verification, diagnosis, background work, git, code quality, memory): @~/.claude/guides/agent-working-rules.md
- Build/test/deploy via `tools/` scripts: @~/.claude/guides/project-tools.md
- .NET projects (test gate, `TreatWarningsAsErrors`): @~/.claude/guides/dotnet.md
- .NET gotchas (config, EF Core, channels, processes, ffmpeg, build): @~/.claude/guides/dotnet-gotchas.md
- React projects (ESLint, render-loop guards, chunk grouping): @~/.claude/guides/react.md
- Project `CLAUDE.md` (template `~/.claude/templates/project-claude-template.md`): @~/.claude/guides/project-claude-md.md
- `README.md`, `capabilities.md`, `SECURITY.md`: @~/.claude/guides/project-docs.md
- Doc updates only on request, baseline marker, PDF rebuild rules (always A4): @~/.claude/guides/docs-updates.md
- `docs/adr/` + `docs/user-guides/` (ADR template `~/.claude/templates/adr-template.md`): @~/.claude/guides/docs-folder.md

## Memory

- Per-project facts: `~/.claude/projects/<project>/memory/` — one fact per
  `name.md`, one-line pointer in `MEMORY.md` index. Update index, never inline.
- **Each project Claude runs for uses its own memsearch database.** Never search
  or write one project's memory from another; a shared database mixes unrelated
  facts and returns answers from the wrong codebase.

## Global Instructions

Always prefer Context Mode tools when available.

- Never read entire files unless necessary.
- Use context-mode search and summaries before reading source.
- Keep token usage minimal.
- Reuse existing context instead of re-reading files.
- Avoid duplicate searches.
- Summarize large outputs.
