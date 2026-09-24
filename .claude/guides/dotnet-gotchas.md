# .NET gotchas

Appendix to `agent-working-rules.md` and `dotnet.md`. Everything here was hit in real code, not
read in a guide. Each one is silent or misleading in some way — that is why it is written down.

## Configuration

- **No `//` comment keys under `Logging:LogLevel`.** The `"//Something": "note"` trick is harmless in most configuration sections, but .NET binds *every* child of `LogLevel` to the `LogLevel` enum. A key whose value is a sentence fails to parse and the application will not start. Put the note in a code comment, a decision record, or a sibling section that is not `LogLevel`.
  *(To toggle EF SQL logging, set `Microsoft.EntityFrameworkCore.Database.Command` to `Information` to show it and `Warning` to hide it.)*
- **A zero or negative interval from configuration throws.** `new PeriodicTimer` rejects a non-positive period with `ArgumentOutOfRangeException`. In a hosted service this usually surfaces as a generic caught error and the loop is simply gone for the life of the process. Clamp or validate the configured value, and log when you do.

## Entity Framework

- **A read-modify-write is not a claim.** Two workers that both read a row, both see the status they expect and both write will both proceed. For "only if it is still in state X", use a single conditional statement — `ExecuteUpdateAsync` over a `Where` that includes the expected state — and treat the affected-row count as the answer. It bypasses the change tracker, which is exactly what makes it atomic.
- **`ExecuteUpdate` and tracked entities disagree.** It writes straight to the database, so an entity already tracked in that context keeps its old values. In the same scope, read back with `AsNoTracking` or re-query; do not trust an instance loaded earlier.
- **`SaveChanges` saves everything the context tracks,** not just the change you had in mind. A "small status write" through a context that already holds unsaved modifications commits those too.
- **After a failed `SaveChanges`, that context is not a good place to write from.** The failed changes are still pending, so the next save retries them and fails the same way. Error handling that records a failure should use a fresh scope.
- **A background worker needs a scope per unit of work.** Resolve scoped services (a `DbContext`, repositories) from `IServiceScopeFactory` inside the loop, never from the scope that queued the work — that one may be a request or hub invocation that ended long ago.

## Channels

- **A `SingleReader` channel cannot count.** `Channel.CreateUnbounded` with `SingleReader = true` returns an implementation where `Reader.Count` throws `NotSupportedException`. `TryPeek` works. This bites hardest in tests, where the throw can be swallowed by the very `try/catch` under test and the assertion then reads as "nothing happened".

## Processes

- **Drain both pipes.** When you redirect standard output and standard error, read both. A full pipe buffer blocks the child process, and the parent then waits for an exit that cannot happen.
- **Kill in `finally`.** A timeout usually arrives as a cancelled wait, not as a dead process. Unless the process is killed on every exit path, including cancellation, it keeps running after the call returns.
- **Media duration: read the packets, not the header.** A file cut short by a crash can keep a header claiming its full length, and a file still being written has no final duration at all. `ffprobe -show_entries format=duration` reported 30 s for a file holding 18 s of audio. Reading through the packets (`ffmpeg -i <file> -map 0 -c copy -f null - -progress pipe:1 -nostats`, take the last `out_time_us`) reported the true 18.1 s.
- **Put global ffmpeg options before `-i`.** Builds older than version 5 ignore options that trail the last output, so a progress report requested at the end silently produces nothing — and the caller sees an empty result rather than an error.

## Build and test

- **Warnings are errors.** Set `TreatWarningsAsErrors` and `Nullable` to `enable`, and treat a build with warnings as a failed build.
- **A solution build can fail for a project you do not care about.** Windows-only projects in a solution break a Linux build with `NETSDK1100`. Build and test the specific project files instead of the solution, or pass `-p:EnableWindowsTargeting=true` where that is the only obstacle.
- **The build's language follows the system locale.** Parsing compiler output for English words like "error" misses a localized build entirely. Read the exit code.
