#!/usr/bin/env python3
"""PreToolUse hook for the Agent tool: remind the model when a subagent brief
cannot be finished in one go.

A subagent that has to come back with a question sits idle while it waits, and
once it is idle past its prompt cache TTL, waking it re-pays its whole history.
Every brief therefore should carry a `Goal:`, `Files:` and `Done:` line (see
"Background work and delegation" in guides/agent-working-rules.md).

Warn-only: the call always goes through. A brief missing a line gets a reminder
added to the model's context, so briefs written by skills and plugins never
fail, and the next hand-written brief improves.
"""
import json
import re
import sys

# Tool names the Agent tool has carried across Claude Code versions.
AGENT_TOOLS = {"Agent", "Task"}

# Agent types exempt from the check: read-only lookups whose whole brief is the
# question, and forks, which inherit the full conversation.
EXEMPT_TYPES = {"Explore", "claude-code-guide", "statusline-setup", "fork"}

REQUIRED_FIELDS = ("Goal", "Files", "Done")


def has_field(prompt: str, field: str) -> bool:
    # Accepts `Goal:`, `- Goal:`, `**Goal:**`, `## Goal:` at the start of a line.
    pattern = rf"^[\s#>*-]*\**{field}\**\s*:"
    return re.search(pattern, prompt, re.IGNORECASE | re.MULTILINE) is not None


def missing_fields(event: object) -> list:
    # Any unexpected shape means "not ours to judge": never break a session.
    if not isinstance(event, dict) or event.get("tool_name") not in AGENT_TOOLS:
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
    missing = missing_fields(event)
    if not missing:
        return 0

    reminder = (
        "Subagent brief is missing " + ", ".join(f"`{f}:`" for f in missing) + ". "
        "The agent was started anyway; if it comes back with a question, answer it "
        "now rather than letting it idle. Next brief: `Goal:` one sentence, "
        "`Files:` the paths involved plus what is known or ruled out, `Done:` the "
        "output wanted and how it is checked; tell it to pick the safest reading "
        "of anything unclear and say so in its result."
    )
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": reminder}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
