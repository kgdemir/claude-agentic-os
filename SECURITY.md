# Security

## Reporting a problem

Use GitHub's private reporting: **Security → Advisories → Report a
vulnerability** on this repository. That reaches the maintainer without the
report being public, and keeps the discussion attached to the code.

Please do not open a public issue for anything that would let someone else
exploit it first. If private reporting is unavailable to you, open a public
issue saying only that you have a security report and asking for a channel —
no details.

## What this pack can do to a machine

It is an installer, so read it before you run it. In full it can:

- write Markdown rules, templates, two hook scripts and a statusline into
  `~/.claude/`, backing up every file whose content it changes as
  `<name>.backup-<timestamp>`;
- merge keys into `~/.claude/settings.json`, never overwrite the file;
- install operating-system packages through `brew`, `sudo apt-get`, `sudo dnf`,
  `sudo zypper` or `sudo pacman`, after asking;
- run `curl -fsSL https://claude.ai/install.sh | bash` to install Claude Code,
  after asking;
- add plugin marketplaces from the five GitHub repositories named in the README
  and install the plugins they publish, which is third-party code that then runs
  inside your Claude Code sessions;
- append a function to your shell rc, set your global git identity and start an
  interactive login — each asked separately, and each declined automatically
  when there is no terminal or when `-y` is passed.

`--no-plugins --no-launcher --no-statusline --no-deps` reduces it to writing
Markdown and the hook scripts into `~/.claude/` and registering the hooks in
`settings.json`.

The hooks run on every Agent and Bash call in your sessions. They only add a
reminder; they never block a command, write a file or use the network. The Bash
hook runs `git diff --cached` (and `git diff` for `git commit -a`) in the
command's folder, with a 5-second limit, to look for secret-shaped text. A
match is reported by file and kind only; the value is never printed, logged or
stored. To check a commit, tag, PR, issue or release text for AI attribution,
it also reads the message file named by `-F`/`--file`/`--body-file`/
`--notes-file`: only a regular file (never a pipe or device), at most 65,536
characters, a relative name resolved against the command's folder and any
`git -C`. Nothing from it is printed or kept.

## What it never does

- It never writes, stores or copies a credential, token or API key. The only
  environment values it sets are `CAVEMAN_DEFAULT_MODE`,
  `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and, when you ask for it,
  `ECC_DISABLED_HOOKS`.
- It never sends anything anywhere. The only network access is the package
  manager, the Claude Code installer and the plugin marketplaces.
- It never deletes a file during an install. Replacements are backed up first,
  and guides from the old flat layout are renamed to
  `<name>.backup-<timestamp>`, not removed. The one deleting path is
  `--prune-backups <N>`, which only removes `.backup-<timestamp>` files in the
  pack's own folders, lists them first, and needs `yes` typed in a terminal.

## Third-party trust

The five marketplaces are other people's repositories, installed with
`autoUpdate` on, which means later versions arrive without review. That is a
convenience decision, not a security one. If you would rather pin what runs,
install with `--no-plugins` and add the plugins yourself, or turn `autoUpdate`
off for each marketplace in `~/.claude/settings.json` afterwards.
