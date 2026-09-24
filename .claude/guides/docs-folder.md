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

## docs/user-guides/ (end-user guide)

- Written for end users, not developers: task-oriented, step by step, UI language of the product, screenshots in `images/`.
- Required files: `README.md` (index/table of contents), `getting-started.md`, `troubleshooting.md`, `PROGRESS.md`, `combined.md`, `combined.pdf`, `images/`.
- One page per user-facing feature area, named by the project's features (e.g. messaging, calling, meetings, settings). Names change per project; derive them from `capabilities.md`.
- `PROGRESS.md`: which pages are done, pending, or outdated, plus screenshot status. Update it on every guide change.
- `combined.md` = all pages concatenated in `README.md` order; `combined.pdf` generated from it, always A4. Both produced by a `tools/` script (e.g. `tools/build-user-guide.sh`), never edited by hand.
- Guide pages change only on user request (`~/.claude/guides/docs-updates.md`). When asked: update or add the page, `README.md` index, `PROGRESS.md`, then regenerate `combined.*`.
- Every image referenced exists, every file in `images/` is referenced.
