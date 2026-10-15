# Resilience (timeouts, retries, health, shutdown)

Applies to code that calls another service over the network (HTTP, gRPC, database, cache, broker)
or runs behind a load balancer or orchestrator.

- **Every outbound call has a timeout,** set explicitly: a per-attempt timeout and a total timeout across retries.
  *Why: library defaults are long or infinite (`HttpClient` 100 s, Python `requests` none); one slow dependency then holds every worker thread.*
- **Retry only transient failures of idempotent operations,** a bounded number of times, with exponential backoff and jitter. Retry in one layer only.
  *Why: retrying a non-idempotent `POST` can apply it twice; retries stacked in three layers multiply into a retry storm against a service that is already struggling.*
- **Use the platform's resilience library instead of hand-written loops:** .NET `Microsoft.Extensions.Http.Resilience` (`AddStandardResilienceHandler()`; turn retries off for unsafe methods with `DisableForUnsafeHttpMethods()`), Python `tenacity`, Node `cockatiel` or `p-retry`.
  *Why: hand-written loops forget jitter, cancellation and the total timeout.*
- **A circuit breaker guards each dependency that can fail for a while,** and the caller has a stated fallback (cached value, degraded response, clear error).
  *Why: without one, every request keeps waiting on a dependency that is known to be down.*
- **Liveness and readiness are separate checks.** Liveness says only "the process is not stuck" and checks no dependencies; readiness checks what the instance needs to serve traffic (ASP.NET Core: `MapHealthChecks` with tag predicates, e.g. `/health/live` and `/health/ready`).
  *Why: a liveness check that pings the database restarts every instance at once during a database outage, turning a partial outage into a full one.*
- **Shut down gracefully on `SIGTERM`:** stop accepting new work, finish in-flight requests within a set timeout, then exit. The timeout is shorter than the orchestrator's kill grace period.
  *Why: a process killed mid-request returns errors for every in-flight call during each deploy.*
- **Limit concurrency per dependency** (bulkhead: connection-pool size, a semaphore, a rate limiter).
  *Why: one slow dependency otherwise consumes every thread and takes down endpoints that never call it.*
- **Load and failure paths are tested,** not assumed: a test or script that makes each dependency slow or unavailable and checks the timeout, breaker and fallback fire.
  *Why: resilience code runs only when something is already wrong; untested, it fails at exactly that moment.*
