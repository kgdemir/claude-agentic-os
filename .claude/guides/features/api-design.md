# HTTP API design

Applies to projects that expose an HTTP API (REST, JSON over HTTP, OpenAPI). Framework specifics
(antiforgery, `ProblemDetails`, idempotency in ASP.NET Core): `~/.claude/guides/stacks/aspnet-core.md`.

- **The OpenAPI document is the contract.** Generate it from the code or write it first, commit it (`openapi.json` / `openapi.yaml`), and review its diff with every API change.
  *Why: an API without a reviewed contract changes shape by accident, and clients find out in production.*
- **Breaking changes fail CI.** Compare the committed contract with the base branch (`oasdiff breaking base.yaml head.yaml --fail-on ERR`) and require an explicit version bump to pass.
  *Why: removing a field or tightening a type looks harmless in a diff and breaks every client that used it.*
- **Additive changes need no new version; breaking ones do.** Version in the path (`/v2/…`) or a header, keep the old version working for a stated period, and announce removal with `Deprecation` and `Sunset` headers.
  *Why: clients upgrade on their own schedule; removing a version without notice is an outage for them.*
- **Return DTOs, never database entities.** Map explicitly; ids are opaque to clients.
  *Why: an exposed entity leaks internal fields (hashes, flags) and freezes the schema into the public contract.*
- **Status codes mean what HTTP says:** `201` + `Location` on create, `204` on empty success, `400` malformed request, `401` not signed in, `403` not allowed, `404` missing, `409` state conflict, `412` failed precondition (`If-Match`), `422` valid syntax but rejected input, `429` rate-limited. One error body shape everywhere (RFC 9457 problem details).
  *Why: clients branch on status codes; a `200` carrying an error, or a different error shape per endpoint, makes every client special-case each call.*
- **Every list is paginated with a maximum page size.** Prefer cursor (keyset) pagination for growing or frequently changing data; offset pagination only for small, stable sets.
  *Why: an unbounded list grows until it times out; offset pages skip or repeat rows when data changes between requests.*
- **Sorting and filtering use an allow-list of fields.**
  *Why: passing a client field name straight into a query is an injection vector and lets clients sort on unindexed columns.*
- **Dates are ISO 8601 with an offset, in UTC** (`2026-10-15T08:30:00Z`).
  *Why: a date without an offset is read in whatever time zone the client is in.*
- **Unsafe retries are made safe.** `PUT` and `DELETE` are idempotent by design; a `POST` that creates something accepts an `Idempotency-Key`.
  *Why: networks retry; without it, one user action can create two orders.*
- **Concurrent edits use optimistic concurrency** (`ETag` + `If-Match`, or a version field), answered with `412` or `409` on conflict.
  *Why: last-write-wins silently discards another user's change.*
