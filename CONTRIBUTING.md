# Contributing

## What belongs here

A rule belongs in this pack when it is **project-agnostic** and **earned**:
something went wrong, and the rule is what stops it happening again. Write the
cost next to the rule, the way the existing ones do. A rule with no incident
behind it reads as fussiness and gets deleted by the next person.

A rule does **not** belong here when it is specific to one repository, one
employer, one stack version that will expire quietly, or one person's taste.
Repository-specific rules go in that repository's own `CLAUDE.md`.

## Layout

```
.claude/CLAUDE.md          the global rules; imports every guide
.claude/guides/*.md        one topic per file
.claude/templates/*.md     ADR and project CLAUDE.md starting points
.claude/bin/runclaude      optional launcher
.claude/statusline-*.sh    one build per operating system
install.sh                 detection, substitution, plugins, statusline, auth
```

## Placeholders

Never hard-code a person, a machine or a path. The installer substitutes:

| Placeholder | Filled with |
| --- | --- |
| `{{REPLY_LANGUAGE}}` | the language Claude replies in |
| `{{OWNER_NAME}}` | owner, author, ADR decider |
| `{{OWNER_GITHUB}}` | GitHub handle |
| `{{OWNER_EMAIL}}` | contact email |
| `{{PROJECT_ROOT}}` | where the person's projects live |

The installer aborts if any `{{` survives substitution, so a new placeholder
needs a matching `sed` expression in `install_file()`.

## Before opening a pull request

```sh
bash -n install.sh                      # syntax
shellcheck install.sh .claude/bin/runclaude .claude/statusline-*.sh   # if available

# a full dry run that touches nothing real
CLAUDE_HOME=/tmp/claude-test ./install.sh \
  --language English --name "Ada Lovelace" --github ada \
  --email ada@example.com --project-root /tmp/claude-test/projects \
  --no-launcher --no-statusline --no-plugins -y
```

Then confirm:

- Re-running the installer is a no-op, not a duplicate. Anything it writes twice
  must be detected and reported as already present.
- Nothing personal ships from inside the pack:
  `grep -rniE "your-name|your-handle|@your-domain|/home/[a-z]" .claude install.sh`
  finds nothing. Author credit in `LICENSE` and `README.md` is deliberate; the
  installed files carry placeholders only.
- Every file the installer replaces is backed up as `<name>.backup-<timestamp>`.
- Nothing outside `~/.claude` changes without an explicit yes — the shell rc,
  the global git identity and any interactive login go through `ask_change`,
  which answers no when there is no terminal and under `-y`.

## Shell portability

Both statusline builds and the launcher run on macOS (bash 3.2, BSD userland)
and Linux (bash 5, GNU coreutils):

- No `declare -A`, no `${var^^}`, no `mapfile`.
- `local` on its own line per variable: `local a="$1" b="$2"` trips `set -u`.
- `export LC_NUMERIC=C` before any `printf %f`, or a comma-decimal locale prints
  `$53,00`.
- Prefer portable regex (`[0-9.][0-9.]*`) over GNU-only forms (`[0-9.]\+`).
