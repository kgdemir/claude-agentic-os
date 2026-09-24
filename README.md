# Claude Agentic OS — a portable Claude Code setup

**A one-command agentic operating system for [Claude Code](https://claude.ai/code):
global rules, a curated plugin set, persistent per-project memory, a statusline
and an optional project launcher — installed, wired together and kept up to date
by `./install.sh`.**

Claude Code out of the box is a capable coding agent with no opinions. This pack
supplies the opinions: how the agent verifies its work, how it diagnoses a
failure, when it may push, what it may rewrite, where it keeps what it learned.
Every rule here was written after something went wrong, and each one records what
it cost.

Nothing in the pack is tied to one person, one machine or one repository. Your
name, GitHub handle, email, reply language and projects folder are placeholders
filled in at install time.

```sh
git clone https://github.com/kgdemir/claude-agentic-os.git
cd claude-agentic-os
./install.sh
```

**Works on:** macOS · Ubuntu / Debian · Fedora / RHEL · openSUSE · Arch · WSL2
**Needs:** `bash`, `git`. Everything else is offered and installed for you.

---

## Contents

- [Why this exists](#why-this-exists)
- [What you get](#what-you-get)
- [Install](#install)
- [What gets installed where](#what-gets-installed-where)
- [The plugin set](#the-plugin-set)
- [Memory: one database per project](#memory-one-database-per-project)
- [What the installer changes outside ~/.claude](#what-the-installer-changes-outside-claude)
- [The statusline](#the-statusline)
- [The optional launcher](#the-optional-launcher)
- [Adapting the rules](#adapting-the-rules)
- [Uninstalling and rolling back](#uninstalling-and-rolling-back)
- [Security](#security)
- [Keywords](#keywords)

## Why this exists

An AI coding agent fails in the same few ways on every project:

- It reads a command's output instead of its exit code and reports a broken
  build as green.
- It ships a plausible fix for a bug it never diagnosed, then another, then
  another.
- It rewrites the user guide as a side effect of a one-line fix.
- It stages everything, including a virtual environment.
- It forgets, between sessions, everything it learned about the codebase.

Each of those has a rule in `agent-working-rules.md`, with the incident that
produced it. Install the pack and Claude Code starts every session already
holding them.

## What you get

| Piece | What it does |
| --- | --- |
| **Global rules** (`~/.claude/CLAUDE.md` + `guides/`) | verification, diagnosis, background work, git hygiene, documentation policy, code quality, decision records |
| **Plugin set** | caveman, context-mode, drywall, ECC, memsearch — installed, enabled, auto-updating |
| **Per-project memory** | memsearch, with a separate database per project so facts never cross repositories |
| **Statusline** | model, effort, context remaining, session cost, burn rate, git branch with +/− counts |
| **Templates** | an ADR template and a project `CLAUDE.md` template |
| **Launcher** (optional) | `runclaude <project>` — installs missing tooling, prepares the venv, fast-forwards a clean default branch, opens Claude |

## Install

```sh
./install.sh
```

It detects your operating system and package manager, reads your name, GitHub
handle and email from `gh` when you are signed in, asks for whatever it could
not detect, and writes the filled-in rules to `~/.claude/`. Re-running is safe:
any file it would overwrite is copied to `<name>.backup-<timestamp>` first.

Non-interactive:

```sh
./install.sh --language English --name "Ada Lovelace" --github ada \
             --email ada@example.com --project-root ~/projects \
             --with-plugins --with-statusline --install-deps -y
```

| Option | Meaning |
| --- | --- |
| `--language` | Language Claude replies in (default `English`) |
| `--name` | Name used as owner, author and ADR decider |
| `--github` | GitHub username |
| `--email` | Contact email; defaults to your GitHub address, or the `id+login@users.noreply.github.com` form when your address is private |
| `--project-root` | Where your projects live (default `~/claude`) |
| `--with-launcher` / `--no-launcher` | Install the optional launcher, or skip the question |
| `--with-statusline` / `--no-statusline` | Install the statusline, or skip the question |
| `--with-plugins` / `--no-plugins` | Install the plugin set, or skip the question |
| `--install-deps` / `--no-deps` | Install every missing tool (`python3`, `claude`, `jq`, `npm`, …) without asking, or never |
| `-y`, `--yes` | Accept every detected default, ask nothing |

The installer refuses rather than writing a blank if a required detail is
missing and it cannot ask — for example in a pipeline with no `gh` session.

It never writes a credential. The only environment values it sets are
`CAVEMAN_DEFAULT_MODE` and, if you ask for it, `ECC_DISABLED_HOOKS`.

It also fills in three settings a fresh machine otherwise needs by hand, and
only when `settings.json` does not already carry them:

| Setting | Value | Why |
| --- | --- | --- |
| `includeCoAuthoredBy` | `false` | stops Claude Code appending a `Co-Authored-By` trailer to your commits |
| `effortLevel` | `medium` | a default instead of none |
| `theme` | `dark` | a default instead of none |

## What gets installed where

```
~/.claude/CLAUDE.md              global rules; imports each guide below
~/.claude/guides/
  agent-working-rules.md         verification, diagnosis, background work, git,
                                 code quality, decisions and memory
  project-tools.md               repeatable commands live in tools/ scripts
  project-claude-md.md           each project keeps its own CLAUDE.md
  project-docs.md                README.md, capabilities.md, SECURITY.md
  docs-updates.md                docs change on request; baseline marker; PDF rules
  docs-folder.md                 docs/adr/ and docs/user-guides/ layout
  dotnet.md                      .NET conventions (test gate, warnings as errors)
  dotnet-gotchas.md              .NET traps that fail silently
  react.md                       ESLint rules, render-loop guards, chunk grouping
~/.claude/templates/
  adr-template.md                architecture decision record
  project-claude-template.md     starting point for a project CLAUDE.md
~/.claude/bin/
  runclaude                      optional launcher (only with --with-launcher)
~/.claude/statusline.sh          statusline for this OS (only with --with-statusline)
~/.claude/settings.json          merged, never overwritten; backed up first
```

## The plugin set

With `--with-plugins` (the interactive default is yes) the installer adds five
marketplaces, installs every plugin each one publishes, enables them, and sets
`autoUpdate` so later versions arrive on their own:

| Plugin | Source | What it adds |
| --- | --- | --- |
| caveman | `JuliusBrussee/caveman` | terse reply style; installed at its `ultra` level |
| context-mode | `mksglu/context-mode` | sandboxed search/execute tools that keep raw output out of the context window |
| drywall | `nikhaldi/drywall` | duplicate-code detection |
| ecc | `https://github.com/affaan-m/ECC.git` | a large agent, skill and hook collection |
| memsearch | `zilliztech/memsearch` | searchable session memory, one database per project |

The catalog is read from each marketplace rather than hard-coded, so a plugin
an upstream repository adds later is installed too, without a change here.

It needs the `claude` CLI and `python3`. If either is missing the installer says
what it is for and offers to install it — `python3` through your package
manager, `claude` through `curl -fsSL https://claude.ai/install.sh | bash` — and
only skips the step if you decline. `--install-deps` answers yes to all of them,
`--no-deps` answers no and just prints the command. The same offer covers `npm`
when `ccusage` is wanted for the statusline. Re-running installs nothing twice:
a marketplace or plugin already there is reported as present.

Two settings are written for you:

- `CAVEMAN_DEFAULT_MODE=ultra`, so caveman starts at its terse level.
- `ECC_DISABLED_HOOKS`, which the installer asks about. ECC's gateguard hooks
  interrupt before an edit, a read/write and a shell command to demand a cited
  fact. On a machine you own that is mostly a nag, so the installer offers the
  three ids that turn them off and leaves the rest of ECC running. An empty
  answer keeps every hook.

Everything lands in `~/.claude/settings.json` (backed up first), beside whatever
is already in that file.

## Memory: one database per project

Facts Claude learns are kept per project, never in one shared pile:

- `~/.claude/projects/<project>/memory/` — one fact per `name.md`, with a
  one-line pointer in `MEMORY.md`. The index holds pointers, never content, and
  no file is left unreferenced.
- **Each project gets its own memsearch database.** A shared database mixes
  unrelated repositories and answers a question about one codebase with a fact
  from another. The rule is in the installed `CLAUDE.md`.
- Memory is context, not truth: anything a stored note claims about the code is
  verified against the code before it is acted on.

## What the installer changes outside ~/.claude

Four things live outside the rules directory. Each is asked about separately,
and each answers **no** when there is no terminal or when you passed `-y`, in
which case the exact command is printed for you to run yourself:

| Change | What happens |
| --- | --- |
| **Sign in to Claude Code** | `claude auth status` is checked; if you are signed out it offers `claude auth login`, because plugins install fine and then the first session stops at a login screen |
| **Sign in to GitHub** | same for `gh auth login`; without it Claude cannot open a pull request, read an issue or clone a private repository for you |
| **Global git identity** | if `git config --global user.name/user.email` differs from what you entered, it offers to set them |
| **Shell rc** | with the launcher, it offers to append `CLAUDE_ROOT` and the `runclaude` function to `~/.zshrc`, `~/.bashrc` or `~/.profile`, between `# >>> claude rules pack` markers; the rc file is backed up first |

## The statusline

Shows directory, git branch with +added/−deleted counts, model, effort, context
remaining, session cost and burn rate. The installer picks the build for your
system — `statusline-linux.sh` (GNU date, coreutils timeout) or
`statusline-macos.sh` (bash 3.2, BSD date, perl alarm) — copies it to
`~/.claude/statusline.sh`, and registers it in `~/.claude/settings.json`,
keeping every other setting already in that file.

Its tools are all optional, and it degrades rather than failing:

| Tool | What it adds | Without it |
| --- | --- | --- |
| `jq` | proper JSON parsing | a grep/sed fallback runs; context bar and costs are skipped |
| `git` | branch name, +added/−deleted | that segment is omitted |
| `ccusage` | "Xh Ym until reset" with the block's cost and tokens | that segment is omitted; this is the one figure Claude Code does not report itself |
| `perl` | bounds how long `ccusage` may run | only needed where coreutils `timeout` is missing |

The installer lists whichever are missing, explains each, and offers to install
them with your package manager — including `npm` itself when `ccusage` is wanted
and npm is absent.

Both builds set `LC_NUMERIC=C`. Without it a comma-decimal locale prints the
session cost as `$53,00`.

## The optional launcher

`runclaude` is installed to `~/.claude/bin/runclaude`, beside the rules rather
than in your projects folder, and so is its memsearch virtual environment
(`~/.claude/.venv`; override with `CLAUDE_VENV`). The projects root stays for
projects and reaches the launcher as `CLAUDE_ROOT`.

It opens a project, installs missing tooling (git, gh, jq, uv, node,
bun, .NET SDK, Claude Code) through whichever package manager the machine has,
sets up a memsearch virtual environment, and fast-forwards the repository's
default branch. It supports macOS and Linux.

It is opt-in because it installs software and touches your working tree. What it
will and will not do:

- It installs packages **without a further prompt**, using Homebrew on macOS
  (installing Homebrew itself if absent) or `sudo apt/dnf/zypper/pacman` on Linux.
- It pulls **only** when you are already on the default branch and the working
  tree is clean, and only as a fast-forward. It never switches branches for you.
- It mirrors `GITHUB_PERSONAL_ACCESS_TOKEN` into `GH_TOKEN` when that variable is
  set, so `gh` and git authenticate without an interactive login. It never writes
  that token anywhere.

Skip it if you would rather manage your own tooling; the rules work without it.

## Adapting the rules

The guides are ordinary Markdown, meant to be edited. Two things to know before
you cut something:

- Each rule in `agent-working-rules.md` and `dotnet-gotchas.md` carries a note of
  what it cost when it was learned. A rule that looks like fussiness usually has
  a broken build behind it.
- `react.md` is version-sensitive and says so at the top. The pinned versions
  expire; the reasoning does not.

## Uninstalling and rolling back

Every file the installer replaces is kept as `<name>.backup-<timestamp>` in the
same directory, `settings.json` included. To undo a run, move the backups back.
To drop the plugins: `claude plugin uninstall <plugin>@<marketplace>` and
`claude plugin marketplace remove <marketplace>`. To drop the rules, delete
`~/.claude/CLAUDE.md`, `~/.claude/guides/` and `~/.claude/templates/`. To unwire
the launcher, delete the block between the `# >>> claude rules pack` and
`# <<< claude rules pack` markers in your shell rc.

## Security

The installer can install operating-system packages, run the Claude Code
installer, add third-party plugin marketplaces with auto-update on, touch your
shell rc and set your global git identity — each after asking.
[SECURITY.md](SECURITY.md) lists exactly what it can and cannot do, and how to
report a problem.

## Contributing

Rules are welcome when they are project-agnostic and earned — see
[CONTRIBUTING.md](CONTRIBUTING.md) for what belongs here, the placeholder
contract and the shell-portability rules.

Maintained by Kerim Gökhan DEMİR ([@kgdemir](https://github.com/kgdemir)).
Licensed MIT.

## Keywords

Claude Code setup · Claude agentic OS · agentic operating system · AI coding
agent rules · `CLAUDE.md` template · Claude Code plugins · Claude Code
marketplace · Claude Code statusline · Claude Code memory · agent memory per
project · memsearch · context-mode · caveman plugin · ECC plugin · drywall ·
AI agent guardrails · LLM coding standards · architecture decision records ·
ADR template · dotfiles for Claude Code · macOS Linux WSL installer
