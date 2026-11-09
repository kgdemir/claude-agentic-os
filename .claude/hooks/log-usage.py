#!/usr/bin/env python3
"""Usage log for context housekeeping (ADR-0012).

Registered for PostToolUse on Read|Skill|Agent|Task and for UserPromptSubmit.
Each use appends one line, `local time<TAB>session id<TAB>name`, to a log:

  Read of projects/<p>/memory/<name>.md   -> that memory folder's .access.log
  Read of <config>/guides/<path>.md       -> <config>/usage/guides.log
  Skill call, or a prompt starting "/x"   -> <config>/usage/skills.log
  Agent/Task call (its subagent_type)     -> <config>/usage/agents.log

<config> is $CLAUDE_CONFIG_DIR, else the folder above this script's hooks/.
MEMORY.md is never logged: it loads at session start, not through Read.
Lines are only appended, so sessions running at once never lose a count. The
hook prints nothing and never blocks or fails a call.

  log-usage.py --report memory <memory dir>   topic files, least read first
  log-usage.py --report guides                guide files, least read first
  log-usage.py --report plugins               per plugin: skills and agents used
"""
import glob
import json
import os
import re
import sys
from collections import Counter
from datetime import datetime

MEMORY_LOG = ".access.log"
INDEX_NAME = "MEMORY.md"
MEMORY_DIR = "memory"
PROJECTS_DIR = "projects"
USAGE_DIR = "usage"
GUIDES_DIR = "guides"
DEFAULT_AGENT = "general-purpose"
USER_SKILLS = "(user skills)"
SLASH = re.compile(r"^/([\w:.-]+)")
NAME_LINE = re.compile(r"^name:\s*['\"]?([^'\"\n]+?)['\"]?\s*$", re.M)


def config_dir():
    return os.path.realpath(os.environ.get("CLAUDE_CONFIG_DIR")
                            or os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def append(log, name, session):
    stamp = datetime.now().astimezone().isoformat(timespec="seconds")
    os.makedirs(os.path.dirname(log), exist_ok=True)
    with open(log, "a", encoding="utf-8") as fh:
        fh.write(f"{stamp}\t{session}\t{name}\n")


def usage_log(kind):
    return os.path.join(config_dir(), USAGE_DIR, kind + ".log")


def log_read(path, session):
    path = os.path.realpath(path)
    if not path.endswith(".md"):
        return
    folder, name = os.path.split(path)
    if (os.path.basename(folder) == MEMORY_DIR
            and os.path.basename(os.path.dirname(os.path.dirname(folder))) == PROJECTS_DIR):
        if name != INDEX_NAME:
            append(os.path.join(folder, MEMORY_LOG), name, session)
        return
    guides = os.path.join(config_dir(), GUIDES_DIR) + os.sep
    if path.startswith(guides):
        append(usage_log("guides"), path[len(guides):], session)


def log_event(event):
    tool_input = event.get("tool_input")
    tool_input = tool_input if isinstance(tool_input, dict) else {}
    tool = event.get("tool_name")
    session = str(event.get("session_id", "-")).replace("\t", " ")
    if event.get("hook_event_name") == "UserPromptSubmit":
        match = SLASH.match(str(event.get("prompt", "")).lstrip())
        if match:
            append(usage_log("skills"), match.group(1), session)
    elif tool == "Read" and isinstance(tool_input.get("file_path"), str):
        log_read(tool_input["file_path"], session)
    elif tool == "Skill" and isinstance(tool_input.get("skill"), str):
        append(usage_log("skills"), tool_input["skill"], session)
    elif tool in ("Agent", "Task"):
        append(usage_log("agents"), str(tool_input.get("subagent_type") or DEFAULT_AGENT), session)


def read_log(log):
    """Return (reads per name, last read per name, first stamp or None)."""
    reads, last, first = Counter(), {}, None
    try:
        with open(log, encoding="utf-8") as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 3:
                    first = first or parts[0]
                    reads[parts[2]] += 1
                    last[parts[2]] = parts[0]
    except FileNotFoundError:
        print(f"no {log} yet; every entry below has 0 uses")
    return reads, last, first


def print_rows(names, log):
    reads, last, first = read_log(log)
    if first:
        print(f"logged since {first}")
    print(f"{'uses':>5}  {'last use':<25}  name")
    for name in sorted(names, key=lambda n: (reads[n], last.get(n, ""), n)):
        print(f"{reads[name]:>5}  {last.get(name, 'never'):<25}  {name}")


def declared_name(path, fallback):
    try:
        with open(path, encoding="utf-8") as fh:
            head = fh.read(2000)
    except OSError:
        return fallback
    match = NAME_LINE.search(head)
    return match.group(1).strip() if match else fallback


def plugin_inventory():
    """Return {plugin: (skill and command names, agent names)}."""
    found = {}
    config = config_dir()
    try:
        with open(os.path.join(config, "plugins", "installed_plugins.json"), encoding="utf-8") as fh:
            installed = json.load(fh)
    except FileNotFoundError:
        installed = {}
    for key, entries in (installed.get("plugins", installed) or {}).items():
        if not isinstance(entries, list) or not entries:
            continue
        root, plugin = entries[0].get("installPath", ""), key.split("@")[0]
        skills = {plugin + ":" + declared_name(p, os.path.basename(os.path.dirname(p)))
                  for p in glob.glob(os.path.join(root, "skills", "*", "SKILL.md"))}
        skills |= {plugin + ":" + os.path.basename(p)[:-3]
                   for p in glob.glob(os.path.join(root, "commands", "*.md"))}
        agents = {plugin + ":" + declared_name(p, os.path.basename(p)[:-3])
                  for p in glob.glob(os.path.join(root, "agents", "*.md"))}
        found[plugin] = (skills, agents)
    found[USER_SKILLS] = ({os.path.basename(os.path.dirname(p))
                           for p in glob.glob(os.path.join(config, "skills", "*", "SKILL.md"))}, set())
    return found


def report_plugins():
    skill_uses, skill_last, first = read_log(usage_log("skills"))
    agent_uses, agent_last, _ = read_log(usage_log("agents"))
    if first:
        print(f"logged since {first}")
    rows = []
    for plugin, (skills, agents) in plugin_inventory().items():
        uses = sum(skill_uses[s] for s in skills) + sum(agent_uses[a] for a in agents)
        last = max([skill_last.get(s, "") for s in skills] + [agent_last.get(a, "") for a in agents] + [""])
        used_s = sum(1 for s in skills if skill_uses[s])
        used_a = sum(1 for a in agents if agent_uses[a])
        rows.append((uses, last, plugin, f"{used_s}/{len(skills)}", f"{used_a}/{len(agents)}"))
    print(f"{'uses':>5}  {'last use':<25}  {'skills':>8}  {'agents':>7}  plugin")
    for uses, last, plugin, skills, agents in sorted(rows):
        print(f"{uses:>5}  {last or 'never':<25}  {skills:>8}  {agents:>7}  {plugin}")


def main():
    args = sys.argv[1:]
    if args[:2] == ["--report", "memory"] and len(args) == 3:
        names = [n for n in os.listdir(args[2]) if n.endswith(".md") and n != INDEX_NAME]
        print_rows(names, os.path.join(args[2], MEMORY_LOG))
    elif args == ["--report", "guides"]:
        root = os.path.join(config_dir(), GUIDES_DIR)
        names = [os.path.relpath(p, root) for p in glob.glob(os.path.join(root, "**", "*.md"), recursive=True)]
        print_rows(names, usage_log("guides"))
    elif args == ["--report", "plugins"]:
        report_plugins()
    elif args:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    else:
        try:
            event = json.load(sys.stdin)
            if isinstance(event, dict):
                log_event(event)
        except Exception as exc:  # a logging hook must never break the session
            print(f"log-usage: {exc!r}", file=sys.stderr)


if __name__ == "__main__":
    main()
