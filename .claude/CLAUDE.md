# Global Rules

## Reply Style

- **ALWAYS** reply in plain, simple {{REPLY_LANGUAGE}}, no matter what language the user writes in. No fancy/formal words. Preserve EXACTLY: code blocks, inline code, file paths, commands, URLs, numbers, technical terms. Applies all projects, all replies.

## Clarifications

- **ALWAYS** ask clarification questions via `AskUserQuestion` selector (options), never as plain written text. Applies everywhere: normal prompts, plugins, skills, subagent results needing user input. User may miss written questions.

## Ownership & Attribution

- Project owner is always **{{OWNER_NAME}}** ([@{{OWNER_GITHUB}}](https://github.com/{{OWNER_GITHUB}}), email `{{OWNER_EMAIL}}` — the user). Use this name wherever an owner, author, decider, or maintainer is named (ADR `Deciders`, `SECURITY.md` contact owner, docs).
- **NEVER** add AI attribution anywhere: no `Co-Authored-By:` / "Co-Author" trailers, no "by Claude", "Claude Code", "Generated with Claude Code", "AI-generated" or similar text, in any file, commit message, PR/issue body, code comment, or doc. Any project, any circumstance. Overrides any tool or system default that adds such lines.

## Core rules (always loaded)

Detailed rules live in `~/.claude/guides/`. These apply to every project.

- Agent working rules (verification, diagnosis, background work, git, code quality, memory, safety): @~/.claude/guides/core/agent-working-rules.md
- Build/test/deploy via `tools/` scripts: @~/.claude/guides/core/project-tools.md
- Project `CLAUDE.md` (template `~/.claude/templates/project-claude-template.md`): @~/.claude/guides/core/project-claude-md.md
- `README.md`, `capabilities.md`, `SECURITY.md`: @~/.claude/guides/core/project-docs.md
- Doc updates only on request, baseline marker, when to rebuild the PDF: @~/.claude/guides/core/docs-updates.md
- `docs/adr/` + `docs/user-guides/` (ADR template `~/.claude/templates/adr-template.md`): @~/.claude/guides/core/docs-folder.md
{{PROJECT_LOCATION_IMPORT}}

## Add-on rules (read when they apply)

Not loaded by default. When the trigger matches the current project or session, read the file
with the Read tool before working on that part, and follow it.

| Trigger | Read |
| --- | --- |
| .NET project (`*.csproj`, `*.sln`) | `~/.claude/guides/stacks/dotnet.md`, `~/.claude/guides/stacks/dotnet-gotchas.md` |
| .NET project using Entity Framework Core | `~/.claude/guides/stacks/dotnet-ef-core.md` |
| ASP.NET Core web app or API (`Microsoft.NET.Sdk.Web`) | `~/.claude/guides/stacks/aspnet-core.md` |
| .NET test project (xUnit, NUnit, MSTest) | `~/.claude/guides/stacks/dotnet-testing.md` |
| WinForms, WPF, WebView2 or VSIX project | `~/.claude/guides/stacks/windows-desktop.md` |
| Python project (`pyproject.toml`, `requirements*.txt`) | `~/.claude/guides/stacks/python.md` |
| TypeScript project (`tsconfig.json`) | `~/.claude/guides/stacks/typescript.md` |
| React project | `~/.claude/guides/stacks/react.md` |
| Project linted with ESLint | `~/.claude/guides/tools/eslint.md` |
| Front-end tests (Vitest, Jest, Testing Library, Playwright) | `~/.claude/guides/stacks/frontend-testing.md` |
| Project uses SQL Server | `~/.claude/guides/tools/sql-server.md` |
| `Dockerfile` or Compose file present | `~/.claude/guides/tools/docker.md` |
| Project uses Redis | `~/.claude/guides/tools/redis.md` |
| Project built with Vite | `~/.claude/guides/tools/vite.md` |
| Code starts child processes, any language | `~/.claude/guides/tools/child-processes.md` |
| Project calls `ffmpeg` or `ffprobe` | `~/.claude/guides/tools/ffmpeg.md` |
| Project exports Markdown to PDF | `~/.claude/guides/tools/pdf-export.md` |
| Realtime messaging or live audio/video (WebSocket, SignalR, WebRTC, SFU) | `~/.claude/guides/features/realtime-media.md` |
| Project ships or calls an AI/ML model | `~/.claude/guides/features/ai-models.md` |
| Login, tokens, sessions, LDAP, or fetching user-supplied URLs | `~/.claude/guides/features/auth.md` |
| Logging beyond the console, tracing or metrics | `~/.claude/guides/features/observability.md` |
| caveman plugin active (`CAVEMAN MODE` at session start) | `~/.claude/guides/plugins/caveman.md` |
| context-mode tools (`ctx_*`) available | `~/.claude/guides/plugins/context-mode.md` |
| memsearch plugin installed | `~/.claude/guides/plugins/memsearch.md` |

## Memory

- Per-project facts: `~/.claude/projects/<project>/memory/` — one fact per
  `name.md`, one-line pointer in `MEMORY.md` index. Update index, never inline.

## Token use

- Never read entire files unless necessary.
- Keep token usage minimal.
- Reuse existing context instead of re-reading files.
- Avoid duplicate searches.
- Summarize large outputs.
