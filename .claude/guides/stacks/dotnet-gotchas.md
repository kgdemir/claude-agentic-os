# .NET gotchas

Appendix to `~/.claude/guides/core/agent-working-rules.md` and `~/.claude/guides/stacks/dotnet.md`. Everything here was hit in real code, not
read in a guide. Each one is silent or misleading in some way — that is why it is written down.
EF Core has its own guide (`~/.claude/guides/stacks/dotnet-ef-core.md`); traps that are not .NET-specific live in
`~/.claude/guides/tools/child-processes.md` and `~/.claude/guides/tools/ffmpeg.md`.

## Configuration

- **No `//` comment keys under `Logging:LogLevel`.** The `"//Something": "note"` trick is harmless in most configuration sections, but .NET binds *every* child of `LogLevel` to the `LogLevel` enum. A key whose value is a sentence fails to parse and the application will not start. Put the note in a code comment, a decision record, or a sibling section that is not `LogLevel`.
  *(To toggle EF SQL logging, set `Microsoft.EntityFrameworkCore.Database.Command` to `Information` to show it and `Warning` to hide it.)*
- **A zero or negative interval from configuration throws.** `new PeriodicTimer` rejects a non-positive period with `ArgumentOutOfRangeException`. In a hosted service this usually surfaces as a generic caught error and the loop is simply gone for the life of the process. Clamp or validate the configured value, and log when you do.

## Channels

- **A `SingleReader` channel cannot count.** `Channel.CreateUnbounded` with `SingleReader = true` returns an implementation where `Reader.Count` throws `NotSupportedException`. `TryPeek` works. This bites hardest in tests, where the throw can be swallowed by the very `try/catch` under test and the assertion then reads as "nothing happened".

## Build and test

- **Warnings are errors.** Set `TreatWarningsAsErrors` and `Nullable` to `enable`, and treat a build with warnings as a failed build.
- **A solution build can fail for a project you do not care about.** Windows-only projects in a solution break a Linux build with `NETSDK1100`. Build and test the specific project files instead of the solution, or pass `-p:EnableWindowsTargeting=true` where that is the only obstacle.
- **The build's language follows the system locale.** Parsing compiler output for English words like "error" misses a localized build entirely. Read the exit code.
