# ADR-0016: A core LSP rule, and a warn-only hook for text searches on code symbols

**Date**: 2026-11-17
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

`.claude/guides/tools/lsp.md` says to use the `LSP` tool, not grep, to find where a code
symbol is defined, used or called. It is an add-on (ADR-0007): it loads only when the model
notices that its trigger row ("Finding where code is defined, used or called") applies and
reads the file. ADR-0013 made sure the language servers are installed and checked at session
start, so the tool works; nothing makes the model use it.

In a TypeScript/React project session on 2026-11-17, `typescript-lsp` was installed and
`typescript-language-server` was on `PATH`, so the `LSP` tool was available (as a deferred
tool). The model never read `lsp.md` and never called `LSP`. Every lookup in a long session
went through `grep` and `sed` in Bash, including code-symbol lookups (`lazy`, `loadSupabase`,
`AppRoutes`, where a lazy route is defined and used). The owner noticed and asked "are you
using lsp"; the model had not noticed the trigger. Most of that session's searches were CSS
class names, strings and config, where grep is the right tool, so the symbol lookups were
mixed in with valid text searches and the gap stayed invisible.

The same pattern led to ADR-0009: a rule that is only written down is skipped at the moment
it matters, and a warn-only reminder at the moment of the call fixes that without blocking.

## Decision

1. **Core rule.** Add one bullet to `.claude/guides/core/agent-working-rules.md` (loaded every
   session), in the same shape as the other rules:
   "**Code symbols: use the `LSP` tool, not grep.** Definition, references, callers,
   implementations: `goToDefinition`, `findReferences`, `incomingCalls`,
   `goToImplementation`. grep stays right for text that is not a symbol. Details, server
   checks and fallbacks: `~/.claude/guides/tools/lsp.md`." with the cost above.
   `lsp.md` stays the detailed guide; its trigger row stays in the add-on table.
2. **Warn-only hook.** A small sibling, `.claude/hooks/check-symbol-search.py`, registered
   as `PreToolUse` on `Bash|Grep`, not an extension of `check-bash-command.py` (ADR-0009):
   that hook is about core-rule breaks in shell commands, and this one needs the plugin
   files and the `Grep` tool too. It returns a reminder as `additionalContext` and never
   blocks when **all** of these hold:
   - the call is a text search: `grep`, `egrep`, `fgrep`, `rg` or `git grep` in any simple
     command of a Bash line (after `&&`, `;`, `|`), or the `Grep` tool;
   - the pattern is a single identifier (`^[A-Za-z_$][A-Za-z0-9_$]*$`, optionally wrapped in
     `\b`, `\<`, `\>`) of at least 3 characters, not a phrase, a regex with spaces, a CSS
     selector (`.foo`, `foo-bar`) or a path; shorter names are mostly keywords and loop
     variables;
   - the search reads files, not its input: a piped search, or a `grep` with no file and no
     `-r`, reads stdin (`ps aux | grep python`) and stays silent;
   - the search is scoped to files a running server covers (`--include`, `-g`/`--glob`,
     `-t`/`--type`, file or glob arguments, the `Grep` tool's `glob`, `type` or file
     `path`), or it has no scope and `git ls-files` in that folder (2-second limit) lists
     such a file; outside a git repository an unscoped search stays silent;
   - the server can start. The extensions each server covers come from its plugin's
     `extensionToLanguage`, read by `check-lsp-servers.py`'s `server_states()` (ADR-0013),
     which the new hook loads, so both hooks agree on what "can start" means. Without a
     server the hook stays silent, because `lsp.md` already says to fall back to grep and
     say so.
   The reminder: "`<pattern>` looks like a code symbol, and a language server is running
   for these files. Use the `LSP` tool (`workspaceSymbol`, then `findReferences` or
   `goToDefinition`); grep only matches text, … If this is a text search on purpose (a log
   line, a config key), go on and say so (lsp.md)". Unreadable JSON or an internal error
   lets the call through with a note on stderr, as in ADR-0009.
3. **Tests.** Every warn case in `tools/test-hooks.sh` gets a silent twin: identifier vs
   kebab-case name, CSS class, short name and phrase; `.tsx` scope vs `.css`/`.md` scope;
   `rg -t ts` vs `-t css`; a git repository vs a plain folder; a file search vs a piped or
   stdin search; server on `PATH` vs not. Each check was removed once to see its tests fail.

## Alternatives Considered

### Alternative 1: Core rule only, no hook
- **Pros**: no new code; the rule is in every session.
- **Cons**: the session above shows the failure is not knowing the rule but not noticing
  the moment it applies, in the middle of many valid greps.
- **Why not**: ADR-0009 already showed that written rules alone are skipped in exactly this
  way; the hook is cheap and stays silent on valid text searches.

### Alternative 2: Block the search (`permissionDecision: deny`)
- **Pros**: grep can never stand in for a reference lookup.
- **Cons**: the identifier heuristic has false positives (a log message word, a config key
  that looks like an identifier, a symbol in a language with no server); a block stops
  legitimate work.
- **Why not**: same reason as ADR-0009: a reminder keeps the decision with the model and
  the person.

### Alternative 3: Move all of `lsp.md` into core
- **Pros**: the full guide is always loaded.
- **Cons**: about 55 lines in every session, most of it install and TypeScript 7 detail
  that matters only once per machine.
- **Why not**: ADR-0007 keeps core small; one bullet that points to the add-on gives the
  trigger at a fraction of the cost.

## Consequences

### Positive
- Symbol lookups use resolved references, so aliased imports, overloads and calls through an
  interface are not missed, and a rename or delete finds every caller.
- The reminder appears at the call that needs it, with the operation to use instead.

### Negative
- One more pattern check in a hook that already runs on every Bash call, and a new
  `PreToolUse` registration on `Grep` (a Python start per Grep call, a few tens of ms).
- Another heuristic to keep in step with `check-lsp-servers.py`'s language-to-server map.

### Risks
- False positives teach the model to ignore the hook (ADR-0009). The identifier-only pattern,
  the source-file scope and the server check keep valid text searches (CSS classes, strings,
  config keys, docs) silent; each warn case needs a no-warn twin.
- A warn on a valid case (searching an identifier inside comments or docs on purpose) adds
  noise; the reminder is advisory, so the model can proceed and say why.
