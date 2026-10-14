# Authentication and request security

Applies to projects with login, tokens or sessions, directory (LDAP/AD) lookups, or code that fetches
URLs a user or another system supplied. Logging of tokens: `~/.claude/guides/features/observability.md`.

- **A user-supplied URL is checked on every hop.** Follow redirects by hand and re-check each hop and each derived link (scheme `https`, public host, no private, loopback or link-local address after DNS resolution) — not only the first request. Prefer an allow-list of hosts when the set is known.
  *Cost: a fetcher checked only the first URL, so a redirect could still lead it to an internal address (SSRF).*
- **Tokens travel in headers,** never in URLs, except where a protocol forces it (WebSocket); then keep them out of logs.
  *Cost: see the observability guide — tokens in query strings ended up in a browser console and an access log.*
- **JWTs are validated fully:** issuer, audience, lifetime and signing key; short-lived access tokens with refresh, and a way to revoke (disabled user, logout everywhere).
  *Why: a token that is only signature-checked stays valid for its whole lifetime after the user is disabled.*
- **Login is rate-limited per account and per IP.**
  *Why: per-IP alone lets a botnet guess one password; per-account alone lets one IP try every account.*
- **LDAP filters escape user input** (RFC 4515: `*`, `(`, `)`, `\`, NUL).
  *Why: an unescaped `*` or `)(` changes the filter, which is LDAP injection.*
- **Session and auth cookies are `HttpOnly`, `Secure` and `SameSite=Lax` or `Strict`;** cookie auth also needs antiforgery (`~/.claude/guides/stacks/aspnet-core.md`).
  *Why: script-readable or cross-site cookies turn any XSS or CSRF into account takeover.*
