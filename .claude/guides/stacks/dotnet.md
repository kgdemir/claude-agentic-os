# .NET projects

- Tests must pass before build/publish/deploy. `tools/build.sh`, `tools/publish.sh`, `tools/deploy.sh` run `dotnet test` first and stop on failure. No skip flag by default.
- `TreatWarningsAsErrors` always `true`. Set it once in `Directory.Build.props` at solution root (create if missing), so every project inherits it:
  ```xml
  <Project>
    <PropertyGroup>
      <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
      <Nullable>enable</Nullable>
    </PropertyGroup>
  </Project>
  ```
- Never silence warnings to pass the build (no `NoWarn`, no `#pragma warning disable`) unless user approves. Fix the warning.
- No test project exists: suggest creating one (xUnit) before adding the test gate.
- **Async all the way.** No `.Result`, `.Wait()` or `.GetAwaiter().GetResult()` on a task, and no `async void` except event handlers. Take a `CancellationToken` and pass it to every call that accepts one.
  *Why: blocking on a task starves the thread pool and can deadlock; an exception in `async void` crashes the process; a dropped token keeps work running after the caller gave up.*
- **`HttpClient` comes from `IHttpClientFactory`** (named or typed clients), never `new HttpClient()` per call.
  *Why: a client per call exhausts sockets under load; one static client never sees DNS changes.*
- **Options are validated at startup:** `AddOptions<T>().BindConfiguration(...).ValidateDataAnnotations().ValidateOnStart()` (or a custom `IValidateOptions<T>`).
  *Why: an invalid value otherwise surfaces mid-run, where the first code to read it fails (see the `PeriodicTimer` trap in `~/.claude/guides/stacks/dotnet-gotchas.md`).*
- **Structured logging:** message templates with named holes (`LogInformation("Order {OrderId} shipped", id)`), never string interpolation. Never log secrets, tokens or connection strings.
  *Why: an interpolated message loses its fields for search and allocates even when the level is off.*
- **A vulnerable transitive package is pinned to a patched version** with a direct `PackageReference` (or a central `PackageVersion`), citing the advisory in the commit; never silence `NU1901`–`NU1904`.
  *Cost: Swashbuckle pulled a transitive `Microsoft.OpenApi` with a high-severity advisory, and restore failed under warnings-as-errors (`NU1903`) until the patched version was pinned explicitly.*
- **Package versions live in one place:** `Directory.Packages.props` with `ManagePackageVersionsCentrally`, next to `Directory.Build.props`.
  *Why: per-project versions drift, and two projects in one solution end up loading different versions of the same package.*
- Known traps (config binding, channels, localized build output): `~/.claude/guides/stacks/dotnet-gotchas.md`. EF Core: `~/.claude/guides/stacks/dotnet-ef-core.md`. Child processes and ffmpeg: `~/.claude/guides/tools/child-processes.md`, `~/.claude/guides/tools/ffmpeg.md`.
