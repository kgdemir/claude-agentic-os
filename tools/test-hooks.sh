#!/usr/bin/env bash
# Feeds sample PreToolUse events to the hooks in .claude/hooks/ and checks which
# ones produce a warning. Every case that must warn has a twin that must not, so
# a check that warns on everything fails here as surely as one that never warns.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 -I - "$PWD/.claude/hooks" <<'PY'
import json, os, subprocess, sys, tempfile

HOOKS = sys.argv[1]
HOOK_TIMEOUT_SECONDS = 10

def run(hook, event):
    try:
        out = subprocess.run([sys.executable, "-I", os.path.join(HOOKS, hook)], input=json.dumps(event),
                             capture_output=True, text=True, check=True, timeout=HOOK_TIMEOUT_SECONDS).stdout
    except subprocess.TimeoutExpired:
        return "HOOK HUNG"
    return json.loads(out)["hookSpecificOutput"]["additionalContext"] if out.strip() else ""

def bash(command, cwd=""):
    return {"tool_name": "Bash", "tool_input": {"command": command}, "cwd": cwd}

failures = []
def expect(name, hook, event, must_contain):
    got = run(hook, event)
    ok = (must_contain in got) if must_contain else (got == "")
    if not ok:
        wanted = repr(must_contain) if must_contain else "no warning"
        failures.append(f"{name}: expected {wanted}, got {got!r}")

B = "check-bash-command.py"
# git safety
expect("add -A", B, bash("git add -A"), "stage named paths")
expect("add .", B, bash("cd x && git add ."), "stage named paths")
expect("add -C path .", B, bash("git -C /repo add ."), "stage named paths")
expect("add named", B, bash("git add README.md src/app.py"), None)
expect("push --force", B, bash("git push --force origin main"), "--force-with-lease")
expect("push -f", B, bash("git push -f"), "--force-with-lease")
expect("push +ref", B, bash("git push origin +main"), "--force-with-lease")
expect("push lease", B, bash("git push --force-with-lease origin main"), None)
expect("push plain", B, bash("git push -u origin main"), None)
expect("reset hard", B, bash("git reset --hard HEAD~1"), "reset --hard")
expect("reset soft", B, bash("git reset --soft HEAD~1"), None)
expect("clean -fd", B, bash("git clean -fd"), "git clean -f")
expect("clean -n", B, bash("git clean -n"), None)
expect("force push on a second line", B, bash("git status\ngit push --force"), "--force-with-lease")
expect("force push named in a multi-line message", B, bash('git commit -m "fix: x\n\ngit push --force now warns"'), None)
expect("force push named in a $'...' message", B, bash("git commit -m $'fix: x\\n\\ngit push --force now warns'"), None)
expect("add . named in a multi-line message", B, bash('git commit -m "fix: x\n\ngit add . is gone"'), None)
# attribution
expect("co-author", B, bash('git commit -m "fix: x\n\nCo-Authored-By: Bot <noreply@anthropic.com>"'), "AI attribution")
expect("generated", B, bash('gh pr create --body "Generated with [Claude Code](https://x)"'), "AI attribution")
expect("clean commit", B, bash('git commit -m "fix: tidy"'), None)
expect("grep is not a commit", B, bash("grep -ri co-authored-by: ."), None)
expect("commit word in a test file", B, bash("cat > t.py <<'EOF'\nrun('git commit -m \"x\\n\\nCo-Authored-By: Bot\"')\nEOF"), None)
expect("commit after an unrelated mention", B, bash('grep -rn "Co-Authored-By:" docs; git commit -m "fix: tidy"'), None)
expect("commit message in $(cat <<EOF)", B, bash("git commit -m \"$(cat <<'EOF'\nfix: x\n\nCo-Authored-By: Bot <noreply@anthropic.com>\nEOF\n)\""), "AI attribution")
expect("message piped into commit -F -", B, bash("printf 'fix\\n\\nGenerated with Claude Code\\n' | git commit -F -"), "AI attribution")
expect("message file written then used", B, bash("cat > msg.txt <<'EOF'\nfix: x\n\nCo-Authored-By: Bot\nEOF\ngit commit -F msg.txt"), "AI attribution")
expect("pr body file written then used", B, bash("cat > body.md <<'EOF'\nGenerated with [Claude Code](https://x)\nEOF\ngh pr create --body-file body.md"), "AI attribution")
# gate pipes
expect("npm lint | tail", B, bash("npm run lint 2>&1 | tail -1"), "pipefail")
expect("dotnet test | grep", B, bash("dotnet test | grep -i failed"), "pipefail")
expect("tools script | tail", B, bash("tools/test.sh | tail -5"), "pipefail")
expect("pipefail set", B, bash("set -o pipefail; npm run lint | tail -1"), None)
expect("gate unpiped", B, bash("npm run lint && git status | head"), None)
expect("non-gate pipe", B, bash("git log --oneline | head -5"), None)
expect("or is not a pipe", B, bash("npm test || echo failed"), None)
expect("gate name as an argument", B, bash("grep -n python3 tools/check.sh | head -3"), None)
expect("gate words in a string", B, bash('echo "npm run lint" | wc -c'), None)
expect("pipes in a heredoc body", B, bash("python3 - <<'EOF'\nx = 'a|tsc|b'\nEOF\ntools/test-hooks.sh"), None)
expect("git add . in a heredoc body", B, bash("cat > steps.sh <<EOF\ngit add .\nEOF"), None)
expect("gate after a heredoc", B, bash("cat <<'EOF' > x\na\nEOF\nnpm test | tail -1"), "pipefail")
expect("attribution in a heredoc", B, bash("git commit -F - <<'EOF'\nfix: x\n\nCo-Authored-By: Bot <noreply@anthropic.com>\nEOF"), "AI attribution")
expect("./tools script | tail", B, bash("./tools/check.sh | tail -1"), "pipefail")
expect("env prefix gate | tail", B, bash("CI=1 npm test | tail -1"), "pipefail")
expect("npx eslint | tail", B, bash("npx eslint . | tail -1"), "pipefail")
expect("python -m pytest | tail", B, bash("python3 -m pytest -q | tail -1"), "pipefail")

# secrets: a throwaway repo; key-shaped strings are assembled here, never stored.
with tempfile.TemporaryDirectory() as repo:
    git = lambda *a: subprocess.run(["git", "-C", repo, *a], check=True, capture_output=True)
    git("init", "-q")
    fake_key = "AKIA" + "ABCDEFGHIJKLMNOP"
    with open(os.path.join(repo, "settings.py"), "w") as fh:
        fh.write(f'KEY = "{fake_key}"\n')
    with open(os.path.join(repo, "clean.py"), "w") as fh:
        fh.write("KEY = os.environ['KEY']\n")
    git("add", "clean.py")
    # which files the hook opens, through an audit hook around the real script
    def opened(command):
        probe = ("import runpy, sys\n"
                 "sys.addaudithook(lambda e, a: e == 'open' and isinstance(a[0], str)"
                 " and a[0].endswith('settings.py') and print(a[0], file=sys.stderr))\n"
                 "runpy.run_path(sys.argv[1], run_name='__main__')\n")
        return subprocess.run([sys.executable, "-I", "-c", probe, os.path.join(HOOKS, B)],
                              input=json.dumps(bash(command, repo)), capture_output=True, text=True,
                              timeout=HOOK_TIMEOUT_SECONDS).stderr
    if opened("cat settings.py > copy.py"):
        failures.append("cat with no commit: the hook read the source file")
    if not opened("cat settings.py > m && git commit -F m"):
        failures.append("cat then commit -F: the hook did not read the source file")
    expect("clean staged", B, bash("git commit -m x", repo), None)
    git("add", "settings.py")
    got = run(B, bash("git commit -m x", repo))
    if "settings.py: AWS access key" not in got:
        failures.append(f"secret staged: expected a warning, got {got!r}")
    if fake_key in got:
        failures.append("secret staged: the warning repeats the secret value")
    expect("no commit, no scan", B, bash("git status", repo), None)
    with open(os.path.join(repo, "msg.txt"), "w") as fh:
        fh.write("fix: x\n\nCo-Authored-By: Bot <noreply@anthropic.com>\n")
    expect("message file on disk", B, bash("git commit -F msg.txt", repo), "AI attribution")
    # the scan runs where the commit does: after a `cd`, or under `git -C`
    parent, name = os.path.split(repo)
    expect("cd into the repo, then commit", B, bash(f"cd {name} && git commit -m x", parent), "AWS access key")
    expect("git -C repo commit", B, bash(f"git -C {name} commit -m x", parent), "AWS access key")
    expect("commit outside the repo", B, bash("git commit -m x", parent), None)

# message files and line continuations: a plain folder, no repository, so the
# secret scan has nothing to report.
with tempfile.TemporaryDirectory() as work:
    def write(name, text):
        os.makedirs(os.path.dirname(os.path.join(work, name)), exist_ok=True)
        with open(os.path.join(work, name), "w") as fh:
            fh.write(text)
    write("notes.md", "Generated with Claude Code\n")
    write("clean.md", "fix: tidy\n")
    write("m.txt", "fix\n\nCo-Authored-By: Bot\n")
    write("sub/msg.txt", "fix\n\nCo-Authored-By: Bot\n")
    os.mkfifo(os.path.join(work, "pipe"))
    expect("-F on a fifo does not hang", B, bash("git commit -F pipe", work), None)
    expect("release --notes-file", B, bash("gh release create v1 --notes-file notes.md", work), "AI attribution")
    expect("release clean notes", B, bash("gh release create v1 --notes-file clean.md", work), None)
    expect("bundled -aF file", B, bash("git commit -aF m.txt", work), "AI attribution")
    expect("bundled -aFfile", B, bash("git commit -aFm.txt", work), "AI attribution")
    expect("bundled -a clean", B, bash("git commit -aF clean.md", work), None)
    expect("git -C dir -F file", B, bash("git -C sub commit -F msg.txt", work), "AI attribution")
    expect("git -C dir, file not there", B, bash("git -C sub commit -F m.txt", work), None)
    expect("cd, then a relative -F", B, bash("cd sub && git commit -F msg.txt", work), "AI attribution")
    expect("cd, file not in that folder", B, bash("cd sub && git commit -F m.txt", work), None)
    expect("cd and back, -F of a file written there", B, bash(
        "cd sub && printf 'fix\\n\\nCo-Authored-By: Bot\\n' > n.txt && cd .. && git commit -F sub/n.txt", work), "AI attribution")
    expect("cd and back, -F of the name only", B, bash(
        "cd sub && printf 'fix\\n\\nCo-Authored-By: Bot\\n' > n.txt && cd .. && git commit -F n.txt", work), None)
    expect("cd in a pipe stage moves nothing", B, bash("cd sub | true; git commit -F m.txt", work), "AI attribution")
    expect("printf > file then -F", B, bash("printf 'fix\\n\\nCo-Authored-By: Bot\\n' > new.txt && git commit -F new.txt", work), "AI attribution")
    expect("printf clean > file then -F", B, bash("printf 'fix: tidy' > new.txt && git commit -F new.txt", work), None)
    expect("cat file > msg then -F", B, bash("cat m.txt > out.txt && git commit -F out.txt", work), "AI attribution")
    expect("cat clean > msg then -F", B, bash("cat clean.md > out.txt && git commit -F out.txt", work), None)
    expect("cp file then -F", B, bash("cp notes.md out.md && gh pr create --body-file out.md", work), "AI attribution")
    expect("cp clean then -F", B, bash("cp clean.md out.md && gh pr create --body-file out.md", work), None)
expect("trailer on a continued line", B, bash('git commit -m "fix" \\\n  --trailer "Co-authored-by: Bot"'), "AI attribution")
expect("clean continued commit", B, bash('git commit -m "fix" \\\n  --signoff'), None)
expect("force push on a continued line", B, bash("git push origin main \\\n  --force"), "--force-with-lease")
expect("gate pipe on a continued line", B, bash("npm test \\\n  | tail -1"), "pipefail")
expect("trailer on a CRLF-continued line", B, bash('git commit -m "fix" \\\r\n  --trailer "Co-authored-by: Bot"'), "AI attribution")
expect("clean CRLF-continued commit", B, bash('git commit -m "fix" \\\r\n  --signoff'), None)
# $'...' quoting: read as one word, not as unbalanced quotes
expect("attribution in $'...'", B, bash("git commit -m $'fix\\n\\nCo-Authored-By: Bot'"), "AI attribution")
expect("$'...' next to an unrelated mention", B, bash("""printf $'a\\'b'; grep -rn "Co-Authored-By:" docs; git commit -m "fix: tidy\""""), None)
expect("$' inside double quotes is literal", B, bash("""echo "a$'b" && git commit -m x --trailer Co-authored-by:Bot"""), "AI attribution")
expect("$' inside double quotes, clean commit", B, bash("""echo "a$'b" && git commit -m x --signoff"""), None)
expect("$' inside single quotes is literal", B, bash("""echo 'cost $'; grep -rn "Co-Authored-By:" docs; git commit -m "fix: tidy\""""), None)

# robustness: never break a session
expect("other tool", B, {"tool_name": "Read", "tool_input": {"file_path": "x"}}, None)
expect("bad input", B, {"tool_name": "Bash", "tool_input": "x"}, None)

# brief hook
A = "check-agent-brief.py"
agent = lambda prompt, kind="general-purpose": {"tool_name": "Agent", "tool_input": {"prompt": prompt, "subagent_type": kind}}
expect("brief missing", A, agent("do the thing"), "`Goal:`")
expect("brief complete", A, agent("Goal: x\nFiles: y\nDone: z"), None)
expect("brief exempt", A, agent("find x", "Explore"), None)

# usage log (PostToolUse + UserPromptSubmit): checks the log lines it writes, and that it stays silent
U = "log-usage.py"
old_config = os.environ.get("CLAUDE_CONFIG_DIR")
try:
    with tempfile.TemporaryDirectory() as home:
        config = os.path.join(home, ".claude")
        os.environ["CLAUDE_CONFIG_DIR"] = config
        mem = os.path.join(config, "projects", "-p", "memory")
        guides = os.path.join(config, "guides", "stacks")
        other = os.path.join(home, "notes")
        for d in (mem, guides, other):
            os.makedirs(d)
        logs = {"memory": os.path.join(mem, ".access.log"),
                **{k: os.path.join(config, "usage", k + ".log") for k in ("guides", "skills", "agents")}}
        snapshot = lambda: {k: open(v).read() if os.path.exists(v) else "" for k, v in logs.items()}
        tool = lambda name, **inp: {"tool_name": name, "tool_input": inp, "session_id": "s1"}
        def logged(name, event, where=None, entry=None):
            before = snapshot()
            expect(name + " (silent)", U, event, None)
            after = snapshot()
            new = {k: after[k][len(before[k]):] for k in logs if after[k] != before[k]}
            want = {where: f"\ts1\t{entry}\n"} if where else {}
            if set(new) != set(want) or any(not new[k].endswith(want[k]) or new[k].count("\n") != 1
                                            or not new[k].split("\t")[0].isdigit() for k in want):
                failures.append(f"{name}: expected {want or 'no log line'}, got {new!r}")
        logged("memory topic read", tool("Read", file_path=os.path.join(mem, "fact.md")), "memory", "fact.md")
        logged("memory index read", tool("Read", file_path=os.path.join(mem, "MEMORY.md")))
        logged("guide read", tool("Read", file_path=os.path.join(guides, "dotnet.md")), "guides", "stacks/dotnet.md")
        logged("md elsewhere", tool("Read", file_path=os.path.join(other, "fact.md")))
        logged("non-md in memory", tool("Read", file_path=os.path.join(mem, "fact.txt")))
        logged("skill call", tool("Skill", skill="p1:used"), "skills", "p1:used")
        logged("skill call, bad input", tool("Skill", skill=3))
        logged("agent call", tool("Agent", subagent_type="p1:helper"), "agents", "p1:helper")
        logged("agent, default type", tool("Agent", prompt="x"), "agents", "general-purpose")
        logged("slash prompt", {"hook_event_name": "UserPromptSubmit", "prompt": "/p1:typed now", "session_id": "s1"},
               "skills", "p1:typed")
        logged("plain prompt", {"hook_event_name": "UserPromptSubmit", "prompt": "fix a/b", "session_id": "s1"})
        logged("other tool", tool("Edit", file_path=os.path.join(mem, "fact.md")))
        logged("bad input", {"tool_name": "Read", "tool_input": "x"})

        def report(*args, stderr_has=None):
            done = subprocess.run([sys.executable, "-I", os.path.join(HOOKS, U), "--report", *args],
                                  capture_output=True, text=True)
            if done.returncode:
                failures.append(f"report {args}: exit {done.returncode}: {done.stderr.strip()[-300:]}")
            if stderr_has and stderr_has not in done.stderr:
                failures.append(f"report {args}: expected {stderr_has!r} on stderr, got {done.stderr!r}")
            return done.stdout.splitlines()
        def order(name, lines, want):
            got = [(r.split()[0], r.split()[-1]) for r in lines if r.split() and r.split()[0].isdigit()]
            if got != want:
                failures.append(f"report {name}: expected {want}, got {lines!r}")
        for f in ("fact.md", "unread.md"):
            open(os.path.join(mem, f), "w").close()
        order("memory", report("memory", mem), [("0", "unread.md"), ("1", "fact.md")])
        open(os.path.join(guides, "dotnet.md"), "w").close()
        open(os.path.join(guides, "python.md"), "w").close()
        order("guides", report("guides"), [("0", "stacks/python.md"), ("1", "stacks/dotnet.md")])
        plugin = os.path.join(home, "p1")
        for d in ("skills/used", "skills/idle", "agents"):
            os.makedirs(os.path.join(plugin, d))
        open(os.path.join(plugin, "skills", "used", "SKILL.md"), "w").write("---\nname: used\n---\n")
        open(os.path.join(plugin, "skills", "idle", "SKILL.md"), "w").write("---\nname: idle\n---\n")
        open(os.path.join(plugin, "agents", "helper.md"), "w").write("---\nname: helper\n---\n")
        os.makedirs(os.path.join(home, "p2", "skills", "never"))
        open(os.path.join(home, "p2", "skills", "never", "SKILL.md"), "w").close()
        os.makedirs(os.path.join(config, "plugins"))
        json.dump({"plugins": {"p1@m": [{"installPath": plugin}], "p2@m": [{"installPath": os.path.join(home, "p2")}]}},
                  open(os.path.join(config, "plugins", "installed_plugins.json"), "w"))
        rows = [r.split() for r in report("plugins") if r.split() and r.split()[0].isdigit()]
        got = [(r[0], r[-3], r[-2], r[-1]) for r in rows if r[-1] in ("p1", "p2")]
        if got != [("0", "0/1", "0/0", "p2"), ("2", "1/2", "1/1", "p1")]:
            failures.append(f"report plugins: expected p2 unused before p1 (2 uses), got {rows!r}")

        # review fixes (ADR-0012): each case would pass without its fix only by accident
        repo_mem = os.path.join(home, "repo", "projects", "web", "memory")
        os.makedirs(repo_mem)
        logged("memory-shaped folder outside config", tool("Read", file_path=os.path.join(repo_mem, "fact.md")))
        if os.path.exists(os.path.join(repo_mem, ".access.log")):
            failures.append("memory-shaped folder outside config: wrote a .access.log into the repo")
        slash = lambda text: {"hook_event_name": "UserPromptSubmit", "prompt": text, "session_id": "s1"}
        logged("prompt starting with a path", slash("/home/x/app.py is broken"))
        logged("bare skill call", tool("Skill", skill="used"), "skills", "used")
        logged("typed bare command", slash("/used"), "skills", "typed/used")
        logged("ambiguous bare skill call", tool("Skill", skill="dup"), "skills", "dup")
        logged("root path typed alone", slash("/tmp"))
        for plug in ("p1", "p3"):
            os.makedirs(os.path.join(home, plug, "commands"), exist_ok=True)
            open(os.path.join(home, plug, "commands", "dup.md"), "w").close()
        # two installs of p3: skills in either path count; no frontmatter: a body "name:" is ignored
        p3b = os.path.join(home, "p3b")
        os.makedirs(os.path.join(p3b, "agents"))
        open(os.path.join(p3b, "agents", "real.md"), "w").write("# Agent\nname: wrong\n")
        plugins_json = os.path.join(config, "plugins", "installed_plugins.json")
        json.dump({"plugins": {"p1@m": [{"installPath": plugin}], "p2@m": [{"installPath": os.path.join(home, "p2")}],
                               "p3@m": [{"installPath": os.path.join(home, "p3")}, {"installPath": p3b}, "junk"]}},
                  open(plugins_json, "w"))
        logged("agent of a second install", tool("Agent", subagent_type="p3:real"), "agents", "p3:real")
        rows = {r.split()[-1]: r.split() for r in report("plugins") if r.split() and r.split()[0].isdigit()}
        if rows.get("p1", [None])[0] != "3":
            failures.append(f"bare skill call: expected p1 at 3 uses (p1:used, helper, used; typed /used not), got {rows.get('p1')}")
        if rows.get("p3", [None])[0] != "1" or rows.get("p3", [""])[-2] != "1/1":
            failures.append(f"second install / frontmatter name: expected p3 1 use, agents 1/1, got {rows.get('p3')}")
        open(plugins_json, "w").write("{not json")
        report("plugins", stderr_has="plugins left out")
        open(plugins_json, "w").write("[1, 2]")
        report("plugins", stderr_has="shape")
        unreadable = os.path.join(plugin, "skills", "used", "SKILL.md")
        json.dump({"plugins": {"p1@m": [{"installPath": plugin}]}}, open(plugins_json, "w"))
        os.chmod(unreadable, 0)
        if not os.access(unreadable, os.R_OK):  # root can still read it; skip there
            report("plugins", stderr_has="cannot read")
        os.chmod(unreadable, 0o644)
        # unix times compare as numbers: 999 is before 1000, though "999" > "1000" as text
        tz = os.path.join(home, "tz")
        os.makedirs(tz)
        for f in ("a.md", "b.md"):
            open(os.path.join(tz, f), "w").close()
        open(os.path.join(tz, ".access.log"), "w").write("1000\ts\tb.md\n999\ts\ta.md\n")
        order("unix time order", report("memory", tz), [("1", "a.md"), ("1", "b.md")])
        # second review (ADR-0012): bad lines are skipped and counted, old ISO lines still read
        bad = os.path.join(home, "bad")
        os.makedirs(bad)
        for f in ("a.md", "b.md", "c.md"):
            open(os.path.join(bad, f), "w").close()
        open(os.path.join(bad, ".access.log"), "w").write(
            "\ts\tb.md\n99999999999999\ts\tb.md\nnot-a-time\ts\tb.md\nshort line\n"
            "2026-11-09T10:00:00+03:00\ts\tc.md\n5\ts\ta.md\n")
        rows = report("memory", bad, stderr_has="4 line(s)")
        order("bad lines", rows, [("0", "b.md"), ("1", "a.md"), ("1", "c.md")])
        if not any(r.startswith("logged since") for r in rows):
            failures.append(f"bad lines: expected a 'logged since' line, got {rows!r}")
        logged("command then punctuation", slash("/used, please"), "skills", "typed/used")
        # a user skill or agent of the same name wins over the one plugin item
        os.makedirs(os.path.join(config, "skills", "mine"))
        open(os.path.join(config, "skills", "mine", "SKILL.md"), "w").close()
        os.makedirs(os.path.join(config, "agents"))
        open(os.path.join(config, "agents", "aide.md"), "w").write("---\nname: aide\n---\n")
        p4 = os.path.join(home, "p4")
        for d in ("skills/mine", "agents"):
            os.makedirs(os.path.join(p4, d))
        open(os.path.join(p4, "skills", "mine", "SKILL.md"), "w").write("\ufeff---\nname: mine\n---\n")
        open(os.path.join(p4, "agents", "aide.md"), "w").write("---\nname: aide\n---\n")
        p4b = os.path.join(home, "p4b")
        os.makedirs(os.path.join(p4b, "skills", "folder"))
        # BOM before the frontmatter: the declared name still wins over the folder name
        open(os.path.join(p4b, "skills", "folder", "SKILL.md"), "w").write("\ufeff---\nname: other\n---\n")
        json.dump({"plugins": {"p4@m1": [{"installPath": p4}], "p4@m2": [{"installPath": p4b}]}}, open(plugins_json, "w"))
        logged("typed user skill", slash("/mine"), "skills", "typed/mine")
        logged("user agent", tool("Agent", subagent_type="aide"), "agents", "aide")
        logged("plugin skill from the second marketplace", tool("Skill", skill="p4:other"), "skills", "p4:other")
        rows = {r.split()[-1]: r.split() for r in report("plugins") if r.split() and r.split()[0].isdigit()}
        if rows.get("p4", [None])[0] != "1" or rows.get("p4", [""])[-3] != "1/2":
            failures.append(f"user names win, marketplaces merge, BOM: expected p4 1 use, skills 1/2, got {rows.get('p4')}")
        lines = report("plugins")
        user_row = [r.split() for r in lines if r.endswith("(user skills and agents)")]
        if not user_row or user_row[0][0] != "2":
            failures.append(f"typed user skill: expected the user row at 2 uses (typed /mine, aide), got {lines!r}")
        # project items: found from the session's cwd or a folder above it; the user's config is not a project
        repo2 = os.path.join(home, "repo2")
        os.makedirs(os.path.join(repo2, ".claude", "skills", "proj"))
        open(os.path.join(repo2, ".claude", "skills", "proj", "SKILL.md"), "w").close()
        os.makedirs(os.path.join(repo2, ".claude", "agents"))
        open(os.path.join(repo2, ".claude", "agents", "pa.md"), "w").close()
        os.makedirs(os.path.join(repo2, "sub"))
        at = lambda event, cwd: {**event, "cwd": cwd}
        sub_dir = os.path.join(repo2, "sub")
        logged("typed project skill", at(slash("/proj"), sub_dir), "skills", "project/proj")
        logged("project skill call", at(tool("Skill", skill="proj"), sub_dir), "skills", "project/proj")
        logged("project agent", at(tool("Agent", subagent_type="pa"), sub_dir), "agents", "project/pa")
        logged("skill call outside the project", at(tool("Skill", skill="proj"), other), "skills", "proj")
        logged("user skill from home is not a project skill", at(tool("Skill", skill="mine"), home), "skills", "mine")
        lines = report("plugins")
        project_row = [r.split() for r in lines if r.endswith("(project skills and agents)")]
        if not project_row or project_row[0][0] != "3" or project_row[0][2:4] != ["1/-", "1/-"]:
            failures.append(f"project row: expected 3 uses, skills 1/-, agents 1/-, got {lines!r}")
        # a symlinked guides folder still matches
        real_guides = os.path.join(home, "pack-guides")
        os.makedirs(os.path.join(real_guides, "tools"))
        open(os.path.join(real_guides, "tools", "x.md"), "w").close()
        linked = os.path.join(home, "linked")
        os.makedirs(linked)
        os.symlink(real_guides, os.path.join(linked, "guides"))
        os.environ["CLAUDE_CONFIG_DIR"] = linked
        real_logs = os.path.join(linked, "usage", "guides.log")
        expect("guide read through a symlink (silent)", U, tool("Read", file_path=os.path.join(linked, "guides", "tools", "x.md")), None)
        if not (os.path.exists(real_logs) and open(real_logs).read().endswith("\ts1\ttools/x.md\n")):
            failures.append("guide read through a symlinked guides folder: not logged as tools/x.md")
finally:
    if old_config is None:
        os.environ.pop("CLAUDE_CONFIG_DIR", None)
    else:
        os.environ["CLAUDE_CONFIG_DIR"] = old_config


if failures:
    print("\n".join(failures))
    sys.exit(1)
print("hooks ok")
PY
