# ADR-0019: Plain text work goes to other models through ask-llm, never code

**Date**: 2026-11-25
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

Every task in a session spends the Claude plan's 5-hour and weekly limits
(ADR-0015), including plain text work that needs no project knowledge: drafts,
translations, rewording, summaries of a given text, many similar short texts.
Cheaper or free models do that work well enough: Gemini's free tier,
OpenRouter's free models, a paid OpenAI mini model, or a small local model in
Ollama. The owner wanted Claude to hand such work off by itself, through the
APIs first and the ChatGPT and Gemini web pages when asked, but **never** for
code. Some text is private (payslips, bank data, customer data) and must not
leave the machine.

## Decision

Implemented in commit `b975eff`.

1. **`.claude/bin/ask-llm`** (Python, standard library) is a thin wrapper over
   Simon Willison's `llm` CLI. It sends the prompt on stdin (never in the process
   list) to each model of a chain in turn: `gemini-3.5-flash`,
   `openrouter/openrouter/free`, `gpt-5.4-mini`. A model with no key, a used-up
   limit, an error or an empty answer is skipped, and the one that answered is
   named. `ASK_LLM_CHAIN` replaces the chain; `--model` picks one model; `--out`
   writes the answer to a file and prints one line.
2. **`--private`** sends only to a local `ollama/<name>` model (default
   `ollama/llama3.2:3b`, fits a 4 GB GPU) and refuses any other model, even one
   named in `ASK_LLM_LOCAL_MODEL`. It never falls back to a remote model.
3. **`.claude/bin/ask-llm-web`** (`uv run --script`, Playwright pinned) types the
   prompt into the ChatGPT or Gemini web page in Chrome with its own profile in
   `~/.claude/ask-llm-web/<site>`, waits until the answer stops changing, and
   prints it without the page's own labels and suggestion buttons. Both sites
   answer guests; `--login` is optional. `ask-llm --web <site>` runs it.
4. **`install.sh`** installs both with the launcher and offers
   `uv tool install llm==0.38` with `llm-gemini`, `llm-ollama` and
   `llm-openrouter`, each pinned. Keys are set by the user with `llm keys set`
   and stay in `llm`'s key file.
5. **The add-on rule `guides/tools/ask-llm.md`** (trigger: plain text work)
   lets Claude decide by itself when to hand off: only output that is big and goes
   straight to a file, private text only through `--private`, output checked
   before use with the model named, the web pages only when the user asks, and a
   Haiku subagent for simple tasks that need project files. Its first rule:
   **never for code** — no source, tests, scripts, commands, SQL, regular
   expressions, configuration, CI files, reviews or fixes, not even as a draft.
6. **`tools/test-ask-llm.sh`**, run by `tools/check.sh`, drives `ask-llm` with a
   stub `llm` on an otherwise empty `PATH`, and `ask-llm-web`'s answer wait with a
   fake page and clock.

## Alternatives Considered

### Alternative 1: Haiku subagents only
- **Pros**: no new tools, keys or providers; the text stays with one company.
- **Cons**: still spends the same Claude plan limits, only less of them.
- **Why not**: kept as the rule for simple tasks that need project files, but it
  does not move work off the plan.

### Alternative 2: Call each provider's API directly from the script
- **Pros**: no `llm` dependency.
- **Cons**: one client, auth scheme and error format per provider to write and
  keep current; key storage to build.
- **Why not**: `llm` and its plugins already do this, keep the keys, and add a
  provider with one plugin.

### Alternative 3: An MCP server for other models
- **Pros**: Claude calls it as a tool, with no shell command.
- **Cons**: a running server per session, its tool list in every context, and
  MCP results come back into the context in full.
- **Why not**: the point is to keep big output out of Claude's context; a shell
  command with `--out` does that with nothing running.

### Alternative 4: Web pages only, no API keys
- **Pros**: no keys, no API cost.
- **Cons**: likely against both sites' terms, can get the account banned, slow,
  and breaks whenever the page changes.
- **Why not**: kept behind `--web`, used only when the user asks.

## Consequences

### Positive
- Plain text work stops spending the Claude plan; free tiers cover most of it.
- One command and one rule cover four providers, and a failing one is skipped.
- Private text has a path that never leaves the machine.

### Negative
- Prompts reach Google, OpenRouter and its providers, or OpenAI, under their
  terms; free tiers may train on them (`SECURITY.md`).
- Another tool to install (`llm` with plugins, `uv`, Chrome or Chromium for
  `--web`), and keys to set by hand.
- Free-tier model names and limits change; the chain needs updating.

### Risks
- An answer from an unchecked model is used as if Claude wrote it. The rule
  requires checking output and naming the model, and forbids code outright.
- A site error message on a web page is returned as an answer (seen once on
  Gemini); the script cannot tell the two apart.
- The web page selectors break without notice; the test covers the wait logic,
  not the live pages.
