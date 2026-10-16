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
import os
import re
import shlex
import subprocess
import sys

GIT_TIMEOUT_SECONDS = 5
MESSAGE_FILE_MAX_BYTES = 64 * 1024

# Splits a command line into the simple commands joined by && || ; | or newline.
SEGMENT_SPLIT = re.compile(r"&&|\|\||;|\n|(?<!\|)\|(?!\|)")
PIPE_SPLIT = re.compile(r"(?<!\|)\|(?!\|)")
CHAIN_SPLIT = re.compile(r"&&|\|\||;|\n")

# git options that take a value and come before the subcommand.
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}

ATTRIBUTION = re.compile(
    r"co-authored-by:|generated with \[?claude|noreply@anthropic\.com", re.IGNORECASE
)
# Only used when the command line cannot be tokenised (unbalanced quotes).
TEXT_COMMANDS = re.compile(r"\bgit\s+(commit|tag|notes)\b|\bgh\s+(pr|issue|release)\b")
GIT_TEXT_SUBCOMMANDS = {"commit", "tag", "notes"}
GH_TEXT_SUBCOMMANDS = {"pr", "issue", "release"}
# Options naming a file that holds the message, body or notes (`-` means stdin).
MESSAGE_FILE_OPTIONS = {"-F", "--file", "--body-file", "--notes-file"}
# Short options that take a value, so a bundle stops there (`-mF` is message "F").
SHORT_OPTIONS_WITH_VALUE = set("mCct")
# A backslash at the end of a line continues the command on the next one.
LINE_CONTINUATION = re.compile(r"\\\r?\n")
COMMAND_WRAPPERS = {"sudo", "command", "time", "env", "exec"}
# Escapes inside bash `$'...'` that the checks need decoded; any other `\x` is x.
ANSI_C_ESCAPES = {"n": "\n", "t": "\t", "r": "\r"}
# Commands whose output file holds the text of the files they read.
COPY_COMMANDS = {"cat", "cp"}
CD_OPTIONS = {"-L", "-P", "-e", "-@", "--"}

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
# Each body is cut out and its `<<EOF` replaced by a marker, so a check can
# still tell which command the body feeds.
HEREDOC = re.compile(r"<<-?[ \t]*(['\"]?)(\w+)\1([^\n]*\n)(.*?\n)?[ \t]*\2[ \t]*(?=\n|$)", re.DOTALL)
HEREDOC_MARKER = "__HEREDOC_{}__"
HEREDOC_MARKER_FIND = re.compile(r"__HEREDOC_(\d+)__")

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


def split_heredocs(command: str):
    """Return the command with heredoc bodies replaced by markers, and the bodies."""
    bodies = []

    def cut(match):
        bodies.append(match.group(4) or "")
        return HEREDOC_MARKER.format(len(bodies) - 1) + match.group(3)

    return HEREDOC.sub(cut, command), bodies


def ansi_c_quotes(code: str) -> str:
    """Rewrite each bash `$'...'` word as a plain single-quoted one, which shlex
    reads; left as is, its `\'` looks like unbalanced quotes."""
    out, i, quote = [], 0, None
    while i < len(code):
        ch = code[i]
        if quote:
            out.append(ch)
            if ch == "\\" and quote == '"' and i + 1 < len(code):
                out.append(code[i + 1])
                i += 1
            elif ch == quote:
                quote = None
        elif ch == "\\" and i + 1 < len(code):
            out.append(code[i:i + 2])
            i += 1
        elif code.startswith("$'", i):
            text, i = [], i + 2
            while i < len(code) and code[i] != "'":
                if code[i] == "\\" and i + 1 < len(code):
                    i += 1
                    text.append(ANSI_C_ESCAPES.get(code[i], code[i]))
                else:
                    text.append(code[i])
                i += 1
            out.append(shlex.quote("".join(text)))
        elif ch in "'\"":
            quote = ch
            out.append(ch)
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def strip_prefix(words: list) -> list:
    """Drop leading env assignments and wrappers such as `sudo`, `env`, `time`."""
    while words and ("=" in words[0] and not words[0].startswith("-") or words[0] in COMMAND_WRAPPERS):
        words = words[1:]
    return words


def git_words(words: list):
    """Return (subcommand, args) when the words run git, else None."""
    words = strip_prefix(words)
    if not words or words[0].rsplit("/", 1)[-1] != "git":
        return None
    rest = words[1:]
    while rest and rest[0].startswith("-"):
        rest = rest[2:] if rest[0] in GIT_OPTIONS_WITH_VALUE else rest[1:]
    if not rest:
        return None
    return rest[0], rest[1:]


def git_base(stage: list, cwd: str) -> str:
    """The folder git works in: cwd, moved by each `git -C <dir>`."""
    words = strip_prefix(stage)
    base = cwd or os.getcwd()
    rest = words[1:]
    while rest and rest[0].startswith("-"):
        if rest[0] == "-C" and len(rest) > 1:
            base = os.path.join(base, rest[1])
        rest = rest[2:] if rest[0] in GIT_OPTIONS_WITH_VALUE else rest[1:]
    return base


def pipelines(code: str):
    """Split a command line into pipelines, each a list of stages (word lists).
    Return None when it cannot be tokenised."""
    lexer = shlex.shlex(code, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        words = list(lexer)
    except ValueError:
        return None
    result, stages, stage = [], [], []
    for word in words:
        if word in {"|", "|&"}:
            stages.append(stage)
            stage = []
        elif word and set(word) <= set("&;\n()|"):
            stages.append(stage)
            result.append([s for s in stages if s])
            stages, stage = [], []
        else:
            stage.append(word)
    stages.append(stage)
    result.append([s for s in stages if s])
    return [p for p in result if p]


def after_cd(pipeline: list, folder: str) -> str:
    """The folder the next command runs in. Only a `cd` that is a pipeline on
    its own moves it: one inside a pipe runs in a subshell. `cd -` and a
    folder named through a variable cannot be followed and leave it as is."""
    words = strip_prefix(pipeline[0]) if len(pipeline) == 1 else []
    if not words or words[0] != "cd":
        return folder
    args = [w for w in words[1:] if w not in CD_OPTIONS]
    target = args[0] if args else "~"
    if target == "-" or "$" in target:
        return folder
    return os.path.normpath(os.path.join(folder, os.path.expanduser(target)))


def simple_commands(code: str, cwd: str = "") -> list:
    """Every simple command's words, with the folder it runs in (cwd, moved by
    each `cd`). Quote-aware when the line parses, so a message line inside
    quotes is not a command; split by regex, without folders, otherwise."""
    folder = cwd or os.getcwd()
    parsed = pipelines(code)
    if parsed is None:
        return [(tokens(segment), folder) for segment in SEGMENT_SPLIT.split(code)]
    result = []
    for pipeline in parsed:
        result.extend((stage, folder) for stage in pipeline)
        folder = after_cd(pipeline, folder)
    return result


def is_text_command(stage: list) -> bool:
    """True when the stage runs a command whose text lands in the repository or on GitHub."""
    call = git_words(stage)
    if call:
        return call[0] in GIT_TEXT_SUBCOMMANDS
    words = strip_prefix(stage)
    return (len(words) > 1 and words[0].rsplit("/", 1)[-1] == "gh"
            and words[1] in GH_TEXT_SUBCOMMANDS)


def message_files(stage: list) -> list:
    """File names given to -F/--file/--body-file, `-` (stdin) left out."""
    names = []
    for i, word in enumerate(stage):
        following = stage[i + 1] if i + 1 < len(stage) else None
        if word in MESSAGE_FILE_OPTIONS:
            if following is not None:
                names.append(following)
        elif word.startswith(("--file=", "--body-file=", "--notes-file=")):
            names.append(word.split("=", 1)[1])
        elif word.startswith("-") and not word.startswith("--"):
            # A bundle of short options: `-aF msg`, `-aFmsg`.
            for j, flag in enumerate(word[1:], 1):
                if flag == "F":
                    value = word[j + 1:] or following
                    if value is not None:
                        names.append(value)
                    break
                if flag in SHORT_OPTIONS_WITH_VALUE:
                    break
    return [n for n in names if n != "-"]


def read_message_file(base: str, name: str) -> str:
    # Only regular files: opening a fifo or a device such as /dev/tty would block
    # the hook. A missing file is normal (the commit is about to fail anyway);
    # there is then nothing to check.
    path = os.path.join(base, name)
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read(MESSAGE_FILE_MAX_BYTES)
    except OSError:
        return ""


def git_safety(command: str) -> list:
    found = []
    for words, _ in simple_commands(command):
        call = git_words(words)
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


def attribution(command: str, code: str, bodies: list, cwd: str) -> list:
    """Warn when a commit, tag, note, PR, issue or release text carries AI
    attribution: in its own arguments, in what is piped into it, in a heredoc
    feeding it, or in the file given to -F/--body-file. The same words
    anywhere else (a test file, a grep) are not a commit text."""
    found = ["AI attribution in a commit/PR/issue text (Co-Authored-By or 'Generated with Claude'); "
             "remove it, the global rules forbid it everywhere"]
    parsed = pipelines(code)
    if parsed is None:
        return found if TEXT_COMMANDS.search(command) and ATTRIBUTION.search(command) else []
    if not any(is_text_command(stage) for pipeline in parsed for stage in pipeline):
        return []  # nothing here carries text, so no file needs reading

    def fed(words: list) -> str:
        return "\n".join(bodies[int(n)] for w in words for n in HEREDOC_MARKER_FIND.findall(w)
                         if int(n) < len(bodies))

    written = {}  # full path -> text of the command (and heredoc) that writes it

    def path(folder: str, name: str) -> str:
        return os.path.normpath(os.path.join(folder, os.path.expanduser(name)))

    def source(folder: str, name: str) -> str:
        full = path(folder, name)
        return written[full] if full in written else read_message_file(folder, name)

    folders, folder = [], cwd or os.getcwd()
    for pipeline in parsed:
        folders.append(folder)
        folder = after_cd(pipeline, folder)

    for pipeline, folder in zip(parsed, folders):
        for stage in pipeline:
            words = strip_prefix(stage)
            name = words[0].rsplit("/", 1)[-1] if words else ""
            redirect = next((i for i, w in enumerate(words) if w in {">", ">>", "<"}), len(words))
            files = [w for w in words[1:redirect] if not w.startswith("-")] if name in COPY_COMMANDS else []
            text = " ".join(stage) + "\n" + fed(stage)
            for i, word in enumerate(words[:-1]):
                if word in {">", ">>"}:
                    written[path(folder, words[i + 1])] = text + "".join("\n" + source(folder, f) for f in files)
            if name == "cp" and len(files) > 1:
                written[path(folder, files[-1])] = "".join("\n" + source(folder, f) for f in files[:-1])
    for pipeline, folder in zip(parsed, folders):
        if not any(is_text_command(stage) for stage in pipeline):
            continue
        words = [w for stage in pipeline for w in stage]
        text = " ".join(words) + "\n" + fed(words)
        for stage in pipeline:
            if is_text_command(stage):
                base = git_base(stage, folder) if git_words(stage) else folder
                for name in message_files(stage):
                    text += "\n" + source(base, name)
        if ATTRIBUTION.search(text):
            return found
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


def commits(command: str, cwd: str) -> list:
    """Return (arguments, folder git works in) for every `git commit` in the command."""
    result = []
    for words, folder in simple_commands(command, cwd):
        call = git_words(words)
        if call and call[0] == "commit":
            result.append((call[1], git_base(words, folder)))
    return result


def staged_secrets(command: str, cwd: str) -> list:
    found_commits = commits(command, cwd)
    if not found_commits:
        return []
    commit_args = [args for args, _ in found_commits]
    bases = sorted({base for _, base in found_commits})
    diffs = [["git", "diff", "--cached", "-U0", "--no-color"]]
    if any(a == "--all" or (a.startswith("-") and not a.startswith("--") and "a" in a) for args in commit_args for a in args):
        diffs.append(["git", "diff", "-U0", "--no-color"])
    hits = set()
    for base in bases:
        if not os.path.isdir(base):
            continue  # no such folder: the commit cannot run there either
        for diff in diffs:
            try:
                out = subprocess.run(diff, cwd=base, capture_output=True, text=True,
                                     timeout=GIT_TIMEOUT_SECONDS, check=False).stdout
            except (OSError, subprocess.SubprocessError) as exc:
                print(f"check-bash-command: secret scan skipped in {base}: {exc}", file=sys.stderr)
                break
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
    code, bodies = split_heredocs(command)
    code = ansi_c_quotes(LINE_CONTINUATION.sub(" ", code))
    return (git_safety(code) + attribution(command, code, bodies, cwd) + gate_pipe(code)
            + staged_secrets(code, cwd))


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
