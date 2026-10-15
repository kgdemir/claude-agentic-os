#!/usr/bin/env bash
# Every gate that must pass before a commit, in one run; CI calls this same
# script. Stops at the first failing gate.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

step() { echo "== $*"; }

step "shell syntax"
for script in install.sh tools/*.sh .claude/statusline-*.sh .claude/bin/runclaude; do
  bash -n "$script"
done

step "hook syntax"
# compile() instead of py_compile, so no __pycache__ is left in the pack.
python3 -I -c 'import sys
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        compile(fh.read(), path, "exec")' .claude/hooks/*.py

step "settings values quoted in docs"
tools/check-values.sh

step "hooks"
tools/test-hooks.sh

step "guides"
tools/check-guides.sh

step "trial install"
TRIAL="$(mktemp -d)"
trap 'rm -rf "$TRIAL"' EXIT
CLAUDE_HOME="$TRIAL" ./install.sh -y --language English --name "Trial Owner" --github trial \
  --email trial@example.com --project-root "$TRIAL/projects" --with-project-location \
  --no-plugins --no-launcher --no-statusline --no-deps </dev/null >"$TRIAL/install.log" 2>&1 || {
  cat "$TRIAL/install.log" >&2
  echo "!! trial install failed" >&2
  exit 1
}
if grep -rlE '\{\{[A-Z_]+\}\}' "$TRIAL" --include='*.md'; then
  echo "!! placeholders left unfilled in the files above" >&2
  exit 1
fi
echo "all gates passed"
