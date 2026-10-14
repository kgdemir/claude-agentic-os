# React projects

> **Version-sensitive.** The pins and bundler options below were correct on
> 2026-09-24. ESLint 10 support moves; recheck
> against the current plugin docs before trusting a specific version claim here.
> The rule choices themselves (which lint rules catch render loops) do not expire.

- ESLint baseline (flat config, `--max-warnings=0`, typed linting, pins): `~/.claude/guides/tools/eslint.md`. Add the React plugins to it:
  - `eslint-plugin-react` recommended + `jsx-runtime`
  - `eslint-plugin-react-hooks` (latest, v7+) `recommended` config, incl. React Compiler rules
  - `eslint-plugin-react-refresh` (`only-export-components` warn) for Vite
  - `eslint-plugin-jsx-a11y` recommended
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
- Built with Vite: chunk grouping and `resolve.dedupe` rules in `~/.claude/guides/tools/vite.md`.
- **`key` comes from a stable id in the data, never the array index,** for any list that can reorder, insert or delete.
  *Why: an index key hands one item's state (input text, focus, open/closed) to its neighbour after a change.*
- **Data fetched in an effect is cancelled in its cleanup** (`AbortController`), or fetched through a data library (e.g. TanStack Query).
  *Why: without it a slow old response arrives after a new one and overwrites it.*
- **`dangerouslySetInnerHTML` only with sanitized HTML** (e.g. `DOMPurify.sanitize`).
  *Why: unsanitized HTML from users or APIs is a stored XSS.*
- **Public env prefixes are public.** `VITE_*`, `NEXT_PUBLIC_*` and `REACT_APP_*` values are compiled into the bundle every visitor downloads: never put a secret in one.
  *Why: anything in the bundle can be read in the browser's dev tools.*
