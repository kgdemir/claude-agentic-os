# .NET testing

Applies to .NET test projects (xUnit, NUnit, MSTest). Test gate: `~/.claude/guides/stacks/dotnet.md`.

- **Test against the real database engine for anything the database decides.** EF Core's InMemory provider has no foreign keys, check constraints, collations, transactions or SQL translation, and no real concurrency. Repository, constraint, collation and concurrency tests run against the real engine (Testcontainers, e.g. `Testcontainers.MsSql`, or a disposable local database). InMemory stays for pure logic that never depends on the database.
  *Cost: a foreign-key and check-constraint violation that broke first login, and a Turkish-collation bug in grid filters, are failures the InMemory provider cannot reproduce at all; a concurrency test passed with its guard removed because in-memory serialized every command.*
- **A fake executable runs on every OS the gate runs on.** A test that starts a stand-in for an external tool (ffmpeg, git, a CLI) writes it in the host's script language — `.cmd` on Windows, `sh` elsewhere — or uses a small cross-platform program.
  *Cost: a `.sh` stand-in passed on Linux and failed the Release test gate on a Windows machine ("not a valid application for this OS platform"), blocking the publish.*
- **One behaviour per test, named for it,** arrange/act/assert visible.
  *Why: a failing test should say what broke without reading its body.*
- **Mocks only at boundaries** (HTTP, clock, file system, message bus); never mock the type under test or EF's `DbSet` LINQ when a real database test is cheap.
  *Why: a mock of LINQ-to-entities accepts queries the real provider cannot translate.*
- **Time and randomness are injected** (`TimeProvider`, a seeded `Random`).
  *Why: tests that read the real clock fail at midnight, month end or on a slow CI machine.*
