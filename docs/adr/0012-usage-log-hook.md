# ADR-0012: A usage-log hook for context housekeeping

**Date**: 2026-11-09
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

Some text is paid for in every session whether it is used or not. Claude Code
loads only the first 200 lines or 25KB of `MEMORY.md`; one project index reached
25KB and lost its last 4 entries. Every enabled plugin lists its skills and
agents in every session; `ecc` alone brings 293 skills, 94 commands and 68
agents. The add-on trigger table in `CLAUDE.md` loads every session too.

The rules in `agent-working-rules.md` §8 (group rarely read memories) and
`tools/skills.md` (prune plugins and guides) need to know what is rarely used.
Without data, that is a guess.

Introduced in commit `2deb277`.

## Decision

- `.claude/hooks/log-usage.py` runs as a `PostToolUse` hook on
  `Read|Skill|Agent|Task` and as a `UserPromptSubmit` hook. It appends
  `local time<TAB>session id<TAB>name` to one log per kind:
  - a `Read` of a topic file in `projects/<project>/memory/`: that folder's
    `.access.log` (`MEMORY.md` is not logged; it loads without `Read`);
  - a `Read` under `<config>/guides/`: `<config>/usage/guides.log`;
  - a `Skill` call, or a prompt that starts with `/name`: `usage/skills.log`;
  - an `Agent` or `Task` call: its `subagent_type` in `usage/agents.log`.
- `<config>` is `$CLAUDE_CONFIG_DIR`, else the folder above the hook's
  `hooks/`. The hook prints nothing and never blocks or fails a call.
- `--report memory <dir>`, `--report guides` and `--report plugins` total the
  logs, least used first. The plugin report reads
  `plugins/installed_plugins.json` and lists every plugin, also the unused ones.
- `install_hook` in `install.sh` takes the hook event as an optional fourth
  argument (default `PreToolUse`) and registers both entries with the same
  once-only, own-entry-only logic as ADR-0006 and ADR-0009.

## Alternatives Considered

### Alternative 1: A JSON counter file
- **Pros**: the count is ready to read, no report step.
- **Cons**: read, add one, write back races when two sessions log at the same
  moment, and a count is lost or the file is cut.
- **Why not**: an appended line is safe without locking; totalling it is cheap.

### Alternative 2: Also count reads through `Bash` (`cat`, `grep`) and memsearch
- **Pros**: fewer missed uses.
- **Cons**: shell commands would be parsed by guessing, a `grep` over a folder
  would count every file, and memsearch recall has no `Read` call to hook.
- **Why not**: wrong counts are worse than known gaps; the gaps are stated in
  the rules and here.

### Alternative 3: One hook per kind
- **Pros**: each script stays tiny.
- **Cons**: four registrations, four scripts to install and test, and a
  `python3` start per hook on the same `Read` call.
- **Why not**: the kinds share the log format, the report code and the
  registration.

### Alternative 4: No tracking; prune by judgment
- **Pros**: nothing to install.
- **Cons**: what matters is guessed, with no record across sessions.
- **Why not**: the owner asked for data to base grouping and pruning on.

## Consequences

### Positive
- Grouping memories, fixing guide triggers and turning off plugins can start
  from what was never used.

### Negative
- Each `Read`, `Skill`, `Agent` call and each prompt starts a `python3` process.
- The logs grow by one line per use and are never trimmed.

### Risks
- Counts miss uses: `MEMORY.md` lines that were enough on their own, reads
  through `Bash` or memsearch, and skills loaded without a `Skill` call or a
  typed `/name`. A low count is a reason to look, never proof; nothing is
  deleted or turned off on the count alone.
- A prompt starting with `/` is logged even when it is a built-in command; the
  plugin report counts only names that belong to a plugin.
- Hook event names and input fields are version-specific; re-verify after a
  major Claude Code update.
