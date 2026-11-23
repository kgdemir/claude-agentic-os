#!/usr/bin/env bash
# Runs .claude/bin/lsp-setup against throwaway projects, with stub claude, npm and
# rustup on a PATH that holds nothing else from the host, so nothing real is
# installed and a host's own go or language server cannot change a result (ADR-0018).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 -I - "$PWD/.claude/bin/lsp-setup" <<'PY'
import json, os, pathlib, pty, shutil, subprocess, sys, tempfile

HELPER = sys.argv[1]
failures = []


def check(name, condition, detail=""):
    if not condition:
        failures.append(f"{name}: {detail}")


def stub(bin_dir, name, body):
    path = bin_dir / name
    path.write_text("#!/usr/bin/env python3\nimport json, os, pathlib, sys\n"
                    "pathlib.Path(os.environ['STUB_LOG']).open('a').write(' '.join(sys.argv[1:]) + '\\n')\n"
                    "home = pathlib.Path(os.environ['HOME'])\n" + body)
    path.chmod(0o755)


def make_env(root):
    home = root / "home"
    stubs = root / "stubs"
    system = root / "system"
    for folder in (home / ".claude" / "plugins", stubs, system, home / ".local" / "bin"):
        folder.mkdir(parents=True, exist_ok=True)
    # Only what the stubs and the helper's ln step need, never the host's /usr/bin.
    (system / "python3").symlink_to(sys.executable)
    for tool in ("sh", "env", "ln"):
        (system / tool).symlink_to(shutil.which(tool))
    # claude plugin install <id>: record it as installed and enabled, as the CLI does.
    stub(stubs, "claude", """
pid = sys.argv[3]
inst = home / '.claude' / 'plugins' / 'installed_plugins.json'
data = json.loads(inst.read_text()) if inst.exists() else {'version': 2, 'plugins': {}}
data['plugins'][pid] = [{'scope': 'user'}]
inst.write_text(json.dumps(data))
st = home / '.claude' / 'settings.json'
cfg = json.loads(st.read_text()) if st.exists() else {}
cfg.setdefault('enabledPlugins', {})[pid] = True
st.write_text(json.dumps(cfg))
""")
    # npm install --prefix <dir> <packages>: lay out the server and, for TypeScript, tsserver.
    stub(stubs, "npm", """
prefix = pathlib.Path(sys.argv[3]); packages = ' '.join(sys.argv[4:])
server = 'pyright-langserver' if 'pyright' in packages else 'typescript-language-server'
binary = prefix / 'node_modules' / '.bin' / server
binary.parent.mkdir(parents=True, exist_ok=True)
binary.write_text('#!/bin/sh\\n'); binary.chmod(0o755)
if 'typescript@' in packages:
    ts = prefix / 'node_modules' / 'typescript' / 'lib' / 'tsserver.js'
    ts.parent.mkdir(parents=True, exist_ok=True); ts.write_text('')
""")
    stub(stubs, "rustup", "")
    env = {"HOME": str(home), "STUB_LOG": str(root / "log"),
           "PATH": f"{stubs}:{home / '.local' / 'bin'}:{system}", "LC_ALL": "C"}
    return env, home


def run(env, *args):
    done = subprocess.run([sys.executable, "-I", HELPER, *args], env=env, text=True,
                          stdin=subprocess.DEVNULL, capture_output=True, check=False)
    return done.returncode, done.stdout + done.stderr


def run_tty(env, answer, *args):
    """Run on a pseudo-terminal and type answer at each [Y/n] prompt, as a person would."""
    pid, fd = pty.fork()
    if pid == 0:
        os.execve(sys.executable, [sys.executable, "-I", HELPER, *args], env)
    out, prompts = b"", 0
    while True:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
        while out.count(b"[Y/n]") > prompts:
            os.write(fd, answer.encode() + b"\n")
            prompts += 1
    _, status = os.waitpid(pid, 0)
    return os.waitstatus_to_exitcode(status), out.decode(errors="replace")


def set_plugin(home, pid, enabled):
    """Record a plugin as installed, enabled or not, the way the claude CLI does."""
    inst = home / ".claude" / "plugins" / "installed_plugins.json"
    data = json.loads(inst.read_text()) if inst.exists() else {"version": 2, "plugins": {}}
    data["plugins"][pid] = [{"scope": "user"}]
    inst.write_text(json.dumps(data))
    st = home / ".claude" / "settings.json"
    cfg = json.loads(st.read_text()) if st.exists() else {}
    cfg.setdefault("enabledPlugins", {})[pid] = enabled
    st.write_text(json.dumps(cfg))


def executable(path, body="#!/bin/sh\n"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)
    path.chmod(0o755)


def log(root):
    path = root / "log"
    return path.read_text() if path.exists() else ""


def project(root, *files):
    folder = root / "proj"
    for rel in files:
        target = folder / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("")
    return folder


with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    env, home = make_env(root)

    # Detection: root and service folders count; dependencies and deep folders do not.
    proj = project(root, "tsconfig.json", "api/requirements-dev.txt", "node_modules/x/Cargo.toml",
                   "a/b/c/go.mod", ".hidden/App.csproj")
    code, out = run(env, "detect", str(proj))
    check("detect", out.split() == ["typescript", "python"], out)

    # --answer no only prints what it would run.
    code, out = run(env, "ensure", "--detect", str(proj), "--answer", "no")
    check("answer no: exit", code == 0, out)
    check("answer no: names the commands",
          "claude plugin install pyright-lsp@claude-plugins-official --scope user" in out
          and "npm install --prefix" in out, out)
    check("answer no: runs nothing", log(root) == "", log(root))

    # --answer yes installs plugin and server, and the language is then ready.
    code, out = run(env, "ensure", "--detect", str(proj), "--answer", "yes")
    check("answer yes: exit", code == 0, out)
    check("answer yes: ready", "typescript: ready" in out and "python: ready" in out, out)
    check("answer yes: tsserver beside the server",
          (home / ".local/share/ts-lsp/node_modules/typescript/lib/tsserver.js").is_file(), out)

    # A second run has nothing to do and says nothing.
    before = log(root)
    code, out = run(env, "ensure", "--detect", str(proj), "--answer", "yes")
    check("second run: silent", code == 0 and out == "" and log(root) == before, out)

    # A typescript-language-server with no tsserver beside it does not count.
    (home / ".local/share/ts-lsp/node_modules/typescript/lib/tsserver.js").unlink()
    code, out = run(env, "ensure", "--lang", "typescript", "--answer", "no")
    check("no tsserver: missing", "typescript-language-server is not on PATH" in out, out)

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    env, home = make_env(root)
    proj = project(root, "Cargo.toml")
    declines = home / ".claude" / "lsp-declined.json"

    # --answer no and a run with no terminal only print; neither is saved as a decline.
    for extra in (["--answer", "no"], []):
        run(env, "ensure", "--detect", str(proj), "--remember-declines", *extra)
        check(f"not a person's no {extra}: not saved", not declines.exists(), extra)

    # A person's "no" at the prompt is saved and not asked again.
    code, out = run_tty(env, "n", "ensure", "--detect", str(proj), "--remember-declines")
    saved = json.loads(declines.read_text()) if declines.exists() else {}
    check("decline: saved", saved == {str(proj.resolve()): ["rust"]}, out)
    code, out = run_tty(env, "n", "ensure", "--detect", str(proj), "--remember-declines")
    check("decline: not asked again", "[Y/n]" not in out, out)
    # --lang (install.sh's defaults) is never saved as a decline.
    code, out = run_tty(env, "n", "ensure", "--lang", "go", "--remember-declines")
    check("decline: defaults not saved", json.loads(declines.read_text()) == saved, out)

    # --reask forgets the saved answer and asks again.
    code, out = run_tty(env, "n", "ensure", "--detect", str(proj), "--remember-declines", "--reask")
    check("reask: asked again", "[Y/n]" in out, out)

    # A person's yes installs.
    code, out = run_tty(env, "y", "ensure", "--lang", "rust")
    check("tty yes: rustup ran", "component add rust-analyzer" in log(root), out)

    # rustup's proxy is on PATH but fails until the component is added: not ready.
    proxy = home / ".local" / "bin" / "rust-analyzer"
    proxy.write_text("#!/bin/sh\nexit 1\n"); proxy.chmod(0o755)
    code, out = run(env, "ensure", "--lang", "rust", "--answer", "no")
    check("rust proxy: missing", "rust-analyzer is not on PATH" in out, out)

    # Without the tool that installs the server, the plugin is still set up and the run fails.
    code, out = run(env, "ensure", "--lang", "go", "--answer", "yes")
    check("no go: exit 1", code == 1, out)
    check("no go: plugin installed", "plugin install gopls-lsp@claude-plugins-official" in log(root), log(root))
    check("no go: says why", "no go, so gopls cannot be installed" in out
          and "Then run: go install golang.org/x/tools/gopls@latest" in out, out)

    # Not a terminal: ask turns into no.
    code, out = run(env, "ensure", "--lang", "csharp")
    check("no tty: skipped", "Skipped." in out and "dotnet tool install" not in log(root), out)

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    env, home = make_env(root)
    local_bin = home / ".local" / "bin"
    run(env, "ensure", "--lang", "typescript", "--lang", "python", "--answer", "yes")

    # Installed but ~/.local/bin is not on PATH: PATH advice, no second npm install.
    before = log(root)
    no_local = dict(env, PATH=env["PATH"].replace(f"{local_bin}:", ""))
    code, out = run(no_local, "ensure", "--lang", "typescript", "--answer", "yes")
    check("off PATH: blocked", code == 1 and f"put {local_bin} first on PATH" in out, out)
    check("off PATH: no reinstall", log(root) == before, log(root))

    # A broken copy earlier on PATH: named, and no second npm install.
    shadow = root / "shadow" / "typescript-language-server"
    executable(shadow)
    shadowed = dict(env, PATH=f"{shadow.parent}:{env['PATH']}")
    code, out = run(shadowed, "ensure", "--lang", "typescript", "--answer", "yes")
    check("shadowed: names the copy", f"PATH finds {shadow} first" in out, out)
    check("shadowed: no reinstall", log(root) == before, log(root))

    # The npm folder is complete and only its link is gone: relinked without npm.
    (local_bin / "typescript-language-server").unlink()
    (root / "stubs" / "npm").unlink()
    code, out = run(env, "ensure", "--lang", "typescript", "--answer", "yes")
    check("relink: ready without npm", code == 0 and "typescript: ready" in out, out)

    # csharp-ls in ~/.dotnet/tools, which is not on PATH: PATH advice, no install advice.
    tools = home / ".dotnet" / "tools"
    executable(tools / "csharp-ls")
    set_plugin(home, "csharp-lsp@claude-plugins-official", True)
    code, out = run(env, "ensure", "--lang", "csharp", "--answer", "yes")
    check("csharp off PATH: PATH advice only",
          code == 1 and f"put {tools} first on PATH" in out and "dotnet tool install" not in out, out)

    # A plugin disabled on purpose is neither enabled again nor given a server.
    set_plugin(home, "gopls-lsp@claude-plugins-official", False)
    before = log(root)
    code, out = run(env, "ensure", "--lang", "go", "--answer", "yes")
    check("disabled: left alone", code == 0 and out == "" and log(root) == before, out)

    # A declines file of the wrong shape is reported and treated as empty.
    (home / ".claude" / "lsp-declined.json").write_text("[]")
    proj = project(root, "tsconfig.json")
    code, out = run(env, "ensure", "--detect", str(proj), "--remember-declines")
    check("bad declines: no crash",
          code == 0 and "Traceback" not in out and "treated as empty" in out, out)

if failures:
    print("\n".join(f"!! {f}" for f in failures), file=sys.stderr)
    sys.exit(1)
print("lsp-setup ok")
PY
