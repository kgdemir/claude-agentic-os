# ADR-0013: Install LSP servers with their plugins, and check them at session start

**Date**: 2026-11-16
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

An LSP plugin only names a language server program (`lspServers.<name>.command`).
The program is installed separately. In one C# and TypeScript project,
`typescript-lsp` was enabled but `typescript-language-server` was missing, and
no C# plugin was installed at all. The `LSP` tool was never used, and every
code lookup, the subagents' too, fell back to grep. Nothing showed that this
had happened. The new rule in `guides/tools/lsp.md` says to look up code
symbols through `LSP`. That rule only helps when the servers can start.

Introduced in commit `f26d4cd`.

## Decision

- `install.sh` installs `csharp-lsp` next to `typescript-lsp` (ADR-0011). After
  installing plugins it offers each server through `offer_install`:
  `typescript-language-server` (`npm install -g typescript-language-server
  typescript`) and `csharp-ls` (`dotnet tool install --global csharp-ls`).
  `--install-deps` installs them, `--no-deps` prints the commands. If `npm`
  or the .NET SDK is missing, the server is skipped with the command to run
  later. A `csharp-ls` left in `~/.dotnet/tools` but not on `PATH` is named.
- `.claude/hooks/check-lsp-servers.py` runs as a `SessionStart` hook. For each
  plugin enabled in the user's `settings.json`, it collects the `lspServers`
  commands from the plugin's marketplace entry, its `.claude-plugin/plugin.json`
  and its `.lsp.json`. It warns, as a `systemMessage` and as context for the
  model, about each command that is not on `PATH`. It is silent when every
  server is found. It never blocks.
- It is registered through `install_hook` like the others (ADR-0006, ADR-0009,
  ADR-0012).

## Alternatives Considered

### Alternative 1: The guide rule alone
- **Pros**: nothing to install or test.
- **Cons**: the model has to remember to check at the start of each session.
  The failure it guards against is exactly one where nothing showed.
- **Why not**: a check that runs by itself catches the case nobody looks for.

### Alternative 2: A hard-coded list of plugins and server commands in the hook
- **Pros**: simpler; it reads no plugin files.
- **Cons**: it goes stale when a plugin is added or a server is renamed.
- **Why not**: the plugin's own `lspServers` entry is the source the
  `LSP` tool itself starts from.

### Alternative 3: Install the servers for all twelve official LSP plugins
- **Pros**: every language is covered.
- **Cons**: it needs Homebrew, Go, Rust, Ruby or a JDK toolchain, and adds
  software the owner does not use.
- **Why not**: the owner asked for C# and TypeScript. Other languages get the
  guide's install offer when they come up.

## Consequences

### Positive
- A missing server is reported in the first moments of a session, not found
  out later from grep-only results.
- A fresh machine gets working C# and TypeScript lookups when the owner says yes.

### Negative
- One more `python3` start at each session start.
- The installer now runs `npm install -g` and `dotnet tool install`, which
  change folders outside `~/.claude` (after asking).

### Risks
- Plugin manifest fields are version-specific. If Claude Code moves
  `lspServers`, the hook goes silent rather than warning. Re-verify after a
  major update.
- Only the user's `settings.json` is read. A plugin enabled only in a project's
  settings is not checked.

## Amendment 2026-11-16

- TypeScript 7, the native port, ships no `tsserver`, and
  `npm install -g typescript` now installs it. A global
  `npm install -g typescript-language-server typescript` therefore gave a server
  that failed with "Could not find a valid TypeScript installation".
- In commit `6d22947`, the installer now puts `typescript-language-server@6` and `typescript@6` in
  their own folder, `~/.local/share/ts-lsp`, linked as
  `~/.local/bin/typescript-language-server`. It skips the step when that
  folder already has a `tsserver.js`, and warns when another copy comes first
  on `PATH`. A project or global `tsc` on TypeScript 7 is left alone; the server
  falls back to its own TypeScript 6. The major versions are constants in
  `install.sh`.
- The hook also warns when `typescript-language-server` has no
  `typescript/lib/tsserver.js` in the session's project or in a folder above
  the server's real file.
- Alternative rejected: pin the whole project to TypeScript 6. It holds back
  the compiler for a tool that only reads code.
