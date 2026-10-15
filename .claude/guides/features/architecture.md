# Architecture (layers, modules, boundaries)

Applies when creating a project with more than one module, or when adding, moving or splitting
modules, layers or projects. Any language.

- **Dependencies point inward.** Domain and application code never reference infrastructure (ORM, HTTP clients, message brokers, file system, UI framework); infrastructure implements interfaces the inner layer owns.
  *Why: a domain that imports the ORM cannot be tested or changed without the database, and every infrastructure swap becomes a rewrite.*
- **Organise by feature, not by technical type.** A feature's endpoint, handler, validation and data access live together (`features/orders/…`), not spread over `Controllers/`, `Services/`, `Repositories/`.
  *Why: a change to one feature then touches one folder, and dead features can be deleted whole.*
- **Boundaries are enforced by a test or a linter,** not by convention: .NET `NetArchTest.Rules` or `ArchUnitNET`; TypeScript `dependency-cruiser` or `eslint-plugin-boundaries`; Python `import-linter`. No circular project or module references.
  *Why: an unenforced layer rule erodes one "just this once" import at a time.*
- **One composition root.** Wire dependencies in one place at start-up (`Program.cs`, `main`); no service locator, no `new` of infrastructure inside business code.
  *Why: hidden construction makes dependencies invisible and turns tests into integration tests.*
- **Configuration comes from the environment** (12-factor): the same build artifact runs in every environment, settings come from environment variables or a config provider, secrets from a secret store.
  *Why: an artifact rebuilt per environment is not the artifact that was tested.*
- **No mutable static or global state.** Shared state lives in an injected service with a stated lifetime.
  *Why: global state leaks between tests and between concurrent requests, and fails only under load.*
- **Side effects at the edges.** Keep decision logic in pure functions that take values and return values; do I/O around them.
  *Why: pure logic is testable without mocks, and the risky code (I/O) stays small and visible.*
- **A modular monolith before microservices.** Split a module into its own service only for a stated reason (independent scaling, deploy cadence, team ownership, fault isolation), recorded in an ADR.
  *Why: a network boundary adds latency, partial failure and distributed transactions; drawing it in the wrong place is very expensive to undo.*
- **A module owns its data.** Other modules go through its public API, never its tables.
  *Why: a shared table is a hidden contract; one module's schema change breaks another module at runtime.*
