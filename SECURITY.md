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

- write Markdown rules, templates and a statusline into `~/.claude/`, backing up
  every file it replaces as `<name>.backup-<timestamp>`;
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
Markdown into `~/.claude/`.

## What it never does

- It never writes, reads or copies a credential, token or API key. The only
  environment values it sets are `CAVEMAN_DEFAULT_MODE` and, when you ask for
  it, `ECC_DISABLED_HOOKS`.
- It never sends anything anywhere. The only network access is the package
  manager, the Claude Code installer and the plugin marketplaces.
- It never deletes a file. Replacements are backed up first.

## Third-party trust

The five marketplaces are other people's repositories, installed with
`autoUpdate` on, which means later versions arrive without review. That is a
convenience decision, not a security one. If you would rather pin what runs,
install with `--no-plugins` and add the plugins yourself, or turn `autoUpdate`
off for each marketplace in `~/.claude/settings.json` afterwards.
