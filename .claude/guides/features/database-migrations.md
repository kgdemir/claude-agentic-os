# Database schema changes

Applies to any project that changes a database schema, whatever the migration tool (EF Core,
Flyway, Liquibase, Alembic, Prisma, plain SQL). Never editing an applied migration is core:
`~/.claude/guides/core/agent-working-rules.md` §9. EF Core specifics: `~/.claude/guides/stacks/dotnet-ef-core.md`.

- **Breaking schema changes use expand/contract,** across separate releases: (1) add the new column or table, nullable or with a default; (2) deploy code that writes both and reads the old; (3) backfill; (4) switch reads to the new; (5) drop the old in a later release.
  *Why: during a deploy, old and new code run against the same database; a rename or drop in one step breaks whichever version is still running.*
- **Backfills run in batches,** each in its own short transaction, and can resume where they stopped.
  *Why: one `UPDATE` over a large table holds locks for minutes and blocks the application.*
- **Migrations run as one deploy step,** from a script or migration bundle, not from every application instance at start-up.
  *Why: several instances starting together race to apply the same migration, and a failed migration then also stops the app from starting.*
- **Indexes on large, live tables are created online** (PostgreSQL `CREATE INDEX CONCURRENTLY`; SQL Server `WITH (ONLINE = ON)` where the edition supports it).
  *Why: a plain index build locks writes to the table for its whole duration.*
- **Timestamps are stored in UTC with the type saying so:** `timestamptz` (PostgreSQL), `datetimeoffset` or a `…Utc`-named `datetime2` (SQL Server).
  *Why: local times shift with daylight saving and server moves, and an ambiguous column cannot be fixed afterwards without guessing.*
- **A backup or point-in-time restore is confirmed before migrating a shared database,** and each migration states its way back: a tested down migration, or a written roll-forward plan.
  *Why: a migration that fails halfway on production data with no way back is the outage that lasts all night.*
- **Every migration is tested on a copy of real-sized data** before production, and the generated SQL is read.
  *Why: a migration that takes a second on an empty test database can take an hour on production volume.*
