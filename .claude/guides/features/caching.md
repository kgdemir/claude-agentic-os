# Caching

Applies to HTTP caching, in-memory caches and distributed caches. Redis specifics (fallback when
it is down, one connection, TTLs): `~/.claude/guides/tools/redis.md`. Measure first:
`~/.claude/guides/features/performance.md`.

- **Cache only for a measured need, with a stated invalidation rule** (time-based, event-based, or both).
  *Why: a cache is a second copy of the truth; without an invalidation rule it serves stale data indefinitely.*
- **Every entry has a TTL,** even when events also invalidate it.
  *Why: a missed invalidation event otherwise leaves a wrong value forever.*
- **The key contains everything the value depends on:** tenant, user or role, culture, query parameters, and a schema version prefix (`v2:`).
  *Why: a key without the tenant serves one customer's data to another; an unversioned key makes a deploy read values in the old shape.*
- **Personal or authorised responses are never stored in shared caches:** send `Cache-Control: private` or `no-store`; `public, max-age=…` only for content that is the same for everyone.
  *Why: a CDN or proxy that caches one user's page serves it to the next user.*
- **Static assets are fingerprinted and immutable:** a content hash in the file name, served with `Cache-Control: public, max-age=31536000, immutable`; the HTML that references them is served with `no-cache`.
  *Why: a long cache on an unhashed file keeps old code in browsers after a deploy; a long cache on the HTML hides the new hashes.*
- **Support conditional requests** with `ETag` or `Last-Modified`, answering `304 Not Modified`.
  *Why: clients revalidate cheaply instead of downloading unchanged data.*
- **Protect against a stampede:** on a miss, one caller rebuilds the value while the others wait or get the stale one (.NET `HybridCache`, a lock per key, single-flight).
  *Why: when a hot key expires, every concurrent request otherwise hits the database at once.*
- **A cache failure falls back to the source and is logged;** it never fails the request or pretends success.
  *Why: the cache is an optimisation; an outage of it must cost speed, not correctness.*
- **Track the hit rate.**
  *Why: a cache with a low hit rate costs memory and complexity and saves nothing.*
