#!/usr/bin/env bash
# Runs .claude/bin/ask-llm against a stub `llm` on a PATH that holds nothing else
# from the host, so no model is called and no key is needed, and runs
# ask-llm-web's answer wait against a fake page and clock, so no browser starts
# (ADR-0019).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 -I - "$PWD/.claude/bin/ask-llm" "$PWD/.claude/bin/ask-llm-web" <<'PY'
import importlib.machinery, importlib.util, json, os, pathlib, subprocess, sys
import tempfile, types

ASK, WEB = sys.argv[1], sys.argv[2]
failures = []


def check(name, condition, detail=""):
    if not condition:
        failures.append(f"{name}: {detail}")


# The stub answers per model from STUB_PLAN ({model: [exit, stdout, stderr]}) and
# logs each call's model and stdin to STUB_LOG, one JSON line per call.
# The stub runs on this Python: the PATH below holds no python3.
STUB = f"""#!{sys.executable}
import json, os, sys
model = sys.argv[sys.argv.index("-m") + 1]
prompt = sys.stdin.read()
with open(os.environ["STUB_LOG"], "a") as log:
    log.write(json.dumps({{"model": model, "argv": sys.argv[1:], "stdin": prompt}}) + "\\n")
code, out, err = json.loads(os.environ["STUB_PLAN"]).get(model, [1, "", "Unknown model"])
sys.stdout.write(out); sys.stderr.write(err); sys.exit(code)
"""


def run(root, args, plan=None, env=None, stdin=subprocess.DEVNULL, tools=("llm",)):
    stubs = root / "stubs"
    stubs.mkdir(exist_ok=True)
    for tool in ("llm", "uv"):
        path = stubs / tool
        if tool in tools:
            path.write_text(STUB if tool == "llm" else "#!/bin/sh\nexit 0\n")
            path.chmod(0o755)
        elif path.exists():
            path.unlink()
    log = root / "calls.log"
    log.write_text("")
    full_env = {"PATH": str(stubs), "HOME": str(root), "STUB_LOG": str(log),
                "STUB_PLAN": json.dumps(plan or {})}
    full_env.update(env or {})
    done = subprocess.run([sys.executable, "-I", ASK, *args], env=full_env, stdin=stdin,
                          capture_output=True, text=True, timeout=60, check=False)
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    return done, calls


CHAIN = ["gemini-3.5-flash", "openrouter/openrouter/free", "gpt-5.4-mini"]

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)

    # Chain: a failure and an empty answer both move on; the reason and the model
    # that answered are named.
    done, calls = run(root, ["hello"], {CHAIN[0]: [1, "", "Error: No key found"],
                                        CHAIN[1]: [0, "  \n", ""],
                                        CHAIN[2]: [0, "hi there\n", ""]})
    check("chain exit", done.returncode == 0, done.stderr)
    check("chain answer", done.stdout == "hi there\n", repr(done.stdout))
    check("chain order", [c["model"] for c in calls] == CHAIN, calls)
    check("chain no key reason", f"{CHAIN[0]}: Error: No key found" in done.stderr, done.stderr)
    check("chain empty answer", f"{CHAIN[1]}: empty answer" in done.stderr, done.stderr)
    check("chain answered by", f"answered by {CHAIN[2]}" in done.stderr, done.stderr)
    check("prompt on stdin, not argv", calls[0]["stdin"] == "hello"
          and "hello" not in calls[0]["argv"], calls[0])

    # Every model fails.
    done, calls = run(root, ["hello"], {})
    check("all fail exit", done.returncode == 1, done.stderr)
    check("all fail hint", "no model answered" in done.stderr, done.stderr)

    # ASK_LLM_CHAIN replaces the default chain; --model is one model, no chain line.
    done, calls = run(root, ["hello"], {"a": [0, "A", ""]}, {"ASK_LLM_CHAIN": "a b"})
    check("env chain", [c["model"] for c in calls] == ["a"] and done.stdout == "A\n",
          (calls, done.stdout))
    done, calls = run(root, ["--model", "x", "hello"], {"x": [0, "X\n", ""]})
    check("one model", [c["model"] for c in calls] == ["x"]
          and "answered by" not in done.stderr, (calls, done.stderr))

    # --system goes to llm as -s.
    done, calls = run(root, ["--model", "x", "--system", "be brief", "hello"],
                      {"x": [0, "X\n", ""]})
    check("system prompt", calls and calls[0]["argv"][-2:] == ["-s", "be brief"], calls)

    # Piped text is added below the arguments; /dev/null (not a pipe or file) is not read.
    piped = root / "notes.txt"
    piped.write_text("Bugün hava çok güzel.\n")
    with piped.open() as fh:
        done, calls = run(root, ["Translate:"], {CHAIN[0]: [0, "ok\n", ""]}, stdin=fh)
    check("piped text", calls and calls[0]["stdin"] == "Translate:\n\nBugün hava çok güzel.",
          calls)
    done, calls = run(root, [], {})
    check("no prompt", done.returncode == 2 and "no prompt" in done.stderr and not calls,
          (done.returncode, done.stderr))

    # --out writes the file and prints one line.
    out = root / "answer.md"
    done, calls = run(root, ["--out", str(out), "hello"], {CHAIN[0]: [0, "long text\n", ""]})
    check("out file", out.read_text() == "long text\n", out.read_text())
    check("out line", done.stdout == f"wrote 10 characters to {out}\n", done.stdout)

    # --private: the local model only, never a remote one, even when it fails.
    done, calls = run(root, ["--private", "payslip"], {CHAIN[0]: [0, "remote\n", ""]})
    check("private local only", [c["model"] for c in calls] == ["ollama/llama3.2:3b"], calls)
    check("private fail hint", done.returncode == 1
          and "ollama pull llama3.2:3b" in done.stderr, done.stderr)
    done, calls = run(root, ["--private", "payslip"],
                      {"ollama/llama3.2:3b": [0, "local\n", ""]})
    check("private answer", done.returncode == 0 and done.stdout == "local\n", done.stdout)
    done, calls = run(root, ["--private", "payslip"], {CHAIN[0]: [0, "remote\n", ""]},
                      {"ASK_LLM_LOCAL_MODEL": CHAIN[0]})
    check("private refuses remote model", done.returncode == 1 and not calls
          and "must be a local ollama/" in done.stderr, (calls, done.stderr))

    # Missing tools and wrong combinations: a clear message, no traceback.
    done, calls = run(root, ["hello"], tools=())
    check("no llm", done.returncode == 1 and "llm is not installed" in done.stderr,
          done.stderr)
    done, calls = run(root, ["--web", "gemini", "hello"], tools=())
    check("web without uv", done.returncode == 1 and "--web needs uv" in done.stderr
          and "Traceback" not in done.stderr, done.stderr)
    done, calls = run(root, ["--web", "gemini", "--system", "x", "hello"], tools=("uv",))
    check("web with system", done.returncode == 2
          and "--system does not work with --web" in done.stderr, done.stderr)
    done, calls = run(root, ["--login", "hello"])
    check("login without web", done.returncode == 2 and "--login goes with --web" in done.stderr,
          done.stderr)


# ask-llm-web: load the script with a stand-in playwright module, then drive
# wait_for_answer with a fake page and a clock that moves only when it sleeps.
fake = types.ModuleType("playwright.sync_api")
fake.Error = type("Error", (Exception,), {})
fake.sync_playwright = None
sys.modules["playwright"] = types.ModuleType("playwright")
sys.modules["playwright.sync_api"] = fake
# No __pycache__ next to the script: the pack ships .claude/bin as it is.
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("ask_llm_web", WEB)
web = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(web)


class Clock:
    def __init__(self):
        self.now, self.page = 0.0, None

    def monotonic(self):
        return self.now

    def sleep(self, seconds):
        # Each poll starts with a sleep, so the page moves to its next state here.
        self.now += seconds
        self.page.poll += 1


class Page:
    """Plays one (answer count, busy, text) state per poll; the last one repeats."""

    def __init__(self, states):
        self.states, self.poll, self.skips = states, -1, []

    def state(self):
        return self.states[min(self.poll, len(self.states) - 1)]

    def locator(self, selector):
        page = self
        if selector == "BUSY":
            return types.SimpleNamespace(count=lambda: int(page.state()[1]))

        def evaluate(script, skip):
            page.skips.append(skip)
            return page.state()[2]
        return types.SimpleNamespace(count=lambda: page.state()[0],
                                     last=types.SimpleNamespace(evaluate=evaluate))


clock = Clock()
web.time = types.SimpleNamespace(monotonic=clock.monotonic, sleep=clock.sleep)
spec = {"answer": "ANSWER", "busy": "BUSY", "skip": "SKIP"}
settle_polls = int(web.SETTLE_SECONDS / web.POLL_SECONDS) + 2

# Streaming text, a busy poll, then the same text again: the case that once raised
# TypeError (stable_since reset, last kept).
states = [(1, False, "Hel"), (1, False, "Hello"), (1, True, "Hello")]
states += [(1, False, "Hello")] * settle_polls
page = clock.page = Page(states)
try:
    answer = web.wait_for_answer(page, spec, 0)
except TypeError as exc:
    answer = f"TypeError: {exc}"
check("web busy then same text", answer == "Hello", answer)
check("web skip passed", set(page.skips) == {"SKIP"}, page.skips)

# Old answers on the page do not count; only a new one is returned.
clock.now = 0.0
page = clock.page = Page([(1, False, "old")] * 3 + [(2, False, "new")] * settle_polls)
check("web new answer only", web.wait_for_answer(page, spec, 1) == "new")

# Never finishes: a TimeoutError, which main() reports as one line.
clock.now = 0.0
try:
    clock.page = Page([(1, True, "x")])
    web.wait_for_answer(clock.page, spec, 0)
    check("web timeout", False, "returned")
except TimeoutError:
    pass

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print("ask-llm ok")
PY
