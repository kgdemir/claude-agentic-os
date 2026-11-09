#!/usr/bin/env python3
"""Usage log for context housekeeping (ADR-0012).

Registered for PostToolUse on Read|Skill|Agent|Task and for UserPromptSubmit.
Each use appends one line, `unix time<TAB>session id<TAB>name`, to a log
(unix time: whole seconds since 1970, UTC; reports show it in local time):

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
import time
from datetime import datetime

MEMORY_LOG = ".access.log"
INDEX_NAME = "MEMORY.md"
MEMORY_DIR = "memory"
PROJECTS_DIR = "projects"
USAGE_DIR = "usage"
GUIDES_DIR = "guides"
DEFAULT_AGENT = "general-purpose"
USER_SKILLS = "(user skills and agents)"
# "/name" alone, or followed by a space or punctuation; "/home/x" (a path) is not
# a command. A one-segment path typed alone ("/tmp") still matches; the plugin
# report counts only names that belong to a plugin, so it never adds to a count.
SLASH = re.compile(r"^/([\w:.-]*\w)(?=[\s,.;:!?]|$)")
FRONTMATTER = re.compile(r"\A---\r?\n(.*?)\r?\n---", re.S)
FRONTMATTER_BYTES = 8192  # frontmatter sits at the top; skill bodies can be large
NAME_LINE = re.compile(r"^name:\s*['\"]?([^'\"\n]+?)['\"]?\s*$", re.M)
NEVER = -1  # sorts before any logged time


def config_dir():
    return os.path.realpath(os.environ.get("CLAUDE_CONFIG_DIR")
                            or os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def append(log, name, session):
    stamp = int(time.time())
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
    projects = os.path.realpath(os.path.join(config_dir(), PROJECTS_DIR))
    # Only Claude's own memory: <config>/projects/<project>/memory/<name>.md
    if os.path.basename(folder) == MEMORY_DIR and os.path.dirname(os.path.dirname(folder)) == projects:
        if name != INDEX_NAME:
            append(os.path.join(folder, MEMORY_LOG), name, session)
        return
    guides = os.path.realpath(os.path.join(config_dir(), GUIDES_DIR)) + os.sep
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


def parse_time(stamp):
    """A logged time as unix seconds. Also reads the local ISO times of the
    first release. Raises ValueError for an empty, unreadable or impossible one."""
    moment = int(stamp) if stamp.isdigit() else int(datetime.fromisoformat(stamp).timestamp())
    try:
        datetime.fromtimestamp(moment)
    except (OverflowError, OSError) as exc:
        raise ValueError(f"time out of range: {stamp}") from exc
    return moment


def shown(moment):
    """A unix time in local time with its offset, for the reports."""
    return "never" if moment == NEVER else datetime.fromtimestamp(moment).astimezone().isoformat(timespec="seconds")


def read_log(log):
    """Return (uses per name, last use per name, first use or None), in unix seconds."""
    uses, last, first, bad = Counter(), {}, None, 0
    try:
        with open(log, encoding="utf-8") as fh:
            for line in fh:
                parts = line.rstrip("\n").split("\t")
                try:
                    stamp, _, name = parts
                    moment = parse_time(stamp)
                except ValueError:
                    bad += 1
                    continue
                first = moment if first is None else min(first, moment)
                uses[name] += 1
                last[name] = max(last.get(name, NEVER), moment)
    except FileNotFoundError:
        print(f"no {log} yet; every entry below has 0 uses")
    if bad:
        print(f"!! {log}: {bad} line(s) not in time<TAB>session<TAB>name form, skipped", file=sys.stderr)
    return uses, last, first


def print_rows(names, log):
    uses, last, first = read_log(log)
    if first is not None:
        print(f"logged since {shown(first)}")
    print(f"{'uses':>5}  {'last use':<25}  name")
    for name in sorted(names, key=lambda n: (uses[n], last.get(n, NEVER), n)):
        print(f"{uses[name]:>5}  {shown(last.get(name, NEVER)):<25}  {name}")


def declared_name(path, fallback):
    """The frontmatter `name:` of a skill or agent file, else the fallback."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read(FRONTMATTER_BYTES).lstrip("\ufeff")
    except OSError as exc:
        print(f"!! cannot read {path} ({exc}); counted as {fallback}", file=sys.stderr)
        return fallback
    front = FRONTMATTER.match(text)
    match = NAME_LINE.search(front.group(1)) if front else None
    return match.group(1).strip() if match else fallback


def plugin_inventory():
    """Return {plugin: (skill and command names, agent names)}."""
    found = {}
    config = config_dir()
    path = os.path.join(config, "plugins", "installed_plugins.json")
    try:
        with open(path, encoding="utf-8") as fh:
            installed = json.load(fh)
    except FileNotFoundError:
        installed = {}
    except (OSError, ValueError) as exc:
        print(f"!! cannot read {path} ({exc}); plugins left out", file=sys.stderr)
        installed = {}
    plugins = installed.get("plugins", installed) if isinstance(installed, dict) else None
    if not isinstance(plugins, dict):
        print(f"!! {path}: not the expected {{plugin: [installs]}} shape; plugins left out", file=sys.stderr)
        plugins = {}
    for key, entries in plugins.items():
        roots = {e["installPath"] for e in entries if isinstance(e, dict) and isinstance(e.get("installPath"), str)} \
            if isinstance(entries, list) else set()
        plugin = key.split("@")[0]
        skills, agents = set(), set()
        for root in roots:
            skills |= {plugin + ":" + declared_name(p, os.path.basename(os.path.dirname(p)))
                       for p in glob.glob(os.path.join(root, "skills", "*", "SKILL.md"))}
            skills |= {plugin + ":" + os.path.basename(p)[:-3]
                       for p in glob.glob(os.path.join(root, "commands", "*.md"))}
            agents |= {plugin + ":" + declared_name(p, os.path.basename(p)[:-3])
                       for p in glob.glob(os.path.join(root, "agents", "*.md"))}
        if roots:  # one plugin from two marketplaces: one row, both lists
            old_skills, old_agents = found.get(plugin, (set(), set()))
            found[plugin] = (old_skills | skills, old_agents | agents)
    found[USER_SKILLS] = ({os.path.basename(os.path.dirname(p))
                           for p in glob.glob(os.path.join(config, "skills", "*", "SKILL.md"))},
                          {declared_name(p, os.path.basename(p)[:-3])
                           for p in glob.glob(os.path.join(config, "agents", "*.md"))})
    return found


def resolve_bare(uses, last, known, own):
    """Credit a bare name ("caveman", typed as /caveman) to the one plugin item
    whose short name it is. A user skill of that name wins; an ambiguous name
    stays bare and is credited to nobody."""
    by_short = {}
    for name in known:
        by_short.setdefault(name.split(":", 1)[-1], []).append(name)
    for bare in [n for n in uses if ":" not in n and n not in own]:
        matches = by_short.get(bare, [])
        if len(matches) == 1:
            full = matches[0]
            uses[full] += uses.pop(bare)
            last[full] = max(last.get(full, NEVER), last.pop(bare, NEVER))


def report_plugins():
    inventory = plugin_inventory()
    own_skills, own_agents = inventory[USER_SKILLS]
    plugin_skills = {s for p, (sk, _) in inventory.items() if p != USER_SKILLS for s in sk}
    plugin_agents = {a for p, (_, ag) in inventory.items() if p != USER_SKILLS for a in ag}
    skill_uses, skill_last, first = read_log(usage_log("skills"))
    agent_uses, agent_last, _ = read_log(usage_log("agents"))
    resolve_bare(skill_uses, skill_last, plugin_skills, own_skills)
    resolve_bare(agent_uses, agent_last, plugin_agents, own_agents)
    if first is not None:
        print(f"logged since {shown(first)}")
    rows = []
    for plugin, (skills, agents) in inventory.items():
        uses = sum(skill_uses[s] for s in skills) + sum(agent_uses[a] for a in agents)
        last = max([skill_last.get(s, NEVER) for s in skills] + [agent_last.get(a, NEVER) for a in agents],
                   default=NEVER)
        used_s = sum(1 for s in skills if skill_uses[s])
        used_a = sum(1 for a in agents if agent_uses[a])
        rows.append((uses, last, plugin, f"{used_s}/{len(skills)}", f"{used_a}/{len(agents)}"))
    print(f"{'uses':>5}  {'last use':<25}  {'skills':>8}  {'agents':>7}  plugin")
    for uses, last, plugin, skills, agents in sorted(rows):
        print(f"{uses:>5}  {shown(last):<25}  {skills:>8}  {agents:>7}  {plugin}")


def main():
    args = sys.argv[1:]
    if args[:2] == ["--report", "memory"] and len(args) == 3:
        names = [n for n in os.listdir(args[2]) if n.endswith(".md") and n != INDEX_NAME]
        print_rows(names, os.path.join(args[2], MEMORY_LOG))
    elif args == ["--report", "guides"]:
        root = os.path.realpath(os.path.join(config_dir(), GUIDES_DIR))
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
