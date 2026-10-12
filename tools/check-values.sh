#!/usr/bin/env bash
# Fails when README.md or the working-rules guide quotes a settings value that
# no longer matches install.sh, the single source for those values. Docs cannot
# read a shell variable, so this check is what keeps them in step.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

INSTALLER="install.sh"
README="README.md"
GUIDE=".claude/guides/agent-working-rules.md"
TOKENS_PER_K=1000

value_of() { # value_of <NAME>: the quoted value assigned to NAME in install.sh
  local line
  line="$(grep -E "^$1=\"[^\"]*\"$" "$INSTALLER")" || {
    echo "!! $INSTALLER: no $1=\"...\" line" >&2
    exit 1
  }
  line="${line#*=\"}"
  printf '%s\n' "${line%\"}"
}

TTL="$(value_of SUBAGENT_CACHE_TTL)"
WINDOW="$(value_of AUTO_COMPACT_WINDOW)"

FAILED=0
expect() { # expect <file> <fixed string>
  if ! grep -qF -- "$2" "$1"; then
    echo "!! $1 does not contain: $2" >&2
    FAILED=1
  fi
}

expect "$README" "| \`subagentPromptCacheTtl\` | \`$TTL\` |"
expect "$README" "| \`env.CLAUDE_CODE_AUTO_COMPACT_WINDOW\` | \`$WINDOW\` |"
expect "$README" "compacting at $((WINDOW / TOKENS_PER_K))k tokens"
expect "$GUIDE" "sets \`subagentPromptCacheTtl\` to \`$TTL\`"

if [ "$FAILED" -ne 0 ]; then
  echo "Docs quote values that differ from $INSTALLER (TTL=$TTL, window=$WINDOW)." >&2
  exit 1
fi
echo "values ok: subagentPromptCacheTtl=$TTL, CLAUDE_CODE_AUTO_COMPACT_WINDOW=$WINDOW"
