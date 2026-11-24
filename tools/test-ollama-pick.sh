#!/usr/bin/env bash
# Runs .claude/bin/ollama-pick against pages shaped like ollama.com's library and
# tags pages, and against stub `nvidia-smi` and `ollama`, so nothing is fetched and
# nothing is pulled.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 -I - "$PWD/.claude/bin/ollama-pick" <<'PY'
import datetime, importlib.machinery, importlib.util, os, pathlib, subprocess, sys, tempfile

sys.dont_write_bytecode = True
PICK = sys.argv[1]
loader = importlib.machinery.SourceFileLoader("ollama_pick", PICK)
pick_mod = importlib.util.module_from_spec(importlib.util.spec_from_loader("ollama_pick", loader))
loader.exec_module(pick_mod)
failures = []


def check(name, condition, detail=""):
    if not condition:
        failures.append(f"{name}: {detail}")


def library_entry(name, pulls, updated, chips=()):
    chip_html = "".join(
        f'<span  class="inline-flex items-center rounded-md bg-indigo-50">{c}</span>' for c in chips)
    return (f'<li class="flex"> <a href="/library/{name}" class="group"> {chip_html}'
            f'<span  class="inline-flex items-center rounded-md bg-[#ddf4ff]">4b</span>'
            f'<span >{pulls}</span> <span class="hidden sm:flex">&nbsp;Pulls</span>'
            f'<span class="flex items-center" title="{updated} 10:34 PM UTC"></span></a> </li>')


def tag_row(name, tag, size):
    return (f'<a href="/library/{name}:{tag}" class="md:hidden flex"> <span>{name}:{tag}</span>'
            f' <span class="font-mono"> abc</span> • {size} • 40K context window • </a>')


page = "".join([
    library_entry("old", "120M", "Nov 30, 2024"),
    library_entry("big", "50M", "Oct 9, 2026", ["vision", "cloud"]),
    library_entry("nomic-embed-text", "40M", "Oct 9, 2026", ["embedding"]),
    library_entry("qwen-coder", "30M", "Oct 9, 2026", ["tools"]),
    library_entry("small", "1.5M", "Oct 1, 2026", ["tools"]),
    library_entry("toolarge", "900K", "Oct 1, 2026"),
])
library = pick_mod.parse_library(page)
check("library order and pulls", [(m["name"], m["pulls"]) for m in library][:2]
      == [("old", 120e6), ("big", 50e6)], library)
check("library chips", library[1]["capabilities"] == {"vision", "cloud"}, library[1])
check("library date", library[0]["updated"] == datetime.date(2024, 11, 30), library[0])

tags_page = "".join([
    tag_row("big", "latest", "3.3GB"), tag_row("big", "1b", "815MB"),
    tag_row("big", "4b", "3.3GB"), tag_row("big", "12b", "8.1GB"),
    tag_row("big", "4b-it-q8_0", "4.4GB"), tag_row("big", "bf16", "2.0GB"),
    tag_row("big", "27b-cloud", "-"),
    # The "file size - memory use" form.
    '<a href="/library/big:e2b" class="md:hidden"> <span class="font-mono"> d</span>'
    ' • 2.9GB - 5.1GB • 128K context window • </a>',
])
tags = pick_mod.parse_tags(tags_page, "big")
check("tags default sizes only", {t: round(s, 3) for t, s in tags.items()}
      == {"1b": 0.815, "4b": 3.3, "12b": 8.1, "e2b": 2.9}, tags)

SIZES = {"big": {"1b": 0.8, "4b": 3.3, "12b": 8.1}, "small": {"1b": 0.7, "3b": 2.1},
         "toolarge": {"70b": 40.0}, "old": {"8b": 4.9}}
fetched = []


def tags_of(name):
    fetched.append(name)
    return SIZES.get(name, {})


today = datetime.date(2026, 11, 25)
picks = pick_mod.pick(library, tags_of, budget=3.4, disk=28, today=today, top=5)
check("pick biggest fitting, most pulled first", [p["model"] for p in picks]
      == ["big:4b", "small:3b"], picks)
check("pick skips old, embedding, special purpose", sorted(fetched)
      == ["big", "small", "toolarge"], fetched)
picks = pick_mod.pick(library, tags_of, budget=3.4, disk=4.5, today=today, top=5)
check("pick disk limit", [p["model"] for p in picks] == ["big:1b", "small:3b"], picks)
picks = pick_mod.pick(library, tags_of, budget=3.4, disk=28, today=today, top=1)
check("pick top", [p["model"] for p in picks] == ["big:4b"], picks)
# An installed size needs no download, so a full disk does not drop it.
picks = pick_mod.pick(library, tags_of, budget=3.4, disk=1, today=today, top=5,
                      have={"big:4b"})
check("pick installed ignores disk", [p["model"] for p in picks] == ["big:4b"], picks)
check("same model and variant", pick_mod.is_same_model("big:4b-gpu", "big:4b")
      and pick_mod.is_same_model("big:4b", "big:4b")
      and not pick_mod.is_same_model("big:40b", "big:4b"))


def broken_fetch(url):
    import http.client
    raise http.client.IncompleteRead(b"")


real_fetch = pick_mod.fetch
pick_mod.fetch = broken_fetch
check("tags fetch error is one warning", pick_mod.tags_fetcher("big") == {})
pick_mod.fetch = real_fetch

with tempfile.TemporaryDirectory() as root:
    root = pathlib.Path(root)
    stubs = root / "bin"
    stubs.mkdir()
    log = root / "ollama.log"

    def stub(name, body):
        path = stubs / name
        path.write_text(f"#!{sys.executable}\nimport os, sys\n{body}\n")
        path.chmod(0o755)

    stub("ollama", f"open({str(log)!r}, 'a').write(' '.join(sys.argv[1:]) + '\\n')\n"
                   "sys.exit(int(os.environ.get('STUB_PULL_EXIT', '0')))")
    stub("nvidia-smi", "print('4096, NVIDIA Test GPU')")
    old_path = os.environ["PATH"]
    os.environ["PATH"] = str(stubs)
    try:
        budget, where = pick_mod.memory_budget()
        check("gpu budget", abs(budget - 4 * pick_mod.FIT_SHARE) < 1e-9
              and "NVIDIA Test GPU" in where, (budget, where))
        (stubs / "nvidia-smi").unlink()
        budget, where = pick_mod.memory_budget()
        check("no gpu budget", where.startswith(("CPU", "Mac")) and budget > 0, (budget, where))

        pick_mod.ASK_LLM.LOCAL_MODEL_FILE = root / ".claude" / "ask-llm" / "local-model"
        check("install ok", pick_mod.install("big:4b") == 0
              and pick_mod.ASK_LLM.LOCAL_MODEL_FILE.read_text() == "big:4b\n"
              and log.read_text() == "pull big:4b\n", log.read_text())
        os.environ.pop("ASK_LLM_LOCAL_MODEL", None)
        check("in use from saved file", pick_mod.in_use_model() == "big:4b")
        pick_mod.ASK_LLM.LOCAL_MODEL_FILE.unlink()
        check("in use default", pick_mod.in_use_model()
              == pick_mod.ASK_LLM.DEFAULT_LOCAL_MODEL.removeprefix("ollama/"))
        os.environ["STUB_PULL_EXIT"] = "1"
        check("install failed pull saves nothing", pick_mod.install("big:4b") == 1
              and not pick_mod.ASK_LLM.LOCAL_MODEL_FILE.exists())
    finally:
        os.environ["PATH"] = old_path
        os.environ.pop("STUB_PULL_EXIT", None)

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print("ollama-pick ok")
PY
