# Web security (headers, browser-facing APIs)

Applies to projects that serve HTML or an API called from a browser. Login, tokens, SSRF and
cookies: `~/.claude/guides/features/auth.md`. Antiforgery: `~/.claude/guides/stacks/aspnet-core.md`.
Which security review or audit tool to run: `~/.claude/guides/tools/skills.md`.

- **HTTPS only, with HSTS:** redirect HTTP to HTTPS and send `Strict-Transport-Security: max-age=31536000` (add `includeSubDomains` only after every subdomain serves HTTPS).
  *Why: without HSTS, the first plain-HTTP request can be intercepted and downgraded.*
- **A Content Security Policy without `'unsafe-inline'` scripts.** Use nonces or hashes for inline scripts; roll out with `Content-Security-Policy-Report-Only` first, then enforce.
  *Why: CSP is the layer that stops an XSS bug from running script; `'unsafe-inline'` turns it off.*
- **Baseline headers on every response:** `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `frame-ancestors 'none'` in CSP (or `X-Frame-Options: DENY`), and a `Permissions-Policy` that turns off unused features. Do not add the obsolete `X-XSS-Protection`.
  *Why: each closes a known browser attack (MIME sniffing, referrer leaks, clickjacking) at no cost.*
- **CORS lists exact origins.** Never reflect the request's `Origin` back, and never combine a wildcard with credentials.
  *Why: a reflected origin with credentials lets any site read the user's data with their cookies.*
- **Output is encoded for its context** (HTML, attribute, URL, JavaScript); user HTML is sanitised with an allow-list sanitiser (DOMPurify, `HtmlSanitizer`).
  *Why: input validation alone cannot know where a value will end up; encoding at output can.*
- **Uploads are checked by content, size-limited, renamed and stored outside the web root;** served with `Content-Disposition: attachment` unless they are meant to display.
  *Why: a trusted file name or extension lets an uploaded HTML or script file run on your origin.*
- **Third-party scripts from a CDN carry Subresource Integrity** (`integrity="sha384-…"` with `crossorigin`), or are self-hosted.
  *Why: a compromised CDN otherwise serves its code with your origin's full access.*
- **Walk the OWASP Top 10 for each new feature:** broken access control (`~/.claude/guides/features/auth.md`, hub checks in `~/.claude/guides/features/realtime-media.md`), injection (parameterised SQL in `~/.claude/guides/stacks/dotnet-ef-core.md` and `~/.claude/guides/tools/sql-server.md`, LDAP escaping in `~/.claude/guides/features/auth.md`), SSRF (`~/.claude/guides/features/auth.md`), vulnerable dependencies (`~/.claude/guides/tools/dependency-updates.md`), logging failures (`~/.claude/guides/features/observability.md`).
  *Why: a checklist keeps the common classes from being skipped when attention is on the feature itself.*
