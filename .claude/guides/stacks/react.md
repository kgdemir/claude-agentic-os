# React projects

> **Version-sensitive.** The pins and bundler options below were correct on
> 2026-09-24. ESLint 10 support moves; recheck
> against the current plugin docs before trusting a specific version claim here.
> The rule choices themselves (which lint rules catch render loops) do not expire.

- Ensure a flat `eslint.config.js` with the widely used baseline (create or merge, never drop user rules):
  - `@eslint/js` recommended
  - `typescript-eslint` recommended (TS projects)
  - `eslint-plugin-react` recommended + `jsx-runtime`
  - `eslint-plugin-react-hooks` (latest, v7+) `recommended` config, incl. React Compiler rules
  - `eslint-plugin-react-refresh` (`only-export-components` warn) for Vite
  - `eslint-plugin-jsx-a11y` recommended
  - `eslint-plugin-import` (`import/no-duplicates`, `import/order`)
  - Pin `eslint@^9` / `@eslint/js@^9` until `eslint-plugin-react`, `eslint-plugin-jsx-a11y`, `eslint-plugin-import` support ESLint 10 (checked 2026-09-24).
  - `globals.browser`, ignore `dist`, `build`, `coverage`, `node_modules`
- Render-loop / re-render guards, always `error` (override preset levels):
  - `react-hooks/rules-of-hooks`
  - `react-hooks/exhaustive-deps` (missing or unstable deps: effect re-runs forever)
  - `react-hooks/set-state-in-render` (setState during render: infinite render loop)
  - `react-hooks/set-state-in-effect` (sync setState in effect: extra render / loop)
  - `react-hooks/static-components` (component defined in render: remount every render)
  - `react-hooks/immutability`, `react-hooks/refs`, `react-hooks/purity`
  - `react/no-unstable-nested-components`
  - `react/jsx-no-constructed-context-values` (new object in Context `value`: all consumers re-render)
  - `react/no-object-type-as-default-prop` (`{}`/`[]` default prop: new ref each render, breaks deps)
- Never disable these with `eslint-disable` comments. Fix the cause (`useMemo`, `useCallback`, move object outside component, derive state instead of syncing it in effect).
- Rule name missing in installed plugin version: upgrade plugin, don't drop rule silently.
- Built with Vite: chunk grouping and `resolve.dedupe` rules in `~/.claude/guides/tools/vite.md`.
- Add missing packages as devDependencies. Add `"lint": "eslint ."` script to `package.json`.
- `tools/lint.sh` runs lint. `tools/build.sh` runs lint (and tests if present) before `npm run build`.
