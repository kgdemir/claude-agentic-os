#!/usr/bin/env python3
"""SessionStart hook: warn when an enabled LSP plugin's language server program
is not on PATH, or cannot find the library it drives.

An LSP plugin only names the server program (`lspServers.<name>.command`); the
program itself is installed separately. Without it the `LSP` tool has nothing to
ask, and every code lookup falls back to grep without anyone noticing (see
guides/tools/lsp.md).

Warn-only and silent when every server is found. Reads the user's settings.json
for enabled plugins, and each plugin's `lspServers` from its marketplace entry,
its `.claude-plugin/plugin.json` and its `.lsp.json`.
"""
import json
import os
import pathlib
import shutil
import sys

PLUGIN_MANIFEST = pathlib.Path(".claude-plugin") / "plugin.json"
LSP_FILE = ".lsp.json"
MARKETPLACE_MANIFEST = pathlib.Path(".claude-plugin") / "marketplace.json"
GUIDE = "~/.claude/guides/tools/lsp.md"
# Servers that drive a library found next to them, and the file they load from
# it. typescript-language-server runs TypeScript's tsserver, which TypeScript 7
# (the native port) no longer ships, so a server installed beside TypeScript 7
# starts and then fails with "Could not find a valid TypeScript installation".
NEEDS_BESIDE = {"typescript-language-server": pathlib.Path("node_modules") / "typescript" / "lib" / "tsserver.js"}


def config_dir() -> pathlib.Path:
    return pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or pathlib.Path.home() / ".claude")


def load(path: pathlib.Path):
    """JSON from path, or None when it is absent. A malformed file is reported."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as exc:
        print(f"check-lsp-servers: {path}: {exc}", file=sys.stderr)
        return None


def server_entries(servers, base: pathlib.Path) -> list:
    """(command, file extensions) for each server in an `lspServers` value: an
    object, or a path to a JSON file."""
    if isinstance(servers, str):
        servers = load(base / servers)
    if not isinstance(servers, dict):
        return []
    entries = []
    for server in servers.values():
        if isinstance(server, dict) and isinstance(server.get("command"), str):
            languages = server.get("extensionToLanguage")
            extensions = frozenset(languages) if isinstance(languages, dict) else frozenset()
            entries.append((server["command"], extensions))
    return entries


def marketplace_entry(config: pathlib.Path, market: str, plugin: str) -> dict:
    known = load(config / "plugins" / "known_marketplaces.json") or {}
    entry = known.get(market) if isinstance(known, dict) else None
    location = entry.get("installLocation") if isinstance(entry, dict) else None
    root = pathlib.Path(location) if location else config / "plugins" / "marketplaces" / market
    catalog = load(root / MARKETPLACE_MANIFEST) or {}
    plugins = catalog.get("plugins", []) if isinstance(catalog, dict) else []
    for item in plugins:
        if isinstance(item, dict) and item.get("name") == plugin:
            return item
    return {}


def install_paths(config: pathlib.Path, plugin_id: str) -> list:
    installed = load(config / "plugins" / "installed_plugins.json") or {}
    plugins = installed.get("plugins") if isinstance(installed, dict) else None
    records = plugins.get(plugin_id) if isinstance(plugins, dict) else None
    if not isinstance(records, list):
        return []
    return [pathlib.Path(r["installPath"]) for r in records
            if isinstance(r, dict) and isinstance(r.get("installPath"), str)]


def finds_beside(program: str, needed: pathlib.Path, workspace: str) -> bool:
    """True when `needed` sits in the project, or in a folder above the program's real file."""
    if workspace and (pathlib.Path(workspace) / needed).is_file():
        return True
    real = pathlib.Path(os.path.realpath(program))
    return any((folder / needed).is_file() for folder in real.parents)


def server_states(config: pathlib.Path, workspace: str = "") -> list:
    """(plugin id, command, file extensions, problem or None, readme or None) for
    each language server an enabled plugin names; problem is None when it can start.
    check-symbol-search.py reads this too."""
    settings = load(config / "settings.json") or {}
    enabled = settings.get("enabledPlugins", {}) if isinstance(settings, dict) else {}
    if not isinstance(enabled, dict):
        return []
    states = []
    for plugin_id, on in sorted(enabled.items()):
        if on is not True or "@" not in plugin_id:
            continue
        plugin, market = plugin_id.split("@", 1)
        paths = install_paths(config, plugin_id)
        entry_servers = marketplace_entry(config, market, plugin).get("lspServers")
        # A path in the catalog entry is relative to the plugin, like one in its manifest.
        entries = [] if isinstance(entry_servers, str) else server_entries(entry_servers, config)
        for path in paths:
            if isinstance(entry_servers, str):
                entries += server_entries(entry_servers, path)
            manifest = load(path / PLUGIN_MANIFEST) or {}
            if isinstance(manifest, dict):
                entries += server_entries(manifest.get("lspServers"), path)
            entries += server_entries(load(path / LSP_FILE), path)
        readme = next((p / "README.md" for p in paths if (p / "README.md").is_file()), None)
        extensions = {}
        for command, found in entries:
            extensions[command] = extensions.get(command, frozenset()) | found
        for command, served in extensions.items():
            program = shutil.which(command)
            needed = NEEDS_BESIDE.get(command)
            problem = None
            if program is None:
                problem = "is not on PATH"
            elif needed and not finds_beside(program, needed, workspace):
                problem = (f"at {os.path.realpath(program)} has no `{needed.relative_to('node_modules')}` "
                           "beside it (TypeScript 7 ships none; install TypeScript 6 next to the server)")
            states.append((plugin_id, command, served, problem, readme))
    return states


def missing_servers(config: pathlib.Path, workspace: str = "") -> list:
    """(plugin id, command, problem, readme or None) for each server that cannot start."""
    return [(plugin_id, command, problem, readme)
            for plugin_id, command, _, problem, readme in server_states(config, workspace)
            if problem is not None]


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except ValueError:
        event = {}
    cwd = event.get("cwd") if isinstance(event, dict) else None
    missing = missing_servers(config_dir(), cwd if isinstance(cwd, str) else "")
    if not missing:
        return 0
    lines = []
    for plugin_id, command, problem, readme in missing:
        how = f" Its install command is in {readme}." if readme else ""
        lines.append(f"`{plugin_id}` is enabled but its language server `{command}` {problem}.{how}")
    note = (
        " ".join(lines) + " The `LSP` tool cannot answer for those languages this session. "
        "Tell the user now and offer the install (a new session picks it up); until then, say "
        f"that grep results are text matches, not resolved references ({GUIDE})."
    )
    json.dump(
        {"systemMessage": " ".join(lines),
         "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": note}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
