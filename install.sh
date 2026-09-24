#!/usr/bin/env bash
# Installs the Claude rules pack into ~/.claude, filling in the details that
# differ per person. Safe to re-run: every file it would overwrite is backed up
# next to the original first.
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"

REPLY_LANGUAGE=""
OWNER_NAME=""
OWNER_GITHUB=""
OWNER_EMAIL=""
PROJECT_ROOT=""
WITH_LAUNCHER=""
WITH_STATUSLINE=""
WITH_PLUGINS=""
INSTALL_DEPS=""
ASSUME_YES=""

usage() {
  cat >&2 <<'USAGE'
usage: ./install.sh [options]

  --language <name>      Language Claude replies in (default: English)
  --name <full name>     Name used as owner/author/decider in projects
  --github <handle>      GitHub username
  --email <address>      Contact email (default: derived from GitHub)
  --project-root <path>  Where projects live (default: ~/claude)
  --with-launcher        Also install the runclaude launcher
  --no-launcher          Skip the launcher without asking
  --with-statusline      Install the statusline for this OS and register it
  --no-statusline        Skip the statusline without asking
  --with-plugins         Install the plugin set, enable it, turn on auto-update
  --no-plugins           Skip the plugins without asking
  --install-deps         Install missing statusline tools without asking
  --no-deps              Never install tools; just report what is missing
  -y, --yes              Accept every detected default, ask nothing
  -h, --help             This text
USAGE
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --language) REPLY_LANGUAGE="${2:-}"; shift 2 ;;
    --name) OWNER_NAME="${2:-}"; shift 2 ;;
    --github) OWNER_GITHUB="${2:-}"; shift 2 ;;
    --email) OWNER_EMAIL="${2:-}"; shift 2 ;;
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    --with-launcher) WITH_LAUNCHER=yes; shift ;;
    --no-launcher) WITH_LAUNCHER=no; shift ;;
    --with-statusline) WITH_STATUSLINE=yes; shift ;;
    --with-plugins) WITH_PLUGINS=yes; shift ;;
    --no-plugins) WITH_PLUGINS=no; shift ;;
    --no-statusline) WITH_STATUSLINE=no; shift ;;
    --install-deps) INSTALL_DEPS=yes; shift ;;
    --no-deps) INSTALL_DEPS=no; shift ;;
    -y|--yes) ASSUME_YES=yes; shift ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done

# ---------------------------------------------------------------- environment

case "$(uname -s)" in
  Darwin) OS_NAME="macOS"; OS_KIND="macos" ;;
  Linux)
    OS_KIND="linux"
    if [ -r /etc/os-release ]; then
      # shellcheck disable=SC1091
      OS_NAME="$(. /etc/os-release && echo "${PRETTY_NAME:-Linux}")"
    else
      OS_NAME="Linux"
    fi
    grep -qi microsoft /proc/version 2>/dev/null && OS_NAME="$OS_NAME (WSL)"
    ;;
  *) OS_NAME="$(uname -s)"; OS_KIND="other" ;;
esac

PKG_MANAGER="none"
for CANDIDATE in brew apt-get dnf zypper pacman; do
  if command -v "$CANDIDATE" >/dev/null 2>&1; then PKG_MANAGER="$CANDIDATE"; break; fi
done

# The command a person would type to install a package here, for messages.
pkg_install_cmd() {
  case "$PKG_MANAGER" in
    brew) echo "brew install $*" ;;
    apt-get) echo "sudo apt-get install -y $*" ;;
    dnf) echo "sudo dnf install -y $*" ;;
    zypper) echo "sudo zypper install -y $*" ;;
    pacman) echo "sudo pacman -S $*" ;;
    *) echo "your package manager: $*" ;;
  esac
}

# Installs packages with whatever manager this machine has. Unknown manager:
# name what is missing and let the caller carry on, rather than guess.
pkg_install() {
  [ $# -gt 0 ] || return 0
  case "$PKG_MANAGER" in
    brew) brew install "$@" ;;
    apt-get) sudo apt-get update -qq && sudo apt-get install -y "$@" ;;
    dnf) sudo dnf install -y "$@" ;;
    zypper) sudo zypper install -y "$@" ;;
    pacman) sudo pacman -S --noconfirm "$@" ;;
    *) echo "!! No supported package manager found. Install manually: $*" >&2; return 1 ;;
  esac
}

echo "==> System:  $OS_NAME"
echo "==> Packages: $PKG_MANAGER"
echo "==> Target:  $DEST"

# ------------------------------------------------------------------- identity

# GitHub first: the CLI knows the handle, the display name and often the email.
GH_LOGIN=""; GH_NAME=""; GH_EMAIL=""; GH_ID=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  GH_JSON="$(gh api user 2>/dev/null || true)"
  if [ -n "$GH_JSON" ] && command -v python3 >/dev/null 2>&1; then
    eval "$(printf '%s' "$GH_JSON" | python3 -c '
import json, sys, shlex
d = json.load(sys.stdin)
for key, field in (("GH_LOGIN", "login"), ("GH_NAME", "name"), ("GH_EMAIL", "email"), ("GH_ID", "id")):
    value = d.get(field)
    print(key + "=" + shlex.quote(str(value) if value else ""))
' 2>/dev/null || true)"
  fi
  [ -n "$GH_LOGIN" ] && echo "==> GitHub:  @$GH_LOGIN${GH_NAME:+ ($GH_NAME)}"
fi
[ -n "$GH_LOGIN" ] || echo "==> GitHub:  not signed in (gh auth login) — will ask"

ask() { # ask <prompt> <default> -> echoes the answer
  local prompt="$1" default="$2" answer=""
  if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
    printf '%s\n' "$default"
    return
  fi
  read -r -p "$prompt${default:+ [$default]}: " answer </dev/tty || true
  printf '%s\n' "${answer:-$default}"
}

# Steps that change something outside ~/.claude — your shell rc, your global git
# identity, an interactive login — are never taken silently. Without a terminal,
# and under -y, the answer is no and the command is printed instead.
ask_change() { # ask_change <prompt> -> echoes yes or no
  if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
    printf 'no\n'
    return
  fi
  ask "$1" 'yes'
}

[ -n "$REPLY_LANGUAGE" ] || REPLY_LANGUAGE="$(ask 'Language Claude should reply in' 'English')"
[ -n "$OWNER_NAME" ] || OWNER_NAME="$(ask 'Your name (owner/author/ADR decider)' "${GH_NAME:-$(git config --global user.name 2>/dev/null || true)}")"
[ -n "$OWNER_GITHUB" ] || OWNER_GITHUB="$(ask 'Your GitHub username' "$GH_LOGIN")"

# A GitHub account without a public email still has a stable noreply address,
# which is what most people want in commits anyway.
DEFAULT_EMAIL="$GH_EMAIL"
if [ -z "$DEFAULT_EMAIL" ] && [ -n "$GH_ID" ] && [ -n "$OWNER_GITHUB" ]; then
  DEFAULT_EMAIL="${GH_ID}+${OWNER_GITHUB}@users.noreply.github.com"
fi
[ -n "$DEFAULT_EMAIL" ] || DEFAULT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
[ -n "$OWNER_EMAIL" ] || OWNER_EMAIL="$(ask 'Contact email' "$DEFAULT_EMAIL")"

[ -n "$PROJECT_ROOT" ] || PROJECT_ROOT="$(ask 'Where your projects live' "$HOME/claude")"
PROJECT_ROOT="${PROJECT_ROOT%/}"

MISSING_FIELDS=""
[ -n "$REPLY_LANGUAGE" ] || MISSING_FIELDS="$MISSING_FIELDS language"
[ -n "$OWNER_NAME" ] || MISSING_FIELDS="$MISSING_FIELDS name"
[ -n "$OWNER_GITHUB" ] || MISSING_FIELDS="$MISSING_FIELDS github"
[ -n "$OWNER_EMAIL" ] || MISSING_FIELDS="$MISSING_FIELDS email"
if [ -n "$MISSING_FIELDS" ]; then
  echo "!! Missing:$MISSING_FIELDS — pass them as options or run interactively." >&2
  exit 1
fi

echo
echo "    Reply language : $REPLY_LANGUAGE"
echo "    Owner          : $OWNER_NAME (@$OWNER_GITHUB)"
echo "    Email          : $OWNER_EMAIL"
echo "    Project root   : $PROJECT_ROOT"
echo

# --------------------------------------------------------------------- write

install_file() { # install_file <relative path>
  local rel="$1"
  local src="$SRC_DIR/$rel"
  local dst="$DEST/${rel#.claude/}"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
    cp -p "$dst" "$dst.backup-$STAMP"
    echo "    backed up  ${dst}.backup-$STAMP"
  fi
  # Placeholders are substituted with a here-doc-free sed: values may contain
  # spaces and non-ASCII, never slashes we care about, so | is a safe delimiter.
  sed -e "s|{{REPLY_LANGUAGE}}|$REPLY_LANGUAGE|g" \
      -e "s|{{OWNER_NAME}}|$OWNER_NAME|g" \
      -e "s|{{OWNER_GITHUB}}|$OWNER_GITHUB|g" \
      -e "s|{{OWNER_EMAIL}}|$OWNER_EMAIL|g" \
      -e "s|{{PROJECT_ROOT}}|$PROJECT_ROOT|g" \
      "$src" > "$dst"
  echo "    installed  $dst"
}

while IFS= read -r REL; do
  install_file "$REL"
done < <(cd "$SRC_DIR" && find .claude -type f -name '*.md' | sort)

LEFTOVER="$(grep -rl '{{' "$DEST" --include='*.md' 2>/dev/null || true)"
if [ -n "$LEFTOVER" ]; then
  echo "!! Placeholders left unsubstituted in:" >&2
  printf '   %s\n' $LEFTOVER >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT"

# ------------------------------------------------------------------ launcher

if [ -z "$WITH_LAUNCHER" ]; then
  if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
    WITH_LAUNCHER=no
  else
    echo
    echo "The optional runclaude launcher (installed to $DEST/bin) opens a project,"
    echo "installs missing tools (git, gh, jq, uv, node, bun, .NET, Claude Code) with"
    echo "$PKG_MANAGER, sets up a memsearch venv, and fast-forwards the default branch"
    echo "when the tree is clean."
    ANSWER="$(ask 'Install it?' 'no')"
    case "$ANSWER" in [Yy]*) WITH_LAUNCHER=yes ;; *) WITH_LAUNCHER=no ;; esac
  fi
fi

if [ "$WITH_LAUNCHER" = "yes" ]; then
  if [ "$OS_KIND" = "other" ]; then
    echo "!! The launcher supports macOS and Linux only; skipping on $OS_NAME." >&2
  else
    mkdir -p "$DEST/bin"
    if [ -e "$DEST/bin/runclaude" ] && ! cmp -s "$SRC_DIR/.claude/bin/runclaude" "$DEST/bin/runclaude"; then
      cp -p "$DEST/bin/runclaude" "$DEST/bin/runclaude.backup-$STAMP"
      echo "    backed up  $DEST/bin/runclaude.backup-$STAMP"
    fi
    cp -p "$SRC_DIR/.claude/bin/runclaude" "$DEST/bin/runclaude"
    chmod +x "$DEST/bin/runclaude"
    echo "    installed  $DEST/bin/runclaude"
    # The function, not a bare PATH entry: it re-sources the memsearch venv in
    # the calling shell after the launcher exits, which a subprocess cannot do.
    RC_MARKER="# >>> claude rules pack (runclaude) >>>"
    RC_BLOCK="$(cat <<SHELLFN
$RC_MARKER
export CLAUDE_ROOT="$PROJECT_ROOT"
runclaude () {
  "$DEST/bin/runclaude" "\$@"
  local rc=\$?
  [ -f "$DEST/.venv/bin/activate" ] && source "$DEST/.venv/bin/activate"
  return \$rc
}
# <<< claude rules pack (runclaude) <<<
SHELLFN
)"
    case "${SHELL:-}" in
      */zsh) SHELL_RC="$HOME/.zshrc" ;;
      */bash) SHELL_RC="$HOME/.bashrc" ;;
      *) SHELL_RC="$HOME/.profile" ;;
    esac

    if grep -qF "$RC_MARKER" "$SHELL_RC" 2>/dev/null; then
      echo "    already wired  $SHELL_RC"
    else
      ANSWER="$(ask_change "Add CLAUDE_ROOT and the runclaude function to $SHELL_RC?")"
      case "$ANSWER" in
        [Nn]*)
          echo
          echo "    Add this to your shell rc yourself:"
          printf '%s\n' "$RC_BLOCK" | sed 's/^/      /'
          ;;
        *)
          [ -e "$SHELL_RC" ] && cp -p "$SHELL_RC" "$SHELL_RC.backup-$STAMP"
          printf '\n%s\n' "$RC_BLOCK" >> "$SHELL_RC"
          echo "    wired  $SHELL_RC  (open a new shell, or: source $SHELL_RC)"
          ;;
      esac
    fi
  fi
fi

# -------------------------------------------------------------------- plugins

# The marketplaces this pack expects. Each one currently publishes a single
# plugin, but the installer installs every plugin a marketplace lists, so an
# upstream split does not need a change here.
#   caveman       terse reply style; set to its "ultra" level below
#   context-mode  sandboxed search/execute tools that keep raw bytes out of context
#   drywall       duplicate-code detection
#   ecc           a large agent/skill/hook collection
#   memsearch     searchable session memory, one database per project
PLUGIN_SOURCES="JuliusBrussee/caveman
mksglu/context-mode
nikhaldi/drywall
https://github.com/affaan-m/ECC.git
zilliztech/memsearch"

if [ -z "$WITH_PLUGINS" ]; then
  if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
    WITH_PLUGINS=no
  else
    echo
    echo "Plugin set: caveman, context-mode, drywall, ecc, memsearch. The installer"
    echo "adds each marketplace, installs the latest version of every plugin in it,"
    echo "enables them, and turns on auto-update so later versions arrive by themselves."
    ANSWER="$(ask 'Install them?' 'yes')"
    case "$ANSWER" in [Nn]*) WITH_PLUGINS=no ;; *) WITH_PLUGINS=yes ;; esac
  fi
fi

# A tool this installer needs is missing: say what it is for, offer to install
# it, and on a no return non-zero so the caller can skip its step. --install-deps
# answers yes for every one of these, --no-deps answers no.
offer_install() { # offer_install <tool> <why> <how> [package]
  local tool="$1"
  local why="$2"
  local how="$3"
  local package="${4:-$1}"
  command -v "$tool" >/dev/null 2>&1 && return 0
  echo
  echo "$tool is not installed. $why"
  if [ "$INSTALL_DEPS" = "no" ]; then
    echo "    Install it with: $how"
    return 1
  fi
  local answer="no"
  if [ "$INSTALL_DEPS" = "yes" ]; then
    answer=yes
  elif [ -z "$ASSUME_YES" ] && [ -t 0 ]; then
    echo "    Would run: $how"
    answer="$(ask "Install $tool now?" 'yes')"
  fi
  case "$answer" in
    [Yy]*) ;;
    *) echo "    Skipped. Install it with: $how"; return 1 ;;
  esac
  case "$tool" in
    claude) curl -fsSL https://claude.ai/install.sh | bash ;;
    *) pkg_install "$package" || return 1 ;;
  esac
  hash -r
  command -v "$tool" >/dev/null 2>&1
}

INSTALLED_PLUGIN_IDS=""
if [ "$WITH_PLUGINS" = "yes" ]; then
  if ! offer_install python3 \
       "The plugin step reads the marketplace catalogs (JSON) with it, and merges settings.json instead of overwriting it." \
       "$(pkg_install_cmd python3)"; then
    echo "!! Skipping plugins: no python3." >&2
    WITH_PLUGINS=no
  elif ! offer_install claude \
       "It is what adds a marketplace and installs a plugin." \
       "curl -fsSL https://claude.ai/install.sh | bash"; then
    echo "!! Skipping plugins: no claude CLI. After installing it, re-run:" >&2
    echo "   ./install.sh --with-plugins --no-statusline --no-launcher -y" >&2
    WITH_PLUGINS=no
  fi
fi

if [ "$WITH_PLUGINS" = "yes" ]; then
  echo
  while IFS= read -r SOURCE; do
    [ -n "$SOURCE" ] || continue
    if claude plugin marketplace add "$SOURCE" >/dev/null 2>&1; then
      echo "    marketplace added    $SOURCE"
    else
      echo "    marketplace present  $SOURCE"
    fi
  done <<PLUGIN_SOURCE_LIST
$PLUGIN_SOURCES
PLUGIN_SOURCE_LIST

  # Pull the newest catalogs before reading them, so "latest" means latest.
  claude plugin marketplace update >/dev/null 2>&1 || true

  # Resolve each source to the local marketplace name Claude gave it, then list
  # the plugins that marketplace publishes. Output is "<plugin>@<marketplace>".
  PLUGIN_IDS="$(PLUGIN_SOURCES="$PLUGIN_SOURCES" CLAUDE_DEST="$DEST" python3 <<'PY'
import json, os, pathlib

dest = pathlib.Path(os.environ["CLAUDE_DEST"])
wanted = [s.strip() for s in os.environ["PLUGIN_SOURCES"].splitlines() if s.strip()]


def keys(text):
    """Comparable forms of a marketplace source: owner/repo, url, bare name."""
    text = text.strip().rstrip("/")
    if text.endswith(".git"):
        text = text[: -len(".git")]
    parts = text.split("/")
    return {text.lower(), "/".join(parts[-2:]).lower(), parts[-1].lower()}


try:
    known = json.loads((dest / "plugins" / "known_marketplaces.json").read_text())
except Exception:
    known = {}

for source in wanted:
    target = keys(source)
    for name, entry in known.items():
        spec = entry.get("source", {})
        found = keys(spec.get("repo") or spec.get("url") or name) | keys(name)
        if not (target & found):
            continue
        catalog = pathlib.Path(
            entry.get("installLocation") or dest / "plugins" / "marketplaces" / name
        ) / ".claude-plugin" / "marketplace.json"
        try:
            plugins = json.loads(catalog.read_text()).get("plugins", [])
        except Exception:
            plugins = []
        for plugin in plugins:
            plugin_name = plugin.get("name") if isinstance(plugin, dict) else plugin
            if plugin_name:
                print(f"{plugin_name}@{name}")
        break
PY
)"

  if [ -z "$PLUGIN_IDS" ]; then
    echo "!! No marketplace catalogs found; nothing installed." >&2
  fi

  while IFS= read -r PLUGIN_ID; do
    [ -n "$PLUGIN_ID" ] || continue
    if claude plugin install "$PLUGIN_ID" >/dev/null 2>&1; then
      echo "    installed  $PLUGIN_ID"
    else
      echo "    present    $PLUGIN_ID"
    fi
    INSTALLED_PLUGIN_IDS="$INSTALLED_PLUGIN_IDS$PLUGIN_ID
"
  done <<PLUGIN_ID_LIST
$PLUGIN_IDS
PLUGIN_ID_LIST

  # ECC ships hooks that stop and question edits mid-flow. They are useful on a
  # shared codebase and tiring on your own, so the ids are asked for rather than
  # assumed; an empty answer leaves every ECC hook active.
  ECC_DISABLED_HOOKS=""
  case "$INSTALLED_PLUGIN_IDS" in
    *ecc@*)
      DEFAULT_ECC_HOOKS="pre:edit-write:gateguard-fact-force,pre:read-write:gateguard-fact-force,pre:bash:gateguard-fact-force"
      if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
        ECC_DISABLED_HOOKS=""
      else
        echo
        echo "ECC's gateguard hooks interrupt before an edit, a read/write and a shell"
        echo "command to demand a cited fact first. On a solo machine that is mostly a"
        echo "nag: every third action stops for a confirmation you always give."
        echo "Listing their ids in ECC_DISABLED_HOOKS turns those three off and leaves"
        echo "the rest of ECC alone. Empty answer keeps all hooks."
        ECC_DISABLED_HOOKS="$(ask 'ECC_DISABLED_HOOKS' "$DEFAULT_ECC_HOOKS")"
      fi
      ;;
  esac

  # Record the result in settings.json: enable each plugin, turn on auto-update
  # for each marketplace, and set the two environment values the set expects.
  SETTINGS="$DEST/settings.json"
  if [ -e "$SETTINGS" ]; then
    cp -p "$SETTINGS" "$SETTINGS.backup-$STAMP"
    echo "    backed up  $SETTINGS.backup-$STAMP"
  fi
  PLUGIN_IDS="$INSTALLED_PLUGIN_IDS" PLUGIN_SOURCES="$PLUGIN_SOURCES" \
  ECC_DISABLED_HOOKS="$ECC_DISABLED_HOOKS" CLAUDE_DEST="$DEST" \
  python3 - "$SETTINGS" <<'PY'
import json, os, pathlib, sys

path = sys.argv[1]
try:
    with open(path) as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError("settings.json is not an object")
except FileNotFoundError:
    data = {}
except Exception as exc:                          # malformed file: leave it alone
    print(f"!! {path}: {exc}; enable the plugins by hand", file=sys.stderr)
    raise SystemExit(0)

ids = [i.strip() for i in os.environ["PLUGIN_IDS"].splitlines() if i.strip()]
enabled = data.setdefault("enabledPlugins", {})
for plugin_id in ids:
    enabled[plugin_id] = True

# autoUpdate lives in settings, not in the CLI, so it is written here.
dest = pathlib.Path(os.environ["CLAUDE_DEST"])
try:
    known = json.loads((dest / "plugins" / "known_marketplaces.json").read_text())
except Exception:
    known = {}
markets = data.setdefault("extraKnownMarketplaces", {})
for plugin_id in ids:
    name = plugin_id.split("@", 1)[1]
    if name == "claude-plugins-official" or name not in known:
        continue                                  # shipped with Claude Code
    entry = markets.setdefault(name, {})
    entry["source"] = known[name].get("source", entry.get("source"))
    entry["autoUpdate"] = True

env = data.setdefault("env", {})
if any(i.startswith("caveman@") for i in ids):
    env["CAVEMAN_DEFAULT_MODE"] = "ultra"
hooks = os.environ.get("ECC_DISABLED_HOOKS", "").strip()
if hooks:
    env["ECC_DISABLED_HOOKS"] = hooks

with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
print(f"    enabled {len(ids)} plugin(s), auto-update on, in {path}")
PY
fi

# ----------------------------------------------------------------- statusline

# What the statusline reads, and what each tool buys. Everything degrades: with
# none of them installed it still prints the directory, model and context.
#   jq       parses Claude's JSON properly. Without it a slower grep/sed
#            fallback runs and the context bar and cost figures are skipped.
#   git      branch name and the +added/-deleted counts for the working tree.
#   ccusage  the "Xh Ym until reset" block and its cost/token estimate. This is
#            the only figure Claude Code does not provide itself. npm package.
#   perl     only a fallback for bounding how long ccusage may take, when
#            coreutils timeout is absent.
statusline_dep_report() {
  MISSING_DEPS=""
  command -v jq >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS jq"
  command -v git >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS git"
  command -v ccusage >/dev/null 2>&1 || MISSING_CCUSAGE=yes
  command -v timeout >/dev/null 2>&1 || command -v perl >/dev/null 2>&1 || MISSING_DEPS="$MISSING_DEPS perl"
}

if [ -z "$WITH_STATUSLINE" ]; then
  if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
    WITH_STATUSLINE=no
  else
    echo
    echo "The statusline shows directory, git branch and diff counts, model, context"
    echo "remaining, session cost and burn rate under your prompt."
    ANSWER="$(ask 'Install the statusline?' 'yes')"
    case "$ANSWER" in [Nn]*) WITH_STATUSLINE=no ;; *) WITH_STATUSLINE=yes ;; esac
  fi
fi

if [ "$WITH_STATUSLINE" = "yes" ]; then
  case "$OS_KIND" in
    macos) STATUSLINE_SRC="$SRC_DIR/.claude/statusline-macos.sh" ;;
    linux) STATUSLINE_SRC="$SRC_DIR/.claude/statusline-linux.sh" ;;
    *) STATUSLINE_SRC="" ;;
  esac

  if [ -z "$STATUSLINE_SRC" ]; then
    echo "!! No statusline build for $OS_NAME; skipping." >&2
  else
    if [ -e "$DEST/statusline.sh" ] && ! cmp -s "$STATUSLINE_SRC" "$DEST/statusline.sh"; then
      cp -p "$DEST/statusline.sh" "$DEST/statusline.sh.backup-$STAMP"
      echo "    backed up  $DEST/statusline.sh.backup-$STAMP"
    fi
    cp -p "$STATUSLINE_SRC" "$DEST/statusline.sh"
    chmod +x "$DEST/statusline.sh"
    echo "    installed  $DEST/statusline.sh  ($(basename "$STATUSLINE_SRC"))"

    MISSING_DEPS=""; MISSING_CCUSAGE=""
    statusline_dep_report
    if [ -n "$MISSING_DEPS" ] || [ -n "$MISSING_CCUSAGE" ]; then
      echo
      echo "    Statusline tools not found on this machine:"
      case "$MISSING_DEPS" in *jq*) echo "      jq       parses Claude's JSON; without it the context bar and costs are skipped" ;; esac
      case "$MISSING_DEPS" in *git*) echo "      git      branch name and +added/-deleted counts" ;; esac
      case "$MISSING_DEPS" in *perl*) echo "      perl     bounds how long ccusage may run (no coreutils timeout here)" ;; esac
      [ -n "$MISSING_CCUSAGE" ] && echo "      ccusage  the 'until reset' block with its cost/token estimate (npm install -g ccusage)"
      echo "    Everything else still works without them."
    fi

    if [ -n "$MISSING_DEPS" ] && [ "$INSTALL_DEPS" != "no" ]; then
      DO_DEPS="$INSTALL_DEPS"
      if [ -z "$DO_DEPS" ]; then
        if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
          DO_DEPS=no
        else
          ANSWER="$(ask "Install$MISSING_DEPS with $PKG_MANAGER?" 'yes')"
          case "$ANSWER" in [Nn]*) DO_DEPS=no ;; *) DO_DEPS=yes ;; esac
        fi
      fi
      if [ "$DO_DEPS" = "yes" ]; then
        pkg_install $MISSING_DEPS || true
      fi
    fi

    # ccusage is an npm package, so a machine without npm needs that first.
    if [ -n "$MISSING_CCUSAGE" ] && [ "$INSTALL_DEPS" != "no" ]; then
      offer_install npm \
        "ccusage, which prints the 'until reset' block with its cost and token estimate, is an npm package." \
        "$(pkg_install_cmd npm)" npm || true
    fi

    if [ -n "$MISSING_CCUSAGE" ] && [ "$INSTALL_DEPS" != "no" ] && command -v npm >/dev/null 2>&1; then
      DO_CCUSAGE="$INSTALL_DEPS"
      if [ -z "$DO_CCUSAGE" ]; then
        if [ -n "$ASSUME_YES" ] || [ ! -t 0 ]; then
          DO_CCUSAGE=no
        else
          ANSWER="$(ask 'Install ccusage globally with npm?' 'no')"
          case "$ANSWER" in [Yy]*) DO_CCUSAGE=yes ;; *) DO_CCUSAGE=no ;; esac
        fi
      fi
      [ "$DO_CCUSAGE" = "yes" ] && npm install -g ccusage
    fi

    # Register it in settings.json, keeping whatever else is in there.
    SETTINGS="$DEST/settings.json"
    if command -v python3 >/dev/null 2>&1; then
      if [ -e "$SETTINGS" ]; then
        cp -p "$SETTINGS" "$SETTINGS.backup-$STAMP"
        echo "    backed up  $SETTINGS.backup-$STAMP"
      fi
      STATUSLINE_CMD="$DEST/statusline.sh" python3 - "$SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]
try:
    with open(path) as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError("settings.json is not an object")
except FileNotFoundError:
    data = {}
except Exception as exc:                      # malformed file: leave it alone
    print(f"!! {path}: {exc}; add statusLine by hand", file=sys.stderr)
    raise SystemExit(0)
data["statusLine"] = {"type": "command", "command": os.environ["STATUSLINE_CMD"], "padding": 0}
with open(path, "w") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
print(f"    registered statusLine in {path}")
PY
    else
      echo "!! python3 not found; add this to $SETTINGS by hand:" >&2
      echo '   "statusLine": { "type": "command", "command": "'"$DEST/statusline.sh"'" }' >&2
    fi
  fi
fi

# ------------------------------------------------------------ base settings

# Defaults a fresh machine otherwise has to be told by hand. Each one is only
# written if settings.json does not already carry it, so your own choices win.
#   includeCoAuthoredBy=false  stops Claude Code adding a Co-Authored-By trailer
#                              to commits, which the rules forbid anyway
#   effortLevel                how hard the model works by default
#   theme                      terminal colours
if command -v python3 >/dev/null 2>&1; then
  SETTINGS="$DEST/settings.json"
  if [ -e "$SETTINGS" ] && [ ! -e "$SETTINGS.backup-$STAMP" ]; then
    cp -p "$SETTINGS" "$SETTINGS.backup-$STAMP"
    echo "    backed up  $SETTINGS.backup-$STAMP"
  fi
  python3 - "$SETTINGS" <<'PY'
import json, sys

path = sys.argv[1]
try:
    with open(path) as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError("settings.json is not an object")
except FileNotFoundError:
    data = {}
except Exception as exc:                          # malformed file: leave it alone
    print(f"!! {path}: {exc}; set the defaults by hand", file=sys.stderr)
    raise SystemExit(0)

defaults = {
    "includeCoAuthoredBy": False,
    "effortLevel": "medium",
    "theme": "dark",
}
# Membership, not setdefault's return value: `False is False` is true, so a
# boolean default would report itself as newly added on every re-run.
added = [key for key in defaults if key not in data]
for key in added:
    data[key] = defaults[key]
if added:
    with open(path, "w") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
print("    defaults   " + (", ".join(added) if added else "already set"))
PY
fi

# ------------------------------------------------------------ authentication

# Installing the CLI is not the same as being signed in, and the first session
# on a fresh machine otherwise stops at a login screen with the work half done.
if command -v claude >/dev/null 2>&1; then
  if claude auth status --json 2>/dev/null | grep -q '"loggedIn": *true'; then
    echo "    claude     signed in"
  else
    echo
    echo "Claude Code is installed but not signed in. Plugins and rules are in"
    echo "place; the first session will stop at a login prompt without this."
    ANSWER="$(ask_change 'Run claude auth login now?')"
    case "$ANSWER" in
      [Nn]*) echo "    Sign in later with: claude auth login" ;;
      *) claude auth login || echo "!! Login did not complete; run: claude auth login" >&2 ;;
    esac
  fi
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo "    gh         signed in"
  else
    echo
    echo "gh is installed but not signed in. Without it Claude cannot open a pull"
    echo "request, read an issue or clone a private repository on your behalf."
    ANSWER="$(ask_change 'Run gh auth login now?')"
    case "$ANSWER" in
      [Nn]*) echo "    Sign in later with: gh auth login" ;;
      *) gh auth login || echo "!! Login did not complete; run: gh auth login" >&2 ;;
    esac
  fi
fi

# ------------------------------------------------------------ git identity

CURRENT_GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
CURRENT_GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
if [ "$CURRENT_GIT_NAME" != "$OWNER_NAME" ] || [ "$CURRENT_GIT_EMAIL" != "$OWNER_EMAIL" ]; then
  echo
  echo "Your global git identity differs from what you entered:"
  echo "    git: ${CURRENT_GIT_NAME:-(unset)} <${CURRENT_GIT_EMAIL:-(unset)}>"
  echo "    you: $OWNER_NAME <$OWNER_EMAIL>"
  # It decides the author of every commit on this machine, so it is asked about
  # rather than assumed — but an unset identity blocks committing entirely.
  ANSWER="$(ask_change 'Set it to what you entered?')"
  case "$ANSWER" in
    [Nn]*)
      echo "    Set it yourself with:"
      echo "      git config --global user.name \"$OWNER_NAME\""
      echo "      git config --global user.email \"$OWNER_EMAIL\""
      ;;
    *)
      git config --global user.name "$OWNER_NAME"
      git config --global user.email "$OWNER_EMAIL"
      echo "    git        $OWNER_NAME <$OWNER_EMAIL>"
      ;;
  esac
fi

echo
echo "==> Done. Rules are in $DEST; start Claude in a project to use them."
