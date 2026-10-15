# docs/ folder

Every project has `docs/` with `docs/adr/` and `docs/user-guides/`. Missing: create on project create/open.

## docs/adr/ (Architecture Decision Records)

- Template: `~/.claude/templates/adr-template.md`. Every ADR follows it exactly: same headings, same order, same fields. Never free-form.
- File name: `docs/adr/NNNN-kebab-case-title.md`, 4-digit zero-padded, next free number, never reused. Title line `# ADR-NNNN: <Title>`.
- `Status`: one of `proposed`, `accepted`, `deprecated`, `superseded by ADR-NNNN`. `Date` absolute `YYYY-MM-DD`. `Deciders`: always `{{OWNER_NAME}}` (project owner). Never list Claude, Claude Code, or any AI.
- At least one real alternative with pros, cons, why not. Consequences list positive, negative, risks honestly.
- Write an ADR after a commit that lands an architectural decision (technology/library, architecture, pattern, data model, auth/security, API contract, infrastructure/deploy, or reversing an earlier decision): date = commit date, cite the commit SHA, link related ADRs. Skip trivial, UI-only and cleanup commits. Unsure: ask via `AskUserQuestion`.
- ADRs are immutable once `accepted`: a later change writes a new ADR, marks the old one `superseded by ADR-NNNN`. Small clarifications: add a dated `Amendment YYYY-MM-DD` note at the end, never rewrite history.
- Keep `docs/adr/README.md` index: number, title, status, date, one line per ADR.
- Code, `capabilities.md`, `README.md` cite ADRs as `(ADR-NNNN)` where the decision applies.

## docs/architecture.md (C4 model)

- Projects with more than one container (separately running app, service, database, queue or file store) keep `docs/architecture.md` from `~/.claude/templates/architecture-template.md`: system context and container diagrams (C4 levels 1 and 2) in Mermaid, then key flows, deployment and cross-cutting concerns. Component and code levels only when a container is too big to follow without them.
- It shows structure; ADRs record why. Link the ADR behind each container or boundary instead of repeating its reasoning.
- It changes on request like the other docs (`~/.claude/guides/core/docs-updates.md`): after a change that adds, removes or rewires a container, name it as needing an update.
  *Why: a README architecture table lists parts but not how they talk; without one diagram of containers and protocols, each new reader rebuilds it from the code.*

## docs/user-guides/ (end-user guide)

- Layout, required files and the update workflow: read `~/.claude/guides/features/user-guide.md` before creating or editing anything under `docs/user-guides/`.
