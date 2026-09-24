# React projects

> **Version-sensitive.** The pins and bundler options below were correct on
> 2026-09-24. ESLint 10 support and Rolldown's option names both move; recheck
> against the current plugin docs before trusting a specific version claim here.
> The rule choices themselves (which lint rules catch render loops, why chunks
> are grouped) do not expire.

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
- Build chunk grouping (Vite): always split output into named vendor/feature chunks, never one giant bundle.
  - Vite on Rolldown (Vite 8+ / `rolldown-vite`): `build.rolldownOptions.output.codeSplitting` (older `rolldown-vite`: `advancedChunks`; check docs via context7). Older Rollup Vite: `build.rollupOptions.output.manualChunks` function with same grouping.
  - `resolve.dedupe: ['react', 'react-dom']` so React stays single instance.
  - Only add vendor groups for packages actually in `package.json`. Feature groups follow real `src/` folders.
  - Reference template (adapt, higher priority wins):
    ```js
    codeSplitting: {
      groups: [
        // React runtime (plus scheduler) in one group; keeps `dedupe` single-instance obvious.
        { name: 'vendor-react', test: /node_modules\/(react|react-dom|scheduler)\//, priority: 100 },
        { name: 'vendor-router', test: /node_modules\/react-router/, priority: 90 },
        { name: 'vendor-tanstack', test: /node_modules\/@tanstack/, priority: 90 },
        { name: 'vendor-other', test: /node_modules/, priority: 10 },
        // App code; everything else falls to entry chunk.
        { name: 'features', test: /\/src\/features\//, priority: 40 },
        { name: 'app-shared', test: /\/src\/shared\//, priority: 30 },
      ],
    },
    ```
  - Budget: `build.chunkSizeWarningLimit` (e.g. 500 KB) reports an oversized chunk. Do not set `maxSize` on every group: it splits even small groups into many fragments. Use `maxSize` only on a group you deliberately split (e.g. `vendor-other`).
  - New heavy dependency (>~100 KB) added: add its own `vendor-*` group. New big feature folder: add `feature-*` group.
  - Single package still exceeds the chunk budget inside its own `vendor-*` group: split it into sub-groups by sub-path or sub-package (`vendor-<pkg>-core`, `vendor-<pkg>-<part>`), higher priority than the parent group. Same for an oversized `feature-*` group: split by sub-folder. Parts only used by lazy routes: load them with dynamic `import()` instead.
  - `tools/build.sh` prints chunk sizes after build. Vite chunk size warning: fix grouping / lazy-load (`React.lazy`), don't just raise the limit.
- Add missing packages as devDependencies. Add `"lint": "eslint ."` script to `package.json`.
- `tools/lint.sh` runs lint. `tools/build.sh` runs lint (and tests if present) before `npm run build`.
