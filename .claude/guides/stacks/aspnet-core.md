# ASP.NET Core

Applies to ASP.NET Core web apps and APIs (MVC/Razor, minimal APIs, controllers). Base .NET rules:
`~/.claude/guides/stacks/dotnet.md`. Login, tokens and outbound URLs: `~/.claude/guides/features/auth.md`.

- **Antiforgery reaches every client transport.** With a global `AutoValidateAntiforgeryToken` filter on cookie auth, every way the browser posts — your own `fetch` wrapper, jQuery `$.ajax`, a UI library's internal grid or upload transport, plain forms — must send the token. Cover jQuery once with `$.ajaxSetup({ beforeSend })`, and add a global `ajaxError` handler so a refused call is visible.
  *Cost: every data-grid POST failed with 400 because only the app's own fetch helper sent the header; the grid's built-in jQuery transport never did, and the failure was silent.*
- **An error response must still pass through CORS.** An exception that escapes to the server's default 500 goes out without `Access-Control-Allow-Origin`, and the browser reports a CORS / "Failed to fetch" error instead of the real one. Handle exceptions with `UseExceptionHandler` + `ProblemDetails` (placed so CORS still runs) or catch at the endpoint and return a normal error result; log the cause server-side.
  *Cost: a missing ffmpeg on the server showed up in the browser as a CORS error, sending the diagnosis to the wrong layer.*
- **A repeated idempotent request is refused, not replayed.** With an `Idempotency-Key`, a repeat of a pending or completed request returns `409` with a clear message; replaying the first success makes every double-click look like a new save.
  *Cost: four clicks on Save created one row and showed four "saved" messages.*
- **Deploys never overwrite the server's own config.** Exclude `appsettings.json` / `appsettings.<Environment>.json` from `rsync --delete` or copy steps that push publish output, and say in the script what it keeps.
  *Cost: every publish silently replaced a hand-corrected production config with the repo's copy, while the script printed "keeping live appsettings".*
- **Authenticated by default.** Set a fallback authorization policy (`RequireAuthenticatedUser`) and mark public endpoints with `[AllowAnonymous]` explicitly.
  *Why: otherwise every new endpoint is public until someone remembers the attribute.*
- **Errors use `ProblemDetails`** (`AddProblemDetails`, RFC 9457 shape); no stack traces outside Development.
  *Why: one error shape lets clients show real messages; a stack trace in production tells an attacker the internals.*
- **Secrets stay out of `appsettings*.json`** in the repo: user secrets in development, environment variables or a vault in production.
  *Why: `appsettings.json` is committed and copied into every publish folder.*
