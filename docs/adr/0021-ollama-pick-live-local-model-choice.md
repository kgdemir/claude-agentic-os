# ADR-0021: ollama-pick chooses the local model from ollama.com's live list

**Date**: 2026-11-25
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

`ask-llm --private` (ADR-0019) ran one fixed local model, `llama3.2:3b`, sized for
a 4 GB GPU. Machines differ in GPU memory and free disk, and the most used small
models change every few months, so a fixed name in the pack goes stale and wastes
a bigger GPU. The owner asked for a check of the GPU and the free disk, an offer of
better models that fit, always up to date, with the most used ones first. The same
work showed that thinking models such as `qwen3.5` wrote their reasoning into the
answer or returned nothing through `llm`.

## Decision

Implemented in commit `f4e7310`, with the review fixes in the commit after it.

1. **`.claude/bin/ollama-pick`** (Python, standard library) reads the NVIDIA GPU's
   memory with `nvidia-smi` (on a Mac the shared memory, elsewhere the RAM for the
   CPU) and the free disk under `OLLAMA_MODELS` or `~/.ollama`.
2. **The list is fetched live** from `https://ollama.com/library?sort=popular`, most
   pulled first, and each model's tags page gives the file size of each size tag.
   No model name is fixed in the pack. Left out: models not updated within 365
   days, embedding models, single-purpose ones (code, OCR, medicine, translation,
   safety filters), quantization and cloud tags.
3. **A size fits** when its file takes at most 85% of the GPU memory and, unless it
   is already installed, leaves 2 GB of disk free. The biggest fitting size of each
   model is listed, most pulled first; the model `--private` uses now, or a local
   variant of it (`qwen3.5:4b-gpu`), is marked `(in use)`.
4. **`ollama-pick --install NAME`** runs `ollama pull` and writes the name to
   `~/.claude/ask-llm/local-model`. `ask-llm` owns that path, the `ollama/` prefix
   and the default model; `ollama-pick` loads them from the `ask-llm` next to it.
   Order in `ask-llm --private`: `ASK_LLM_LOCAL_MODEL`, then the file, then
   `llama3.2:3b`. An unreadable file gives one warning and the default.
5. **`install.sh`** installs `ollama-pick` with the other bins and, at a terminal
   with `ollama` present, shows the top 3 and asks which to install. `-y` and runs
   without a terminal only print the command: a model is gigabytes.
6. **The add-on rule** has Claude run `ollama-pick --top 3` once per session before
   the first `--private` task, offer the list through `AskUserQuestion` when none is
   `(in use)`, and pull only after a yes. It also tries `--private` first for
   private text that fits, instead of skipping the hand-off.
7. **`ask-llm` sends `-o think false`** to every `ollama/` model, and when llm's
   error names `think` (a plugin without the option), tries once more without it.
8. **`tools/test-ollama-pick.sh`**, run by `tools/check.sh`, drives the parsers and
   the choice with pages shaped like ollama.com's, and stub `nvidia-smi` and `ollama`.

## Alternatives Considered

### Alternative 1: A fixed table of models per GPU size in the pack
- **Pros**: no network call, no HTML parsing, the same answer every run.
- **Cons**: goes stale within months; every new model needs a pack release.
- **Why not**: the owner asked for a list that is always up to date.

### Alternative 2: Rank by newest release instead of pull count
- **Pros**: always shows the latest families first.
- **Cons**: new models with few users and unknown quality come first.
- **Why not**: the owner asked for the most used models; the one-year cut keeps old
  ones out.

### Alternative 3: Pull the best model during install without asking
- **Pros**: `--private` gets a good model with no extra step.
- **Cons**: gigabytes of disk and network nobody agreed to.
- **Why not**: a download that size is the user's choice each time.

## Consequences

### Positive
- Each machine gets the biggest current model its GPU holds.
- No model names to keep current in the pack.

### Negative
- One run fetches up to 41 pages from ollama.com, about 7 seconds.
- Only NVIDIA GPUs are detected; an AMD GPU is sized as the CPU.

### Risks
- The page layout changes and the parser finds nothing; `ollama-pick` then says the
  page changed, and the test covers the parser only against copies of today's layout.
- Ollama may still keep part of a model that fits on the CPU, because it holds GPU
  memory back for the context (seen with `qwen3.5:4b` on 4 GB: 31% CPU, 18 against
  50 tokens per second). A Modelfile variant with `PARAMETER num_gpu 99` fixed it on
  the owner's machine; the pack does not make one.
