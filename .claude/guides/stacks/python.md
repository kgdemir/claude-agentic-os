# Python

Applies to projects with `pyproject.toml`, `requirements*.txt` or Python scripts that are run more than once.

- **One virtual environment per project** (`python -m venv .venv` or `uv venv`), never the system interpreter; `.venv/` is in `.gitignore`.
  *Why: packages installed globally collide between projects, and a venv committed to git is thousands of files (see the core staging rule).*
- **Dependencies are pinned and locked**: a lock file (`uv.lock`, `poetry.lock`) or `requirements.txt` with exact versions, plus the GPU/CUDA wheels the code needs.
  *Why: an unpinned install on another machine resolves newer, different versions.*
- **Lint and test gates: `ruff check` (and `ruff format --check`), `pytest`,** run from `tools/lint.sh` and `tools/test.sh`.
  *Why: the same zero-warning gate as other stacks; Python has no compiler to catch typos.*
- **Every network call has a timeout** (`requests.get(url, timeout=...)`, `httpx` timeouts).
  *Why: `requests` has no default timeout, so one stalled server hangs the process forever.*
- **Run scripts that read untrusted files with `python -I`**, from a directory other than the files'.
  *Why: Python imports from the script's and current directory first, so a planted `json.py` runs on `import json`.*
