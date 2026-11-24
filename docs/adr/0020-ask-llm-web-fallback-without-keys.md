# ADR-0020: ask-llm falls back to the web pages when no API key is set

**Date**: 2026-11-25
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

ADR-0019 made the ChatGPT and Gemini web pages a path used only when the user
asks for it. Without any API key, the default chain of `ask-llm` (Gemini,
OpenRouter's free router, OpenAI) cannot answer at all, so a new install does
nothing useful until keys are set. Both web pages answer guests without a
login, which was checked live on 2026-11-25. The owner chose the pages over no
answer for that case.

## Decision

Implemented in commit `c457649`. This replaces the "web pages only when the user
asks" part of ADR-0019; the rest of ADR-0019 stands.

1. **Plain `ask-llm`** first checks for a key the default chain needs: `gemini`,
   `openrouter` or `openai` in `llm keys list`, or `LLM_GEMINI_KEY`,
   `OPENROUTER_KEY` or `OPENAI_API_KEY` in the environment. No `llm` installed
   counts as no key. When `llm keys list` fails or hangs, the chain runs as
   before, so its errors say what is wrong.
2. **With no key,** the prompt goes on stdin to `ask-llm-web chatgpt`, then
   `ask-llm-web gemini` if that fails, and stderr names the page that answered.
   `--system` text goes above the prompt, since the pages have no system prompt.
3. **Never** for `--private`, `--model` or `ASK_LLM_CHAIN`: those name what the
   caller wants, and private text must stay on the machine.
4. **Once any key is set,** a failing chain stops with an error as before; it
   does not fall through to the pages.
5. **The add-on rule** lets Claude use the pages by itself only in the no-key
   case, never with private text, and never `--web` to get round a failing chain.

## Alternatives Considered

### Alternative 1: Fall back to the pages whenever the chain fails
- **Pros**: an answer even when every key has run out of free quota.
- **Cons**: the pages would be used on accounts that chose the APIs; a used-up
  limit would quietly move the text to another company.
- **Why not**: with keys set, a failure is something to fix, not to route round.

### Alternative 2: Keep the pages only on request
- **Pros**: no automated use of the sites' pages; nothing sent without a choice.
- **Cons**: a fresh install without keys cannot answer any text task.
- **Why not**: the owner chose the pages over no answer for that case.

## Consequences

### Positive
- `ask-llm` answers on a fresh install, before any key is set.
- Setting one key turns the fallback off; nothing else changes.

### Negative
- Without keys, prompts reach OpenAI's and Google's web products by default,
  under their consumer terms (`SECURITY.md`).
- A web answer takes 8 to 15 seconds and needs `uv` and Chrome or Chromium.

### Risks
- Automating the pages is likely against the sites' terms; the account at risk
  is the browser profile's, a guest one unless the user logged in.
- A site error message can come back as an answer (ADR-0019).
