# TypeScript

Applies to any project with a `tsconfig.json`. Lint rules: `~/.claude/guides/tools/eslint.md`.
Preventive rules: each one names the failure it stops (*Why*).

- **`strict: true` and `noUncheckedIndexedAccess: true`** in `tsconfig.json`.
  *Why: without them `null`, `undefined` and missing array or record entries type-check as present and fail at runtime.*
- **Type-check is its own gate: `tsc --noEmit`** (or `tsc -b` with project references) runs in `tools/build.sh` and CI, before the bundler.
  *Why: Vite, esbuild and SWC strip types without checking them, so a type error builds green.*
- **No `any`, no `@ts-ignore`, no `!` to silence an error.** Use `unknown` and narrow it. A genuinely needed `@ts-expect-error` follows the core lint-disable rule: ask first, reason in a comment above it.
  *Why: each one switches the checker off exactly where it disagrees with the code.*
- **Validate data from outside the program at runtime** (HTTP responses, `JSON.parse`, `localStorage`, environment variables, messages), with a schema library such as `zod` or a hand-written guard, before typing it.
  *Why: types do not exist at runtime; a cast on unvalidated data is a claim nothing checks.*
