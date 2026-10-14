# Frontend testing (Vitest, Testing Library, Playwright)

Applies to web front-ends tested with Vitest or Jest, Testing Library, jsdom, or Playwright.

- **CI runs the same Node major as development and production,** and a test that needs a browser API (Web Locks, `BroadcastChannel`, IndexedDB) skips explicitly when the runtime lacks it instead of falling through to another code path.
  *Cost: CI on an older Node had no `navigator.locks`; the Web Locks tests silently exercised the fallback path and one hung until timeout, waiting for an event nothing sent.*
- **The DOM environment is scoped:** `jsdom` (or `happy-dom`) only for the test files that need it, via a per-file environment comment or config glob.
  *Why: a global DOM environment slows every test and hides code that wrongly depends on `window`.*
- **Query by what the user sees:** `getByRole`, `getByLabelText`, `getByText`, not CSS classes or test ids, unless nothing visible identifies the element.
  *Why: tests tied to markup break on every refactor and still miss inaccessible UI.*
- **No snapshot-only tests.** A snapshot may accompany explicit assertions, never replace them.
  *Why: a large snapshot gets re-accepted without being read, so it asserts nothing.*
