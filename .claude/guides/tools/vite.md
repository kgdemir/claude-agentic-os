# Vite

> **Version-sensitive.** Correct on 2026-09-24. Rolldown's option names move; recheck against
> the current Vite docs before trusting a specific option name. Why chunks are grouped does not
> expire.

Applies to any project built with Vite. Group names below assume React; for another framework,
swap the runtime group and keep the rest.

- **Always** split build output into named vendor/feature chunks, never one giant bundle.
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
