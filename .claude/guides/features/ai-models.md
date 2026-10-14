# AI / ML models

Applies when a project ships, calls or experiments with a machine-learning model (an LLM API,
speech-to-text, embeddings, a local model). Adds to the core docs rules in `~/.claude/guides/core/project-docs.md`.

- `capabilities.md` gets an **AI/ML models** section: shipped vs proof-of-concept, where each is
  defined, runtime/config, resource needs.

Code rules:

- **Measure output coverage against input, not just "no error".** For speech-to-text, compare the last segment's end time with the audio duration (and segment count with the voice-activity spans) on a real recording; a pipeline can drop content without raising.
  *Cost: faster-whisper's `BatchedInferencePipeline` ended a 240.8 s track at 196.16 s, silently dropping the last 44 s, and its chunk packer turned 55 VAD spans into 52; the sequential path reached 239.52 s. The speed-up was 1.3x, not the advertised 3-4x.*
- **Filter model inventions before using output:** drop segments below a confidence threshold (`avg_logprob`), known filler/outro phrases, and one word repeated many times; keep digital silence out of noise estimates.
  *Cost: Whisper produced invented phrases on noise and silence until low-confidence segments and repeat loops were filtered.*
- **Deploys to a model host never overwrite its live config** (exclude config files from `rsync --delete`).
  *Cost: same incident as the deploy rule in `~/.claude/guides/stacks/aspnet-core.md`.*
- **API calls have a timeout, bounded retries with backoff, and a spend limit;** API keys come from environment or a secret store only.
  *Why: a hung or retry-looping model call blocks workers and can run up a large bill.*
- **GPU/CUDA libraries are pinned together** with the runtime they were tested on (CUDA, cuDNN, driver minimum).
  *Why: a mismatched cuDNN or CUDA wheel fails only at first inference, on the GPU machine.*
