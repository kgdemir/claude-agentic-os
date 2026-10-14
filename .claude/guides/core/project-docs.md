# Project Documentation Files

- Every project has `README.md`, `capabilities.md`, `SECURITY.md` at project root. On create/open: missing one, create it from the real code (never invent facts; unknown item: write `TODO:`).
- Update them only when the user asks; after a code change, name the doc that would need a line and stop. Workflow: `~/.claude/guides/core/docs-updates.md`.
- Style: plain factual English, exact identifiers in backticks (paths, routes, types, config keys, commands). State the reason for non-obvious decisions. Reference ADRs when they exist. No marketing words.

## README.md

- One-paragraph summary: what the product is, who uses it, main features, where it is served.
- Architecture table: layer, project/folder, responsibility. One line naming the solution or workspace file.
- Stack: per layer with major versions and key build flags (the stack guide names them), state management approach, notable libraries.
- Commands: dev, build, lint, test, run per part, pointing to `tools/` scripts. Note platform-specific build limits.
- Quality gates that must pass before commit (warnings as errors, lint with zero warnings, no lint-disable comments, tests, contract checks; the stack guide names the exact flags).
- Documentation section linking `capabilities.md`, `SECURITY.md`, ADRs, user guide, tools/PoCs, `CLAUDE.md`.

## capabilities.md

- Overview: purpose, target users, domains/hosts, what is out of scope.
- Tech stack: each component the project actually has (backend, frontend, auth, database/ORM, background services, deploy, …) with versions and the decision behind it.
- Feature-specific sections (realtime/media, AI/ML models, …): see the matching `features/` guide.
- API / routes grouped by area: method + path + one-line behavior, plus auth rule, limits, error codes, and non-obvious rules.
- Data models: table of entity + key fields, then relationships list.
- Auth & permissions: authentication, token, roles, authorization gates, session revocation, CORS, dev-only fakes.
- UI / pages: modules, main screens, notable UX behavior.
- Features & business logic: one bullet per feature, behavior plus the edge cases and why.
- Footer: `<!-- DOC-BASELINE: ... -->` marker + `_Documentation baseline: current as of commit <hash> (<date>)_` with the `git log --oneline <hash>..HEAD` command to refresh it.

## SECURITY.md

- Supported versions table (which branch/build gets fixes).
- Reporting a vulnerability: private channel only, contact, what to include, acknowledgement time.
- Security posture: authentication, authorization, transport encryption, secrets handling (never commit credentials, keys, connection strings), dependency policy.
- Dependency & supply chain: automated update tool, review and CI gate per bump, extra smoke test for major bumps.
