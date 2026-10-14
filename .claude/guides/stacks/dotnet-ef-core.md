# Entity Framework Core

Applies to .NET projects that use EF Core. Everything here was hit in real code; each trap
is silent: the code runs, and the data is wrong or the save fails later.

- **A read-modify-write is not a claim.** Two workers that both read a row, both see the status they expect and both write will both proceed. For "only if it is still in state X", use a single conditional statement — `ExecuteUpdateAsync` over a `Where` that includes the expected state — and treat the affected-row count as the answer. It bypasses the change tracker, which is exactly what makes it atomic.
- **`ExecuteUpdate` and tracked entities disagree.** It writes straight to the database, so an entity already tracked in that context keeps its old values. In the same scope, read back with `AsNoTracking` or re-query; do not trust an instance loaded earlier.
- **`SaveChanges` saves everything the context tracks,** not just the change you had in mind. A "small status write" through a context that already holds unsaved modifications commits those too.
- **After a failed `SaveChanges`, that context is not a good place to write from.** The failed changes are still pending, so the next save retries them and fails the same way. Error handling that records a failure should use a fresh scope.
- **A background worker needs a scope per unit of work.** Resolve scoped services (a `DbContext`, repositories) from `IServiceScopeFactory` inside the loop, never from the scope that queued the work — that one may be a request or hub invocation that ended long ago.
