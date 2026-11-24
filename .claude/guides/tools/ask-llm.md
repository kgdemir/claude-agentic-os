# Handing simple text tasks to other models

Applies when a task is plain text work that needs no project knowledge and no judgment
about the code: drafts, rewording, translation, summaries of a given text, many similar
short texts. Three ways, cheapest for the Claude plan first. Claude decides on its own
when a task fits; it does not wait to be asked.

- **Never for code.** Nothing `ask-llm` returns becomes code: no source, tests, scripts,
  shell commands, SQL, regular expressions, configuration, build or CI files, and no
  review or fix of code either. Not as a draft for Claude to edit, not as a snippet inside
  a doc. Code is always written by Claude in the session.
  *Why: the owner forbids it; code from an unchecked model lands in the project as if
  Claude had written and verified it.*
- **Hand off only output that is big and goes straight to a file.** `~/.claude/bin/ask-llm
  --out <file> "<task>" < <input>` writes the answer and prints one line. A short text is
  cheaper to write than to brief, call and check.
  *Why: the prompt, the call and reading the answer back cost Claude tokens too; the saving
  comes only from output Claude does not have to generate or read in full.*
- **Private text goes to `--private` or nowhere.** Payslips, bank and card data, customer or
  personal data, secrets, keys, connection strings and private source code go only to the
  local model (`ask-llm --private`), which never falls back to a remote one. Private is a
  reason to use `--private`, not to skip handing off: when a private task fits the rules
  above, try it first. When the local server is down (`ollama list` fails), start
  `ollama serve` in the background, run the task, and stop the server again; if it still
  fails, do the task in Claude and say why in the reply. Never drop `--private` to get an
  answer.
  *Why: free tiers may log prompts and train on them; text sent there cannot be taken back.
  A session that saw "private" and stopped there spent the plan on work the local model
  could do.*
- **Offer a better local model once per session.** Before the first `--private` task, run
  `~/.claude/bin/ollama-pick --top 3`: it reads the GPU memory and free disk, and lists the
  most pulled models on ollama.com updated within a year that fit. When none of them is
  marked `(in use)`, offer them through `AskUserQuestion` with their size, plus "keep the
  current one". Only after a yes run `ollama-pick --install <model>`, which pulls it and
  makes it the `--private` model. Never pull without asking.
  *Why: the list changes every few months and a bigger model that fits answers much better,
  but a pull is gigabytes of the user's disk and network.*
- **Default chain: Gemini, then OpenRouter's free model, then OpenAI.** `ask-llm` moves to the
  next one when a key is missing or a free limit is reached, and names the model that
  answered on stderr. `--model <id>` picks one; `llm models` lists the ids.
  *Why: the free tiers' daily limits run out, and a fixed single model stops the task there.*
- **Check what comes back before using it.** Read at least a sample of the output file:
  language, format, nothing cut off, nothing invented. Say in the reply which model wrote it.
  *Why: a smaller model fails quietly, and text handed back as Claude's own work is trusted
  as if Claude had checked it.*
- **Web pages: by themselves only when no API key is set.** With no key for Gemini,
  OpenRouter or OpenAI, plain `ask-llm` types the prompt into the ChatGPT page, then the
  Gemini one, in Chrome, and says so on stderr. Both answer without a login; a login done
  once by hand (`ask-llm --web <site> --login`) gives better models. Once any key is set,
  use `ask-llm --web chatgpt|gemini` only when the user asks. Never send private text this
  way, and never call `--web` on your own to get round a failing chain.
  *Why: the user chose the pages over no answer when there is no key; automating them is
  likely against the sites' terms, and the risk lands on the user's account.*
- **Inside Claude, use a Haiku subagent.** For a simple task that needs project files or
  tools, start the `Agent` tool with `model: "haiku"` and a short brief instead of a remote
  model. No data leaves Anthropic, and it uses much less of the plan limits than the main model.
  *Why: remote models cannot read the project, and the main model is the costliest way to do
  simple work.*
