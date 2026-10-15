# Testing strategy

Applies to any project with tests, any language. Stack specifics:
`~/.claude/guides/stacks/dotnet-testing.md`, `~/.claude/guides/stacks/frontend-testing.md`.
Proving a test can fail is core: `~/.claude/guides/core/agent-working-rules.md` §1.

- **Most tests are fast tests of logic; fewer integration tests; few end-to-end tests** of the main user journeys.
  *Why: end-to-end tests are slow and brittle; a suite built mostly of them is run less and trusted less.*
- **Test behaviour through the public surface,** not private methods or internal calls.
  *Why: tests tied to implementation break on every refactor that keeps behaviour the same, and stop protecting anything.*
- **A bug fix starts with a test that reproduces the bug,** red before the fix and green after.
  *Why: a fix without a reproducing test can quietly come back in the next change.*
- **Integration tests run against real dependencies** (database, broker, cache in containers), not mocks of them.
  *Why: a mock agrees with whatever the code assumes; the real dependency is what disagrees in production.*
- **Services that call each other have contract tests** (consumer-driven, e.g. Pact) or a committed schema with a breaking-change check (`~/.claude/guides/features/api-design.md`).
  *Why: each side's own tests pass while the two drift apart.*
- **Tests are independent and deterministic:** own data, any order, parallel-safe; inject the clock and random seeds; wait on a condition, never a fixed sleep.
  *Why: order-dependent and time-dependent tests are the main source of flaky failures.*
- **A flaky test is quarantined with an issue and an owner,** then fixed or deleted within a set time; never silently retried until green.
  *Why: a suite people re-run until green has stopped being a gate.*
- **Coverage is a signal, not a target.** Review which changed lines are uncovered (diff coverage) instead of chasing a percentage.
  *Why: a coverage target gets met with tests that execute code without asserting anything.*
- **Test data comes from builders with sensible defaults,** each test setting only the fields it is about.
  *Why: a shared fixture that every test leans on breaks dozens of tests at once when one needs a change.*
