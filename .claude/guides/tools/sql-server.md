# SQL Server

Applies to projects that use SQL Server (EF Core `SqlServer` provider, `Microsoft.Data.SqlClient`, T-SQL scripts).
EF Core rules: `~/.claude/guides/stacks/dotnet-ef-core.md`.

- **Language-correct comparisons use a collation, on every operator.** Case- and accent-insensitive search in a language with special casing (Turkish `I/ı/İ/i`, German `ß`) needs an explicit collation (e.g. `Turkish_CI_AI`, via `EF.Functions.Collate` or the column definition). `ToLower()`/`ToUpper()` are not a substitute, and a query rewriter that adds the collation must cover equality as well as `LIKE`-style operators, including the `ToLower()`-wrapped column shape grid libraries emit.
  *Cost: "Is equal to" on a grid of `ust sag` returned nothing for a row holding `Üst Sağ` while "Contains" worked, because the collation was applied only to the bare-column shape, not to `x.Name.ToLower() == v`.*
- **Parameters only.** Never build SQL by concatenating input, in C#, scripts or dynamic SQL inside stored procedures (`sp_executesql` with parameters).
  *Why: concatenated input is SQL injection.*
- **`TrustServerCertificate=True` only in local development.** Production connection strings use `Encrypt=True` with a certificate the client trusts.
  *Why: trusting any certificate turns on encryption without authentication, so a man-in-the-middle is invisible.*
- **Look at the plan for a slow query before adding an index**, and add indexes in migrations, not by hand on one server.
  *Why: a hand-made index exists on one database only, and a guessed index often is not used.*
- **Keep transactions short and never wait on a user or network call inside one.**
  *Why: held locks block other sessions and turn into timeouts or deadlocks under load.*
