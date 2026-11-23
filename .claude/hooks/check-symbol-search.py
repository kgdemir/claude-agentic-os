#!/usr/bin/env python3
"""PreToolUse hook for Bash and Grep: remind the model to use the `LSP` tool when a
text search looks for a code symbol that a running language server could resolve.

grep matches text: it also hits comments and strings, and misses aliased imports,
overloads and calls through an interface. A rule saying so is skipped in the
middle of many valid text searches (ADR-0016), so the reminder comes at the call.

It speaks only when all of these hold (ADR-0016):
- the call is a text search: `grep`, `egrep`, `fgrep`, `rg` or `git grep` in a
  Bash command, or the `Grep` tool;
- the pattern is one identifier (optionally inside `\\b`, `\\<`, `\\>`), not a
  phrase, a CSS class, a kebab-case name or a path;
- the search is scoped to files of a language whose server is enabled and can
  start, or it has no scope and the git repository holds such files;
- that server can start, by the same check as check-lsp-servers.py (ADR-0013).

Warn-only and silent otherwise. Any unexpected input lets the call through.
"""
import importlib.util
import json
import pathlib
import re
import shlex
import subprocess
import sys

GREP_PROGRAMS = {"grep", "egrep", "fgrep"}
SEARCH_PROGRAMS = GREP_PROGRAMS | {"rg"}
RECURSIVE_OPTIONS = {"--recursive", "--dereference-recursive"}
# Shell operator characters. A run of them is one word: it ends a simple command
# (`|`, `&&`, `;`, a new line), or redirects (`>`, `2>&1`, `<<`) and is
# followed by its target, which is not a search argument.
OPERATOR_CHARS = "();<>|&\n"
REDIRECT_CHARS = "<>"
IDENTIFIER = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*")
# Shorter names are mostly keywords or loop variables, and noise as a reminder.
MIN_IDENTIFIER_LENGTH = 3
WORD_EDGES = ("\\b", "\\<", "\\>")

# Options whose value is the next word (grep, rg and git grep), and those only
# rg gives a value (`grep -T` is --initial-tab, `grep -r` is --recursive).
RG_VALUE_OPTIONS = {"-T", "-r", "--replace"}
VALUE_OPTIONS = {"-e", "-f", "-m", "-A", "-B", "-C", "-t", "-g", "-d", "-D", "-j",
                 "--regexp", "--file", "--max-count", "--context", "--before-context",
                 "--after-context", "--type", "--type-not", "--glob", "--iglob", "--include",
                 "--exclude", "--exclude-dir", "--max-depth", "--threads"}
PATTERN_OPTIONS = {"-e", "--regexp"}
GLOB_OPTIONS = {"-g", "--glob", "--iglob", "--include"}
TYPE_OPTIONS = {"-t", "--type"}

# ripgrep type names (also the Grep tool's `type`) for the languages with an
# official LSP plugin, and the extensions each one covers.
RG_TYPES = {
    "ts": {".ts", ".tsx", ".mts", ".cts"}, "typescript": {".ts", ".tsx", ".mts", ".cts"},
    "js": {".js", ".jsx", ".mjs", ".cjs"}, "cs": {".cs"}, "csharp": {".cs"},
    "py": {".py", ".pyi"}, "go": {".go"}, "rust": {".rs"}, "java": {".java"},
    "kotlin": {".kt", ".kts"}, "lua": {".lua"}, "php": {".php"}, "ruby": {".rb"},
    "swift": {".swift"}, "c": {".c", ".h"}, "cpp": {".cpp", ".cc", ".cxx", ".hpp", ".hxx", ".h"},
}
GLOB_EXTENSION = re.compile(r"\.(\{[^}]*\}|[A-Za-z0-9]+)$")
GIT_TIMEOUT_SECONDS = 2
LSP_HOOK = pathlib.Path(__file__).with_name("check-lsp-servers.py")
GUIDE = "~/.claude/guides/core/lsp.md"


def symbol(pattern: str) -> str:
    """The identifier a search pattern looks for, or '' when it is not one."""
    for edge in WORD_EDGES:
        if pattern.startswith(edge):
            pattern = pattern[len(edge):]
        if pattern.endswith(edge):
            pattern = pattern[:-len(edge)]
    if IDENTIFIER.fullmatch(pattern) and len(pattern) >= MIN_IDENTIFIER_LENGTH:
        return pattern
    return ""


def glob_extensions(glob: str) -> set:
    match = GLOB_EXTENSION.search(glob)
    if not match:
        return set()
    part = match.group(1)
    names = part[1:-1].split(",") if part.startswith("{") else [part]
    return {"." + name.strip() for name in names if name.strip()}


def path_extension(path: str) -> set:
    suffix = pathlib.PurePath(path).suffix
    return {suffix} if suffix else set()


def simple_commands(command: str) -> list:
    """(words, reads a pipe) for each simple command in a shell line; [] when it
    cannot be split."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=OPERATOR_CHARS)
    lexer.whitespace = " \t\r"  # a new line ends a command, so it is an operator here
    lexer.whitespace_split = True
    try:
        words = list(lexer)
    except ValueError:
        return []
    commands, current, piped, redirect_target = [], [], False, False
    for word in words:
        operator = set(word) <= set(OPERATOR_CHARS)
        if redirect_target and not operator:
            redirect_target = False
        elif operator and any(ch in word for ch in REDIRECT_CHARS):
            if current and current[-1].isdigit():  # the 2 of 2>/dev/null
                current.pop()
            redirect_target = True
        elif operator:
            if current:
                commands.append((current, piped))
            current, piped, redirect_target = [], "|" in word and "||" not in word, False
        else:
            current.append(word)
    if current:
        commands.append((current, piped))
    return commands


def search_args(words: list):
    """(program, arguments after it), or None when this is not a text search."""
    while words and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", words[0]):
        words = words[1:]
    if not words:
        return None
    program = pathlib.PurePath(words[0]).name
    if program in SEARCH_PROGRAMS:
        return program, words[1:]
    if program == "git" and "grep" in words[1:4]:
        return "git grep", words[words.index("grep") + 1:]
    return None


def recursive(args: list) -> bool:
    return any(a in RECURSIVE_OPTIONS or re.fullmatch(r"-[A-Za-z]*[rR][A-Za-z]*", a) for a in args)


def parse_search(program: str, args: list):
    """(patterns, scope extensions or None for no scope, folders searched, whether
    any file or folder was named)."""
    patterns, extensions, folders, positional = [], set(), [], []
    value_options = VALUE_OPTIONS | (RG_VALUE_OPTIONS if program == "rg" else set())
    scoped = False
    i = 0
    while i < len(args):
        word = args[i]
        name, has_value, value = word.partition("=")
        if word == "--":
            positional += args[i + 1:]
            break
        if word.startswith("--") and has_value:
            option = name
        elif word in value_options and i + 1 < len(args):
            option, value = word, args[i + 1]
            i += 1
        else:
            option = ""
        if option:
            if option in PATTERN_OPTIONS:
                patterns.append(value)
            elif option in GLOB_OPTIONS:
                scoped = True
                extensions |= glob_extensions(value)
            elif option in TYPE_OPTIONS:
                scoped = True
                extensions |= RG_TYPES.get(value, set())
        elif not word.startswith("-") or word == "-":
            positional.append(word)
        i += 1
    if not patterns and positional:
        patterns.append(positional.pop(0))
    for path in positional:
        found = path_extension(path)
        if found:
            scoped = True
            extensions |= found
        elif not any(ch in path for ch in "*?["):
            folders.append(path)
        else:
            scoped = True
            extensions |= glob_extensions(path)
    return patterns, (extensions if scoped else None), folders, bool(positional)


def searches(event: dict) -> list:
    """(patterns, scope extensions or None, folders) for each text search in the call."""
    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict):
        return []
    if event.get("tool_name") == "Grep":
        pattern = tool_input.get("pattern")
        if not isinstance(pattern, str):
            return []
        extensions, scoped = set(), False
        if isinstance(tool_input.get("glob"), str):
            scoped = True
            extensions |= glob_extensions(tool_input["glob"])
        if isinstance(tool_input.get("type"), str):
            scoped = True
            extensions |= RG_TYPES.get(tool_input["type"], set())
        path = tool_input.get("path")
        folders = []
        if isinstance(path, str) and path_extension(path):
            scoped = True
            extensions |= path_extension(path)
        elif isinstance(path, str):
            folders.append(path)
        return [([pattern], extensions if scoped else None, folders)]
    if event.get("tool_name") == "Bash":
        command = tool_input.get("command")
        if not isinstance(command, str) or not re.search(r"\b(grep|rg)\b", command):
            return []
        found = []
        for words, piped in simple_commands(command):
            search = search_args(words)
            if search is None:
                continue
            program, args = search
            patterns, extensions, folders, named = parse_search(program, args)
            # With no file named, grep (unless recursive) and a piped search read
            # their input, not the code: `ps aux | grep python`.
            if not named and (piped or (program in GREP_PROGRAMS and not recursive(args))):
                continue
            found.append((patterns, extensions, folders))
        return found
    return []


def repository_has(folder: str, extensions: set) -> bool:
    """True when the git repository at folder tracks a file with one of the extensions."""
    try:
        listed = subprocess.run(["git", "-C", folder, "ls-files", "-z"], capture_output=True,
                                text=True, timeout=GIT_TIMEOUT_SECONDS, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return False
    if listed.returncode != 0:
        return False
    return any(pathlib.PurePath(name).suffix in extensions for name in listed.stdout.split("\0") if name)


def running_servers(workspace: str) -> dict:
    """{extension: server command} for every enabled language server that can start."""
    sys.dont_write_bytecode = True  # no __pycache__ beside the installed hooks
    spec = importlib.util.spec_from_file_location("check_lsp_servers", LSP_HOOK)
    lsp = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(lsp)
    served = {}
    for _, command, extensions, problem, _ in lsp.server_states(lsp.config_dir(), workspace):
        if problem is None:
            for extension in extensions:
                served.setdefault(extension, command)
    return served


def reminder(event: object) -> str:
    if not isinstance(event, dict):
        return ""
    found = searches(event)
    candidates = [(name, extensions, folders) for patterns, extensions, folders in found
                  for name in map(symbol, patterns) if name]
    if not candidates:
        return ""
    cwd = event.get("cwd") if isinstance(event.get("cwd"), str) else ""
    served = running_servers(cwd)
    if not served:
        return ""
    for name, extensions, folders in candidates:
        if extensions is None:
            places = [str(pathlib.Path(cwd) / f) for f in folders] or [cwd]
            hit = any(p and repository_has(p, set(served)) for p in places)
        else:
            hit = bool(extensions & set(served))
        if hit:
            return (f"`{name}` looks like a code symbol, and a language server is running for these "
                    "files. Use the `LSP` tool (`workspaceSymbol`, then `findReferences` or "
                    "`goToDefinition`); grep only matches text, so it hits comments and strings and "
                    "misses aliased imports and calls through an interface. Uses in files the server "
                    "does not read (Razor `.cshtml`/`.razor` views, HTML templates) still need grep on "
                    "those files. If this is a text search "
                    f"on purpose (a log line, a config key), go on and say so ({GUIDE}).")
    return ""


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except ValueError as exc:
        print(f"check-symbol-search: unreadable event: {exc}", file=sys.stderr)
        return 0
    try:
        note = reminder(event)
    except Exception as exc:  # a broken hook must never stop a search (ADR-0016)
        print(f"check-symbol-search: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 0
    if note:
        json.dump({"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": note}},
                  sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
