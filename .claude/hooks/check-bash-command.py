#!/usr/bin/env python3
"""PreToolUse hook for the Bash tool: remind the model when a shell command
breaks one of the core rules that a command line can show.

Checks (see guides/core/agent-working-rules.md):
- git safety (§6, §9): `git add -A` / `git add .`, `git push --force` without
  `--force-with-lease`, `git reset --hard`, `git clean -f`.
- AI attribution (global CLAUDE.md): a commit, tag, PR, issue or release text
  carrying a `Co-Authored-By:` trailer or a "Generated with Claude" line.
- gate pipes (§1): a build, test or lint command piped into another command
  without `set -o pipefail`, so `$?` belongs to the last command.
- secrets (§9): on `git commit`, added lines in the staged diff that look like
  keys, tokens, private keys or passwords. Only the file and the kind of
  secret are reported, never the value.

Warn-only: the command always runs. Any unexpected input is let through
silently, so the hook can never break a session.
"""
import json
import re
import shlex
import subprocess
import sys

GIT_TIMEOUT_SECONDS = 5

# Splits a command line into the simple commands joined by && || ; | or newline.
SEGMENT_SPLIT = re.compile(r"&&|\|\||;|\n|(?<!\|)\|(?!\|)")
PIPE_SPLIT = re.compile(r"(?<!\|)\|(?!\|)")
CHAIN_SPLIT = re.compile(r"&&|\|\||;|\n")

# git options that take a value and come before the subcommand.
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}

ATTRIBUTION = re.compile(
    r"co-authored-by:|generated with \[?claude|noreply@anthropic\.com", re.IGNORECASE
)
TEXT_COMMANDS = re.compile(r"\bgit\s+(commit|tag|notes)\b|\bgh\s+(pr|issue|release)\b")

# A gate is recognised only as the command a pipe stage runs, never as an
# argument (`grep x tools/check.sh | head` runs grep, not the gate).
GATE = re.compile(
    r"(?:(?:bash|sh)\s+|npx\s+|python3?\s+-m\s+)?"
    r"(?:(npm|pnpm|yarn|bun)\s+(run\s+)?(test|lint|build|typecheck)\b"
    r"|dotnet\s+(build|test|publish)\b"
    r"|(pytest|tsc|eslint|vitest|jest|ruff|mypy)\b"
    r"|(cargo|go)\s+(build|test)\b"
    r"|(\S*/)?tools/[\w.-]+\.sh\b)"
)
# A heredoc body is data, not commands: `|` and `git add .` inside it run nothing.
HEREDOC = re.compile(r"(<<-?[ \t]*(['\"]?)(\w+)\2[^\n]*\n)(?:.*?\n)?[ \t]*\3[ \t]*(?=\n|$)", re.DOTALL)

# Leading `VAR=value` assignments and wrappers before the command word.
COMMAND_PREFIX = re.compile(r"^\s*(?:(?:\w+=\S*|sudo|time|env|command|exec)\s+)*")

SECRETS = (
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("GitHub token", re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,})")),
    ("Slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}")),
    ("Anthropic or OpenAI key", re.compile(r"\bsk-(ant-|proj-)?[A-Za-z0-9_-]{32,}")),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("password in a connection string",
     re.compile(r"\b(password|pwd)\s*=\s*[^;'\"\s<>{}$%]{4,}", re.IGNORECASE)),
    ("secret value in JSON/YAML",
     re.compile(r"[\"']?(password|secret|api_?key|access_?token)[\"']?\s*[:=]\s*[\"'][^\"'<>{}$%]{6,}[\"']",
                re.IGNORECASE)),
)


def tokens(segment: str) -> list:
    try:
        return shlex.split(segment, comments=False)
    except ValueError:
        return segment.split()


def git_call(segment: str):
    """Return (subcommand, args) when the segment runs git, else None."""
    words = tokens(segment)
    # Skip env assignments and wrappers such as `sudo`, `command`, `time`.
    while words and ("=" in words[0] and not words[0].startswith("-") or words[0] in {"sudo", "command", "time", "env"}):
        words = words[1:]
    if not words or words[0].rsplit("/", 1)[-1] != "git":
        return None
    rest = words[1:]
    while rest and rest[0].startswith("-"):
        rest = rest[2:] if rest[0] in GIT_OPTIONS_WITH_VALUE else rest[1:]
    if not rest:
        return None
    return rest[0], rest[1:]


def git_safety(command: str) -> list:
    found = []
    for segment in SEGMENT_SPLIT.split(command):
        call = git_call(segment)
        if not call:
            continue
        sub, args = call
        if sub == "add" and any(a in {"-A", "--all", ".", ":/"} for a in args):
            found.append("`git add -A` / `git add .` stages everything; stage named paths (§6)")
        elif sub == "push" and (
            any(a in {"--force", "-f"} or (a.startswith("-") and not a.startswith("--") and "f" in a) for a in args)
            or any(a.startswith("+") for a in args)
        ) and not any(a.startswith("--force-with-lease") for a in args):
            found.append("plain force push; use `--force-with-lease` and confirm with the user first (§9)")
        elif sub == "reset" and "--hard" in args:
            found.append("`git reset --hard` discards work; look at `git status` and confirm with the user first (§9)")
        elif sub == "clean" and any(a.startswith("-") and not a.startswith("--") and "f" in a or a == "--force" for a in args):
            found.append("`git clean -f` deletes untracked files; run `git clean -n` and confirm with the user first (§9)")
    return found


def attribution(command: str) -> list:
    if TEXT_COMMANDS.search(command) and ATTRIBUTION.search(command):
        return ["AI attribution in a commit/PR/issue text (Co-Authored-By or 'Generated with Claude'); "
                "remove it, the global rules forbid it everywhere"]
    return []


def gate_pipe(command: str) -> list:
    if "pipefail" in command:
        return []
    for chain in CHAIN_SPLIT.split(command):
        stages = PIPE_SPLIT.split(chain)
        if len(stages) > 1 and any(GATE.match(COMMAND_PREFIX.sub("", stage, count=1)) for stage in stages[:-1]):
            return ["a build/test/lint command is piped without `set -o pipefail`, so the exit code "
                    "is the last command's; add `set -o pipefail` or run the gate unpiped (§1)"]
    return []


def commits(command: str) -> list:
    """Return the argument lists of every `git commit` in the command."""
    calls = (git_call(segment) for segment in SEGMENT_SPLIT.split(command))
    return [args for call in calls if call and call[0] == "commit" for args in [call[1]]]


def staged_secrets(command: str, cwd: str) -> list:
    commit_args = commits(command)
    if not commit_args:
        return []
    diffs = [["git", "diff", "--cached", "-U0", "--no-color"]]
    if any(a == "--all" or (a.startswith("-") and not a.startswith("--") and "a" in a) for args in commit_args for a in args):
        diffs.append(["git", "diff", "-U0", "--no-color"])
    hits = set()
    for diff in diffs:
        try:
            out = subprocess.run(diff, cwd=cwd or None, capture_output=True, text=True,
                                 timeout=GIT_TIMEOUT_SECONDS, check=False).stdout
        except (OSError, subprocess.SubprocessError) as exc:
            print(f"check-bash-command: secret scan skipped: {exc}", file=sys.stderr)
            return []
        current = "?"
        for line in out.splitlines():
            if line.startswith("+++ "):
                current = line[6:] if line.startswith("+++ b/") else line[4:]
            elif line.startswith("+"):
                for name, pattern in SECRETS:
                    if pattern.search(line):
                        hits.add(f"{current}: {name}")
    if not hits:
        return []
    return ["staged changes look like secrets (" + "; ".join(sorted(hits)) + "); read `git diff --cached`, "
            "move real values to the secret store and rotate any that were real (§9)"]


def warnings(event: object) -> list:
    if not isinstance(event, dict) or event.get("tool_name") != "Bash":
        return []
    tool_input = event.get("tool_input")
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    if not isinstance(command, str):
        return []
    cwd = event.get("cwd") if isinstance(event.get("cwd"), str) else ""
    # Attribution reads the full text: a commit message often arrives as a heredoc.
    code = HEREDOC.sub(lambda m: m.group(1), command)
    return git_safety(code) + attribution(command) + gate_pipe(code) + staged_secrets(code, cwd)


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return 0
    try:
        found = warnings(event)
    except Exception as exc:  # a broken check must never block or break a session
        print(f"check-bash-command: check failed, command let through: {exc!r}", file=sys.stderr)
        return 0
    if not found:
        return 0
    reminder = ("This command runs anyway (warn-only hook), but it breaks a core rule: " +
                " | ".join(found) + ". Undo or fix it now if it should not have run.")
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": reminder}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
