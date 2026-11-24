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

- write Markdown rules, templates, five hook scripts and a statusline into
  `~/.claude/`, backing up every file whose content it changes as
  `<name>.backup-<timestamp>`;
- merge keys into `~/.claude/settings.json`, never overwrite the file;
- install operating-system packages through `brew`, `sudo apt-get`, `sudo dnf`,
  `sudo zypper` or `sudo pacman`, after asking;
- run `curl -fsSL https://claude.ai/install.sh | bash` to install Claude Code,
  after asking;
- add plugin marketplaces from the six GitHub repositories named in the README
  and install the plugins they publish (from Anthropic's official marketplace,
  only the 17 the README names), which is third-party code that then runs
  inside your Claude Code sessions;
- run `npm install --prefix ~/.local/share/ts-lsp typescript-language-server@6
  typescript@6` (linked into `~/.local/bin`) and `dotnet tool install --global
  csharp-ls`, after asking, so the two LSP plugins have their language servers;
- run `npx skills@<pinned version> add` to fetch Cloudflare's `security-audit`
  skill from GitHub, after asking: the CLI runs with a throwaway `HOME` and
  config folder and telemetry off, and the installer copies the result into
  `~/.claude/skills/security-audit`, backing up a changed copy as a tar file in
  `~/.claude/skill-backups/` first;
- with `--with-launcher`, install `runclaude`, which on each launch installs
  missing tools without a further prompt and uninstalls an npm global
  `@anthropic-ai/claude-code` that sits beside the native Claude Code (never
  while a session runs from it, and never with `sudo`; ADR-0014);
- with `--with-launcher`, offer `uv tool install llm==<pinned>` with three
  pinned provider plugins, after asking, and install `ask-llm` and
  `ask-llm-web` (ADR-0019);
- append a function to your shell rc, set your global git identity and start an
  interactive login — each asked separately, and each declined automatically
  when there is no terminal or when `-y` is passed.

`--no-plugins --no-security-audit --no-launcher --no-statusline --no-deps`
reduces it to writing Markdown and the hook scripts into `~/.claude/` and
registering the hooks in `settings.json`.

The hooks never use the network, and only one ever blocks: the Agent hook
stops a new subagent when the 5-hour or weekly usage limit the statusline saved
in `~/.claude/usage/limits.json` is near (ADR-0015). Otherwise the Agent and Bash
hooks only add a reminder. The usage-log hook appends one line per memory, guide,
skill or agent use to logs under `~/.claude/usage/` and each project's memory
folder (ADR-0012). The LSP hook reads plugin files at session start and only
warns (ADR-0013). The symbol-search hook reads the same plugin files and, for
a search with no file scope, runs `git ls-files` in the session's folder with a
2-second limit; it only adds a reminder (ADR-0016). The Bash
hook runs `git diff --cached` (and `git diff` for `git commit -a`) in the
folder the commit runs in (after any `cd` or `git -C`), with a 5-second limit, to look for secret-shaped text. A
match is reported by file and kind only; the value is never printed, logged or
stored. To check a commit, tag, PR, issue or release text for AI attribution,
it also reads the message file named by `-F`/`--file`/`--body-file`/
`--notes-file`, and the files a `cat … > file` or `cp … file` in the same
command copies into it: only a regular file (never a pipe or device), at most
65,536 characters, a relative name resolved against the command's folder as
moved by any `cd` and `git -C`. Nothing from it is printed or kept.

## What it never does

- It never writes, stores or copies a credential, token or API key. The only
  environment values it sets are `CAVEMAN_DEFAULT_MODE`,
  `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and, when you ask for it,
  `ECC_DISABLED_HOOKS`.
- It never sends anything anywhere. The only network access is the package
  manager, the Claude Code installer, the plugin marketplaces, npm and NuGet
  for the two language servers, npm and GitHub for the `security-audit`
  skill, and PyPI for `llm`.
- It never deletes a file during an install. Replacements are backed up first,
  and guides from the old flat layout are renamed to
  `<name>.backup-<timestamp>`, not removed. A changed `security-audit` skill
  folder is removed only after its tar backup is written. The one deleting
  path is
  `--prune-backups <N>`, which only removes `.backup-<timestamp>` files in the
  pack's own folders, lists them first, and needs `yes` typed in a terminal.

## ask-llm sends text to other companies

`ask-llm` (ADR-0019) sends the prompt and any piped text to Google, OpenRouter
and the model provider it routes to, or OpenAI, under each one's own terms;
free tiers may use the text for training. The rule Claude follows sends private
text (payslips, bank or card data, customer or personal data, secrets, keys,
connection strings, private source code) only through `--private`, which refuses
any model but a local Ollama one. API keys are kept by `llm` in its own key file,
never by the pack. The prompt reaches `llm` on stdin, so it never shows in the
process list. `ask-llm-web` drives the ChatGPT or Gemini web page and keeps its
browser profile, logins included, in `~/.claude/ask-llm-web/`; automating those
pages is likely against their terms and can get the account banned.

## Third-party trust

The five community marketplaces are other people's repositories, installed
with `autoUpdate` on, which means later versions arrive without review. The
official marketplace is updated by Claude Code itself. The `security-audit`
skill is whatever its upstream repository holds when the installer runs; only
the `skills` CLI version is pinned, and re-running the installer is what
updates the skill. That is a convenience decision, not a security one. If you would rather pin what runs,
install with `--no-plugins` and add the plugins yourself, or turn `autoUpdate`
off for each marketplace in `~/.claude/settings.json` afterwards.
