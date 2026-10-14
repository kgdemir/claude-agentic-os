# ESLint

> **Version-sensitive.** The pins below were correct on 2026-09-24. ESLint 10 support moves;
> recheck against the current plugin docs before trusting a specific version claim here.

Applies to any JavaScript or TypeScript project linted with ESLint. Framework plugins live in
their stack guide (React: `~/.claude/guides/stacks/react.md`).

- Ensure a flat `eslint.config.js` with the widely used baseline (create or merge, never drop user rules):
  - `@eslint/js` recommended
  - `typescript-eslint` recommended (TS projects)
  - `eslint-plugin-import` (`import/no-duplicates`, `import/order`)
  - Pin `eslint@^9` / `@eslint/js@^9` only while a plugin the project uses lacks ESLint 10 support: `eslint-plugin-import` did not have it (checked 2026-09-24); React plugins: `~/.claude/guides/stacks/react.md`.
  - `globals.browser` (browser code) or `globals.node` (Node code), ignore `dist`, `build`, `coverage`, `node_modules`
- **`--max-warnings=0` in the lint script** (`"lint": "eslint . --max-warnings=0"`).
  *Why: ESLint exits 0 on warnings, so without it every warning passes CI and they pile up unseen.*
- **Typed linting in TS projects.** Use `typescript-eslint`'s `recommendedTypeChecked` with `parserOptions.projectService: true`, and keep `@typescript-eslint/no-floating-promises` and `@typescript-eslint/no-misused-promises` at `error`.
  *Why: an un-awaited promise drops its error silently; only type-aware rules can see it.*
- **Prettier in use: `eslint-config-prettier` goes last** in the config array.
  *Why: otherwise ESLint style rules and Prettier rewrite each other's output, and lint fails on formatted code.*
- **Never run `eslint --fix` over the whole repository as a side effect.** Fix the files the task touches (core rule: change only what was asked).
  *Why: a repo-wide fix buries the real change under hundreds of unrelated lines.*
- No `eslint-disable` comments without approval: fix the cause; a genuinely needed disable follows the core rule (ask first, reason in a comment above it).
- Rule name missing in installed plugin version: upgrade plugin, don't drop rule silently.
- Add missing packages as devDependencies.
- `tools/lint.sh` runs lint. `tools/build.sh` runs lint (and tests if present) before `npm run build`.
