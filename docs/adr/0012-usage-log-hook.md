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

## Amendment 2026-11-09

After a review of `2deb277` (fixed in `312a3bd`):
- Log lines start with Unix time (whole seconds, UTC) instead of a local ISO
  time, so times compare as numbers across time zones; the reports show them
  in local time.
- Memory reads are logged only under `<config>/projects/`, so a repository
  with a `projects/*/memory/` folder of its own gets no `.access.log`.
- A typed `/name` must end at a space or the end of the prompt, so a prompt
  that starts with a path is not logged. A bare name is credited to the one
  plugin item with that short name; an ambiguous one to none.
- The guides folder is resolved through symlinks; skill and agent names come
  from the frontmatter only; every install path of a plugin is scanned; and an
  unreadable file or a bad `installed_plugins.json` is reported on stderr
  instead of being skipped silently or crashing the report.

## Amendment 2026-11-09 (second review)

After a review of `312a3bd`:
- An empty, unreadable or out-of-range time makes its line a bad line: skipped
  and counted on stderr, never a use and never a report crash. Lines with the
  local ISO time of the first release are still read.
- A user skill in `~/.claude/skills/` or a user agent in `~/.claude/agents/`
  wins over a plugin item of the same bare name; one plugin from two
  marketplaces is one row with both lists.
- A typed `/name` may be followed by punctuation. A one-segment path typed
  alone (`/tmp`) still matches, but never counts for a plugin.
- Only the first 8KB of a skill or agent file is read for its name, after a
  leading BOM. Built-in commands and project skills are still unknown to the
  report, so a bare name that matches one plugin item is credited to it.

## Amendment 2026-11-09 (known gaps)

Three gaps named in the second amendment are closed in the hook:

- A bare name found as `.claude/skills/<name>/SKILL.md`, `.claude/commands/<name>.md`
  or `.claude/agents/<name>.md` under the session's `cwd` or a folder above it is
  logged as `project/<name>`. The user's own config folder is not a project. The
  plugin report sums these in one `(project skills and agents)` row; its totals show
  `-`, because project items differ per project.
- A bare name typed as `/name` is logged as `typed/<name>`. A typed name may be a
  built-in command, and no reliable list of those exists, so the report credits a
  typed name to a user skill of that name, but never to a plugin item. Cost: a
  plugin skill typed by its short name (`/caveman`) is no longer counted; typed in
  full (`/caveman:caveman`), or loaded through a `Skill` call, it still is.
- A typed `/name` that exists as a path at the filesystem root (`/tmp`) is not logged.

## Amendment 2026-11-09 (typed short names)

Typed short names count for plugins again: the report reads `typed/<name>` the same
as a bare `Skill` call, so `/caveman` is credited to the one plugin item of that
name. The owner chose this over a hand-kept list of built-in commands, which would
go stale. Cost: a built-in command that shares a plugin item's short name
(`/code-review`) is counted for that plugin. The `typed/` marker stays in the log,
so typed uses can still be told apart from `Skill` calls.
