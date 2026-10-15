# Performance

Applies when a task is about speed, memory, load or bundle size, or before launching something
expected to carry real traffic. Query traps: `~/.claude/guides/stacks/dotnet-ef-core.md`. Bundle
chunks: `~/.claude/guides/tools/vite.md`. Caching: `~/.claude/guides/features/caching.md`.

- **Measure, change, measure again.** No optimisation without a before and after number, recorded in the commit or PR.
  *Why: intuition about where time goes is usually wrong, and an unmeasured "optimisation" often adds complexity for nothing.*
- **Set budgets and check them:** p95/p99 latency per key endpoint, JS bundle size, and for web pages the Core Web Vitals at the 75th percentile (LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1).
  *Why: without a budget, performance only gets worse, one acceptable-looking change at a time.*
- **Report percentiles, not averages.**
  *Why: an average hides the slow tail that real users hit.*
- **Profile with the stack's tools before guessing:** .NET `dotnet-counters`, `dotnet-trace`, BenchmarkDotNet; Python `cProfile`, `py-spy`; browser DevTools Performance panel and Lighthouse; the database's execution plan.
  *Why: a profile points at the real hot spot; guessing optimises the wrong function.*
- **Look at the database first:** N+1 queries, missing indexes, and reading whole tables or columns that are not used.
  *Why: in most business apps the database round trips, not the code, dominate request time.*
- **Benchmarks run in Release builds, warmed up, over many iterations,** on a quiet machine.
  *Why: debug builds, cold JIT and a single run produce numbers that do not hold in production.*
- **Load-test before launch and after big changes** (k6, NBomber, Locust) with production-like data volume.
  *Why: contention, pool exhaustion and lock waits appear only under concurrency.*
- **Large results are paginated or streamed,** never loaded whole into memory.
  *Why: a list that fits in memory in testing grows until it does not.*
