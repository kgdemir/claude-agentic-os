#!/usr/bin/env python3
"""PreToolUse hook for the Agent tool: remind the model when a subagent brief
cannot be finished in one go, and keep agents inside the plan's usage limits.

A subagent that has to come back with a question sits idle while it waits, and
once it is idle past its prompt cache TTL, waking it re-pays its whole history.
Every brief therefore should carry a `Goal:`, `Files:` and `Done:` line (see
"Background work and delegation" in guides/core/agent-working-rules.md).

A brief missing a line only gets a reminder added to the model's context, so
briefs written by skills and plugins never fail, and the next hand-written brief
improves.

Usage limits: the model cannot see the 5-hour and weekly limits; the statusline
can, and saves them to `usage/limits.json` in the config folder. From
LIMIT_WARN_PERCENT on, the hook adds both numbers and their reset times to the
model's context. From LIMIT_BLOCK_PERCENT on, it blocks the agent: a subagent
spends the same limit, and one that hits it mid-task stops with its work half
done (ADR-0015). A window whose reset time has passed is ignored.
"""
import datetime
import json
import os
import pathlib
import re
import sys
import time

# Tool names the Agent tool has carried across Claude Code versions.
AGENT_TOOLS = {"Agent", "Task"}

# Agent types exempt from the check: read-only lookups whose whole brief is the
# question, and forks, which inherit the full conversation.
EXEMPT_TYPES = {"Explore", "claude-code-guide", "statusline-setup", "fork"}

REQUIRED_FIELDS = ("Goal", "Files", "Done")

LIMITS_FILE = pathlib.Path("usage") / "limits.json"
LIMIT_WINDOWS = {"five_hour": "5-hour", "seven_day": "weekly"}
LIMIT_WARN_PERCENT = 75
LIMIT_BLOCK_PERCENT = 90


def has_field(prompt: str, field: str) -> bool:
    # Accepts `Goal:`, `- Goal:`, `**Goal:**`, `## Goal:` at the start of a line.
    pattern = rf"^[\s#>*-]*\**{field}\**\s*:"
    return re.search(pattern, prompt, re.IGNORECASE | re.MULTILINE) is not None


def is_agent_call(event: object) -> bool:
    return isinstance(event, dict) and event.get("tool_name") in AGENT_TOOLS


def config_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude")


def current_limits(now: float) -> list:
    """(label, used percent, resets at) for each saved window that has not reset yet."""
    path = config_dir() / LIMITS_FILE
    try:
        saved = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return []
    except (OSError, ValueError) as exc:
        print(f"check-agent-brief: {path}: {exc}", file=sys.stderr)
        return []
    found = []
    for key, label in LIMIT_WINDOWS.items():
        window = saved.get(key) if isinstance(saved, dict) else None
        if not isinstance(window, dict):
            continue
        used, resets = window.get("used_percentage"), window.get("resets_at")
        if isinstance(used, (int, float)) and isinstance(resets, (int, float)) and resets > now:
            found.append((label, round(used), resets))
    return found


def describe(limits: list) -> str:
    return "; ".join(
        f"{label} limit {used}% used, resets {datetime.datetime.fromtimestamp(resets).strftime('%a %H:%M')}"
        for label, used, resets in limits)


def missing_fields(event: object) -> list:
    # Any unexpected shape means "not ours to judge": never break a session.
    if not is_agent_call(event):
        return []
    tool_input = event.get("tool_input")
    if not isinstance(tool_input, dict) or tool_input.get("subagent_type") in EXEMPT_TYPES:
        return []
    prompt = tool_input.get("prompt")
    if not isinstance(prompt, str):
        return []
    return [field for field in REQUIRED_FIELDS if not has_field(prompt, field)]


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return 0
    if not is_agent_call(event):
        return 0
    limits = [w for w in current_limits(time.time()) if w[1] >= LIMIT_WARN_PERCENT]
    if any(used >= LIMIT_BLOCK_PERCENT for _, used, _ in limits):
        reason = (
            f"Agent not started: {describe(limits)} (blocked from {LIMIT_BLOCK_PERCENT}%). "
            "A subagent spends the same limit and would stop mid-task when it runs out. "
            "Do the work in this session in small steps, or tell the user and wait for the reset."
        )
        json.dump({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                          "permissionDecision": "deny",
                                          "permissionDecisionReason": reason}}, sys.stdout)
        return 0

    notes = []
    if limits:
        notes.append(
            f"Usage is high: {describe(limits)}. Agents are blocked from {LIMIT_BLOCK_PERCENT}%. "
            "Keep this agent's task small; if one is already running, send it the order to stop "
            "at its next checkpoint and report what is done (a message reaches it at its next tool call)."
        )
    missing = missing_fields(event)
    if missing:
        notes.append(
            "Subagent brief is missing " + ", ".join(f"`{f}:`" for f in missing) + ". "
            "The agent was started anyway; if it comes back with a question, answer it "
            "now rather than letting it idle. Next brief: `Goal:` one sentence, "
            "`Files:` the paths involved plus what is known or ruled out, `Done:` the "
            "output wanted and how it is checked; tell it to pick the safest reading "
            "of anything unclear and say so in its result."
        )
    if not notes:
        return 0
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": " ".join(notes)}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
