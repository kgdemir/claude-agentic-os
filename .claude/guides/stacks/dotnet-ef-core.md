# Entity Framework Core

Applies to .NET projects that use EF Core. Everything here was hit in real code; each trap
is silent: the code runs, and the data is wrong or the save fails later.

- **A read-modify-write is not a claim.** Two workers that both read a row, both see the status they expect and both write will both proceed. For "only if it is still in state X", use a single conditional statement — `ExecuteUpdateAsync` over a `Where` that includes the expected state — and treat the affected-row count as the answer. It bypasses the change tracker, which is exactly what makes it atomic.
- **`ExecuteUpdate` and tracked entities disagree.** It writes straight to the database, so an entity already tracked in that context keeps its old values. In the same scope, read back with `AsNoTracking` or re-query; do not trust an instance loaded earlier.
- **`SaveChanges` saves everything the context tracks,** not just the change you had in mind. A "small status write" through a context that already holds unsaved modifications commits those too.
- **After a failed `SaveChanges`, that context is not a good place to write from.** The failed changes are still pending, so the next save retries them and fails the same way. Error handling that records a failure should use a fresh scope.
- **A background worker needs a scope per unit of work.** Resolve scoped services (a `DbContext`, repositories) from `IServiceScopeFactory` inside the loop, never from the scope that queued the work — that one may be a request or hub invocation that ended long ago.

Preventive rules (no incident recorded here yet; each names the failure it stops):

- **Read-only queries use `AsNoTracking()`.**
  *Why: tracking costs memory and time for entities nobody saves, and a stray change to an entity meant to be read-only is written by the next `SaveChanges` in that context.*
- **No N+1 queries.** No lazy-loading proxies; load related data with `Include` or a `Select` projection. Check the SQL of a non-trivial query with `ToQueryString()` or the `Microsoft.EntityFrameworkCore.Database.Command` log.
  *Why: a loop over entities that touches a navigation property sends one query per row.*
- **Read every generated migration before applying it.** A rename can be scaffolded as drop column + add column; turn it into `RenameColumn`/`RenameTable` by hand. Never mix `EnsureCreated` with migrations.
  *Why: drop + add loses the column's data, and nothing warns at apply time.*
- **One `DbContext`, one operation at a time.** Never `Task.WhenAll` queries over the same context; use a context per parallel unit (`IDbContextFactory<T>`).
  *Why: it throws "A second operation was started on this context instance".*
- **Raw SQL is parameterized:** interpolated `FromSql` / `ExecuteSql`, never `FromSqlRaw` / `ExecuteSqlRaw` with concatenated input.
  *Why: concatenated input is SQL injection.*
