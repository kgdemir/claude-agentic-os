# ADR-0011: Official plugins by name, and the security-audit skill through a pinned skills CLI

**Date**: 2026-10-16
**Status**: accepted
**Deciders**: Kerim Gökhan DEMİR

## Context

The working machine already used 16 plugins from Anthropic's official
marketplace (`claude-plugins-official`): review and workflow tools, security
guidance, Claude setup and authoring tools, and MCP/LSP tools. The pack did not
install them, so a fresh machine lacked them. ADR-0003 installs every plugin a
marketplace publishes; the official marketplace publishes over 300.

Cloudflare's `security-audit` skill (`cloudflare/security-audit-skill`, MIT)
gives security guidance and, when asked, a full multi-phase audit. It has no
plugin marketplace; its upstream install path is the `skills` npm CLI.

Nothing told a session which of these tools to use for which task.

Introduced in the commit that adds this ADR.

## Decision

- `PLUGIN_SOURCES` lines become `<source>[ <plugin>...]`. A line without names
  keeps ADR-0003's behaviour (every plugin); a line with names installs only
  those. `anthropics/claude-plugins-official` is added with the 16 names. A
  named plugin the catalog does not publish is reported and skipped.
- The official marketplace keeps no `autoUpdate` entry in
  `extraKnownMarketplaces`, as before: Claude Code ships and updates it.
- A new step, `--with-security-audit` / `--no-security-audit` (asked, default
  yes in a terminal, no under `-y` or without a terminal), runs
  `npx skills@1.7.2 add https://github.com/cloudflare/security-audit-skill
  --skill security-audit --global --agent claude-code --yes --copy` with a
  throwaway `HOME` and `CLAUDE_CONFIG_DIR` and telemetry off, then copies the
  result into `~/.claude/skills/security-audit` when it differs. The version is
  the `SKILLS_CLI_VERSION` constant in `install.sh`.
- A changed installed copy is backed up as
  `~/.claude/skill-backups/security-audit.tar.backup-<STAMP>`, outside
  `skills/` so it is not loaded as a duplicate skill. `--prune-backups` covers
  that folder (ADR-0010).
- New add-on guide `tools/skills.md` says which skill, command or plugin to use
  for security review, code review, clean-up, debugging, test-first work,
  planning, git and authoring, with a trigger row in `.claude/CLAUDE.md` and
  links from `features/web-security.md` and `features/auth.md` (ADR-0007).

## Alternatives Considered

### Alternative 1: Install the whole official marketplace
- **Pros**: No list to keep; matches ADR-0003.
- **Cons**: Over 300 plugins, most unrelated, all loading skills and MCP servers
  into every session.
- **Why not**: Context cost and attack surface far beyond what the rules use.

### Alternative 2: Download a pinned tarball of the skill repository
- **Pros**: No npm or npx needed; exact content pinned by commit.
- **Cons**: Re-implements what the upstream CLI does; a new skill version needs
  a pack change.
- **Why not**: The owner chose the upstream install path; the CLI version is
  pinned instead.

### Alternative 3: Let the skills CLI write into the real home
- **Pros**: Simplest call; the CLI's own lock file tracks the install.
- **Cons**: Writes `~/.agents/` and replaces an existing copy without a backup.
- **Why not**: Breaks ADR-0002 (back up before replacing, touch nothing else).

## Consequences

### Positive
- A fresh machine gets the same official plugins and the audit skill.
- Sessions have one guide that maps a task to a tool, with the core rules
  winning on conflict.

### Negative
- The 16 names are a list to maintain; a renamed upstream plugin shows up only
  as a "does not publish" line.
- The skill step needs Node (`npx`) and git, and network access to npm and
  GitHub.

### Risks
- Supply chain: the skill content is whatever upstream `main` holds at install
  time; only the CLI is pinned. Re-running the installer is what updates it,
  and the diff against the installed copy shows whether anything changed.
