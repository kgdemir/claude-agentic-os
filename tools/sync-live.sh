#!/usr/bin/env bash
# Brings the live Claude Code folder up to date with this checkout without
# running the full installer on it (ADR-0010). It renders the pack into a
# temporary folder with the person's own install answers, then copies over
# only the files that differ: CLAUDE.md, guides, templates and hook scripts.
# Each replaced file is backed up first. settings.json is never touched; a
# hook that is not registered there yet is reported, with the command to fix it.
#
# Install answers come from tools/sync-live.local (gitignored), one install.sh
# argument per line, for example:
#   --language
#   English
#   --name
#   Jane Doe
# Usage: tools/sync-live.sh [--dry-run]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

LIVE="${CLAUDE_HOME:-$HOME/.claude}"
LOCAL_CONFIG="tools/sync-live.local"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=no
case "${1:-}" in
  "") ;;
  --dry-run) DRY_RUN=yes ;;
  *) echo "usage: tools/sync-live.sh [--dry-run]" >&2; exit 2 ;;
esac

if [ ! -f "$LOCAL_CONFIG" ]; then
  echo "!! $LOCAL_CONFIG is missing; put your install.sh arguments there, one per line" >&2
  exit 1
fi
ARGS=()
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ""|"#"*) continue ;; esac
  ARGS+=("$line")
done < "$LOCAL_CONFIG"

RENDER="$(mktemp -d)"
trap 'rm -rf "$RENDER"' EXIT
# ${ARGS[@]+...}: macOS bash 3.2 treats an empty array as unset under set -u.
if ! CLAUDE_HOME="$RENDER" ./install.sh -y ${ARGS[@]+"${ARGS[@]}"} \
    --no-plugins --no-launcher --no-statusline --no-deps </dev/null >"$RENDER/install.log" 2>&1; then
  cat "$RENDER/install.log" >&2
  echo "!! render failed; live folder not touched" >&2
  exit 1
fi

changed=0
while IFS= read -r rel; do
  src="$RENDER/$rel" dst="$LIVE/$rel"
  if [ -e "$dst" ] && cmp -s "$src" "$dst"; then
    continue
  fi
  changed=$((changed + 1))
  if [ "$DRY_RUN" = yes ]; then
    echo "would update  $rel"
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ]; then
    cp -p "$dst" "$dst.backup-$STAMP"
    echo "updated  $rel  (old copy: $rel.backup-$STAMP)"
  else
    echo "added    $rel"
  fi
  cp -p "$src" "$dst"
done < <(cd "$RENDER" && { echo CLAUDE.md; find guides templates -type f -name '*.md'; find hooks -type f -name '*.py'; } | sort)

# Files the pack no longer ships: reported, never deleted.
while IFS= read -r rel; do
  [ -e "$RENDER/$rel" ] || echo "no longer in the pack (delete by hand if unused)  $rel"
done < <(cd "$LIVE" && find guides templates -type f -name '*.md' 2>/dev/null | sort)

# Hooks need a settings.json entry, which only install.sh writes.
for hook in "$RENDER"/hooks/*.py; do
  name="$(basename "$hook")"
  if ! grep -qF "hooks/$name" "$LIVE/settings.json" 2>/dev/null; then
    echo "not registered in settings.json  hooks/$name  (run ./install.sh to register it)"
  fi
done

if [ "$changed" -eq 0 ]; then
  echo "live folder already matches the pack"
elif [ "$DRY_RUN" = yes ]; then
  echo "$changed file(s) would change; nothing written"
else
  echo "$changed file(s) updated in $LIVE"
fi
