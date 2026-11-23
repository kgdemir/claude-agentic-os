# ADR-0018: LSP plugins and servers follow the languages a project uses

**Date**: 2026-11-24
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

`install.sh` installs two LSP plugins, `typescript-lsp` and `csharp-lsp`, and offers their
language servers (ADR-0013). A project in any other language gets no plugin, so the `LSP`
tool has nothing to start and code lookups fall back to grep, which the core rule says not to
do (ADR-0016, ADR-0017). The official marketplace publishes LSP plugins for more languages, and
Gökhan's projects already include Python (`Bordro`, the Python services in
`chat.eminevim.com.tr`) with no `pyright-lsp` installed.

The servers were set up in Bash inside `install.sh`. `runclaude` (ADR-0014) opens one project
at a time and never looked at LSP, so a project created or cloned after the install was never
checked.

## Decision

1. **One helper, `.claude/bin/lsp-setup`** (Python, standard library, run with `python3 -I`).
   It knows five languages, the ones whose server installs without sudo:

   | Language | Marker files | Plugin | Server, installed with |
   | --- | --- | --- | --- |
   | typescript | `tsconfig.json`, `jsconfig.json`, `package.json` | `typescript-lsp` | `typescript-language-server@6` with `typescript@6` in `~/.local/share/ts-lsp`, linked into `~/.local/bin` |
   | csharp | `*.csproj`, `*.sln`, `*.slnx` | `csharp-lsp` | `dotnet tool install --global csharp-ls` |
   | python | `pyproject.toml`, `setup.py`, `setup.cfg`, `Pipfile`, `requirements*.txt` | `pyright-lsp` | `pyright@1` in `~/.local/share/pyright-lsp`, linked into `~/.local/bin` |
   | go | `go.mod` | `gopls-lsp` | `go install golang.org/x/tools/gopls@latest` |
   | rust | `Cargo.toml` | `rust-analyzer-lsp` | `rustup component add rust-analyzer` |

   Detection reads the project folder and up to two folders below it, and skips hidden
   folders, dependencies and build output (`node_modules`, `bin`, `obj`, `target`, ...).
   For each language it installs the plugin at user scope (`claude plugin install ...
   --scope user`) and installs the server when the one on `PATH` does not work: a
   `typescript-language-server` with no `tsserver` beside it, or a `rust-analyzer` proxy
   that fails to run, counts as missing. A plugin that is installed but disabled was
   turned off on purpose, so that language is left alone. A working server that `PATH`
   does not reach, or reaches only after a broken copy, gets PATH advice instead of a
   second install; a complete npm folder whose `~/.local/bin` link is gone is linked
   again without npm.
2. **`install.sh`** calls it for each of its two default languages whose plugin the
   catalog step installed, plus every language found in the folders under the projects
   root, with `CLAUDE_CONFIG_DIR` set to the folder it installs into. `--install-deps` installs, `--no-deps`, `-y` and a run
   without a terminal only print the commands, as for every other tool. The Bash version of
   the TypeScript and C# server setup is removed.
3. **`runclaude`** calls it for the project it opens, before starting Claude, and asks once
   per missing language. A "no" is saved per project and language in
   `~/.claude/lsp-declined.json` and not asked again; `runclaude --lsp` forgets the saved
   answers for that project and asks again. The installer copies the helper beside
   `runclaude` in `~/.claude/bin`.
4. Other marketplace LSP plugins (Java, Kotlin, C/C++, PHP, Ruby, Swift, Lua) are not
   offered yet: their servers need a system package, sudo or a manual download. They can be
   added to the table when a project needs one.

## Alternatives Considered

### Alternative 1: Install every LSP plugin the marketplace has
- **Pros**: no detection; every language works at once.
- **Cons**: twelve servers, most of them never used, several needing sudo; each enabled plugin
  is loaded in every session.
- **Why not**: cost and installs for languages no project uses.

### Alternative 2: Enable plugins per project in the project's `.claude/settings.json`
- **Pros**: sessions in other projects do not load the plugin.
- **Cons**: `runclaude` would write into every project's repository, which shows up in
  `git status`; one more place to manage.
- **Why not**: Gökhan chose user scope; an LSP plugin with no matching files stays idle.

### Alternative 3: Keep the Bash code in `install.sh` and copy it into `runclaude`
- **Pros**: no new file, no Python in the launcher path.
- **Cons**: two copies of the same install logic that drift apart; detection and JSON in Bash.
- **Why not**: one helper, tested once, serves both.

### Alternative 4: Ask on every launch instead of saving the answer
- **Pros**: no saved state.
- **Cons**: the same question on every launch for a language Gökhan does not want set up.
- **Why not**: a repeated question gets answered without reading.

## Consequences

### Positive
- A Python, Go or Rust project gets working code lookups the first time `runclaude` opens it.
- One tested place (`tools/test-lsp-setup.sh`, run by `tools/check.sh`) holds the server
  install logic for `install.sh` and `runclaude`.

### Negative
- `runclaude` can now install software (npm packages, a dotnet tool, a Go binary, a rustup
  component) after a yes.
- A new file in `~/.claude` (`lsp-declined.json`) and one in `~/.claude/bin`.

### Risks
- A marker can mislead: a `package.json` that only holds scripts still counts as TypeScript.
  The cost is one question, and a "no" is remembered.
- `gopls@latest` is not pinned; a broken gopls release reaches a new install.
- If the official marketplace renames a plugin, the helper's install fails and says so; the
  table needs updating.
