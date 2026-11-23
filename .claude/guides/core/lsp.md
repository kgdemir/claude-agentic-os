# LSP (code navigation)

Applies when a task needs to find where code is defined, used or called: functions, methods,
classes, interfaces, variables, types.

- **Use the `LSP` tool for code symbols, not grep.** Definition: `goToDefinition`. Every use:
  `findReferences`. Callers and callees: `incomingCalls`, `outgoingCalls` (after
  `prepareCallHierarchy`). Implementations of an interface or abstract method:
  `goToImplementation`. Type and docs: `hover`. Outline of one file: `documentSymbol`.
  *Why: grep matches text, so it also hits comments, strings and the same name in other scopes,
  and it misses aliased imports, overloads and calls through an interface.*
- **Find the position first.** Every operation takes a file, line and character. Start from
  `workspaceSymbol` with the name (never an empty query), or `documentSymbol` on the file, then
  pass the position it returns.
  *Why: a position off by one lands on whitespace or a keyword, and the server returns nothing.*
- **Before a rename, delete or signature change, list every caller** with `findReferences` or
  `incomingCalls`, and change them in the same step.
  *Why: a caller missed by a text search breaks the build in a module that was never opened.*
- **grep stays right for text that is not a code symbol:** docs, config keys, log lines, error
  messages, string literals, file names, and languages with no language server.
  *Why: a language server only knows symbols; for plain text, grep is the faster and complete tool.*
- **Templates the server does not read still need grep.** `csharp-ls` reads `.cs` only, and no
  official plugin covers Razor (`.cshtml`, `.razor`) or HTML, so `findReferences` on a C# model
  property, action or view component misses its uses in views, tag helpers and `asp-*`
  attributes. For a rename or delete in an MVC, Razor Pages or Blazor project, take the
  `LSP` results for `.cs` and add a grep over the view files, and say which part came from which.
  The `check-symbol-search.py` hook stays silent on a search scoped to those files.
  *Why: a reference list from the server reads as complete, and the view that still names the
  old property fails only at runtime.*
- **Check that a server can start before the first lookup.** A plugin alone is not enough: it
  only names a server program (the `command` in its `lspServers`), which must be on `PATH`
  (`command -v <command>`). The `check-lsp-servers.py` hook warns at session start when one is
  missing. The plugins in `claude-plugins-official`:
  `clangd-lsp`, `csharp-lsp`, `gopls-lsp`, `jdtls-lsp`, `kotlin-lsp`, `lua-lsp`, `php-lsp`,
  `pyright-lsp`, `ruby-lsp`, `rust-analyzer-lsp`, `swift-lsp`, `typescript-lsp`; each one's
  README gives the install command for its server. Look these up yourself; never tell the user
  "I have not checked whether a plugin exists".
  *Cost: in a C# and TypeScript project, `typescript-lsp` was on but `typescript-language-server`
  was not installed, and no C# plugin was installed although `csharp-lsp` exists. The `LSP` tool
  was never used, and every lookup in the session, the agents' too, fell back to grep unnoticed.*
- **TypeScript 7 has no language server yet; keep TypeScript 6 beside the server.**
  `typescript-language-server` drives TypeScript's `tsserver`, which TypeScript 7 (the native
  port) does not ship. It uses the project's `node_modules/typescript` when that has a `tsserver`,
  else the TypeScript installed next to it. So install the server in its own folder with
  `typescript@6` (`npm install --prefix ~/.local/share/ts-lsp typescript-language-server@6
  typescript@6`, linked into `~/.local/bin`), never with a global `npm install -g typescript`,
  and leave the project and the global `tsc` on 7. Definitions, references and callers come out
  the same. Move to TypeScript 7's own server once it ships one.
  *Cost: a global `npm install -g typescript-language-server typescript` pulled TypeScript 7, and
  the server failed with "Could not find a valid TypeScript installation".*
- **When a plugin or its server is missing,** say so at once and offer both installs through
  `AskUserQuestion`, with the exact commands (`claude plugin install <plugin>@claude-plugins-official`
  and the README's server command). Language servers are loaded when a session starts, so a new
  session is needed after installing. Until then, use grep and say the results are text matches,
  not resolved references.
  *Why: a silent fallback to grep reads as a complete reference list when it is not.*
- **Subagent briefs say it too.** When an agent will look up code symbols, its brief says to use
  the `LSP` tool, or that no server is running and its grep results are text matches.
  *Why: an agent does not see this guide unless told, and defaults to grep.*
- **Offer a better tool when one fits.** When the question is better answered by something else,
  name it and offer it instead of forcing LSP or grep: the compiler or type checker for every
  error in the project, a test run for what the code does at runtime.
  *Why: navigation answers "where", not "does it work"; using it for the second gives a
  confident wrong answer.*
