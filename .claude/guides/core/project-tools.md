# Project Tools Scripts

- Applies whenever user creates/opens a project and asks to build, compile, test, lint, run, publish, deploy, clean, migrate, or similar repeatable operation.
- **NEVER** run those commands ad hoc each time. Use scripts under `{{PROJECT_ROOT}}/<project-name>/tools/`:
  1. `tools/` missing: create it first.
  2. Needed script missing: create it (e.g. `tools/build.sh`, `tools/test.sh`, `tools/publish.sh`, `tools/deploy.sh`, `tools/run.sh`, `tools/lint.sh`). `#!/usr/bin/env bash`, `set -euo pipefail`, `cd` to project root from script location, `chmod +x`.
  3. Run the script, not the raw commands.
- Script exists: reuse it. Update it only when user asks, or when it is broken/outdated for the requested operation (say what changed).
- Proactively suggest:
  - A repeated or multi-step manual operation could become a script: name it, e.g. "add this as `tools/seed-db.sh`?".
  - An existing script could do more automatically (e.g. restore deps, run tests, lint before build, clean old output): suggest the update.
- Suggestions go through `AskUserQuestion` selector.
