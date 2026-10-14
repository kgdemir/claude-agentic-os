# Redis

Applies to projects that use Redis (StackExchange.Redis, `redis-py`, ioredis) as a cache, lock or queue.

- **A "Redis disabled" fallback keeps the same semantics.** When Redis is switched off, fall back to an in-process implementation (`IMemoryCache`, a dict with expiry) that really stores, expires and answers set-if-not-exists, never a no-op that always says "done". Note that the fallback is single-process only.
  *Cost: with Redis disabled, the null cache's `SetIfNotExists` always returned true, so idempotency de-duplication never engaged and repeated saves all ran.*
- **One shared connection.** StackExchange.Redis: a single `ConnectionMultiplexer` for the app (singleton), never one per request.
  *Why: a multiplexer per request exhausts sockets and adds a handshake to every call.*
- **Every key has a TTL** unless it is deliberately permanent and documented.
  *Why: keys without expiry fill memory until Redis starts evicting or refusing writes.*
- **Never `KEYS *` (or `FLUSHALL`) against a shared server;** use `SCAN` and key prefixes per app and environment.
  *Why: `KEYS` blocks the single-threaded server for every client while it walks the keyspace.*
