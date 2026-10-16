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
expect("$ inside single quotes is not $'...'", B, bash("""echo 'cost $' && git commit -m 'fix: tidy'"""), None)

# robustness: never break a session
expect("other tool", B, {"tool_name": "Read", "tool_input": {"file_path": "x"}}, None)
expect("bad input", B, {"tool_name": "Bash", "tool_input": "x"}, None)

# brief hook
A = "check-agent-brief.py"
agent = lambda prompt, kind="general-purpose": {"tool_name": "Agent", "tool_input": {"prompt": prompt, "subagent_type": kind}}
expect("brief missing", A, agent("do the thing"), "`Goal:`")
expect("brief complete", A, agent("Goal: x\nFiles: y\nDone: z"), None)
expect("brief exempt", A, agent("find x", "Explore"), None)

if failures:
    print("\n".join(failures))
    sys.exit(1)
print("hooks ok")
PY
