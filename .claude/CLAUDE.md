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
| `.github/workflows/` present | `~/.claude/guides/tools/github-actions.md` |
| Project has package dependencies and a remote repository | `~/.claude/guides/tools/dependency-updates.md` |
| Project built with Vite | `~/.claude/guides/tools/vite.md` |
| Code starts child processes, any language | `~/.claude/guides/tools/child-processes.md` |
| Project calls `ffmpeg` or `ffprobe` | `~/.claude/guides/tools/ffmpeg.md` |
| Project exports Markdown to PDF | `~/.claude/guides/tools/pdf-export.md` |
| Realtime messaging or live audio/video (WebSocket, SignalR, WebRTC, SFU) | `~/.claude/guides/features/realtime-media.md` |
| Project ships or calls an AI/ML model | `~/.claude/guides/features/ai-models.md` |
| Login, tokens, sessions, LDAP, or fetching user-supplied URLs | `~/.claude/guides/features/auth.md` |
| Logging beyond the console, tracing or metrics | `~/.claude/guides/features/observability.md` |
| Project has or creates `docs/user-guides/` (end-user guide) | `~/.claude/guides/features/user-guide.md` |
| Project stores or processes personal data (names, contacts, ids, location, health, payment) | `~/.claude/guides/features/privacy.md` |
| Project has tests, or a task adds or changes them | `~/.claude/guides/features/testing-strategy.md` |
| Task about speed, memory, load or bundle size, or a launch expecting real traffic | `~/.claude/guides/features/performance.md` |
| HTTP caching, in-memory or distributed caches | `~/.claude/guides/features/caching.md` |
| Adding or restructuring modules, layers or projects | `~/.claude/guides/features/architecture.md` |
| Project exposes an HTTP API (REST, OpenAPI) | `~/.claude/guides/features/api-design.md` |
| Queues, message brokers, scheduled or background jobs | `~/.claude/guides/features/background-jobs.md` |
| Code calls another service over the network, or runs behind a load balancer or orchestrator | `~/.claude/guides/features/resilience.md` |
| Project changes a database schema (any migration tool) | `~/.claude/guides/features/database-migrations.md` |
| Parsing or formatting numbers and dates, comparing strings, storing times, or more than one UI language | `~/.claude/guides/features/i18n.md` |
| Project has a web or desktop UI | `~/.claude/guides/features/accessibility.md` |
| Project serves HTML or an API called from a browser | `~/.claude/guides/features/web-security.md` |
| Project tags releases, publishes packages or images, or keeps `CHANGELOG.md` | `~/.claude/guides/features/releases.md` |
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
