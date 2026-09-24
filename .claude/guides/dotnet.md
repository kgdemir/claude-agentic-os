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
- Known traps (config binding, EF Core concurrency/scopes, channels, child processes, ffmpeg, localized build output): `dotnet-gotchas.md`.
