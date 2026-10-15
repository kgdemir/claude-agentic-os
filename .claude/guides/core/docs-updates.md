# Documentation Updates

Applies to `capabilities.md`, `README.md`, `docs/adr/README.md`, `docs/user-guides/*` (incl. `combined.md`, `combined.pdf`).

## Only on request

- Never edit these docs as a side effect of shipping code. After a code change, say in the reply which doc would need a line, then stop.
- Docs change only when the user asks ("update the docs", "update the documents", "dokümanları güncelle").
- Exceptions: creating a missing doc on project create/open, and ADRs (see below).
- Why: an unrequested doc update once rewrote a guide page and started a multi-minute PDF render nobody asked for.

## Baseline marker

- `capabilities.md` ends with `<!-- DOC-BASELINE: ... -->` and `_Documentation baseline: current as of commit <hash> (<date>)_`.
- That hash is the last commit whose features are documented. No git repo yet: use the date, switch to a hash once commits exist.

## Workflow when asked

1. `git log --oneline <hash>..HEAD` — everything landed since the last sync.
2. Fold each new feature, fix and ADR into:
   - `capabilities.md` — authoritative feature + tech-stack overview
   - `README.md` — architecture table + stack
   - `docs/architecture.md` — C4 diagrams, when the project has one
   - `docs/adr/README.md` — ADR index; rows must match `docs/adr/*.md` exactly (it goes stale easily)
   - `docs/user-guides/*.md` — end-user guide, plus `PROGRESS.md`
3. A change that reaches a guide page: `combined.md`, its links and the PDF rebuild follow `~/.claude/guides/features/user-guide.md`. A README, ADR or `capabilities.md` change is not in the PDF: edit and stop.
4. Bump the baseline hash in `capabilities.md` to the new `HEAD`.

## Never commit a baseline-only bump

- If every commit since the baseline already updated `capabilities.md` and the hash is the only change: do not commit. Say the content is current and stop.
- The hash moves only together with real content. (A baseline-only commit was once rolled back.)

## ADRs

- After a commit that lands an architectural decision (tech choice, pattern, API/auth/data-model design, infrastructure), record an ADR in `docs/adr/` from `~/.claude/templates/adr-template.md`: status `accepted`, date = commit date, Deciders `{{OWNER_NAME}}`, cite the commit SHA, link related ADRs. Add its row to `docs/adr/README.md`.
- Skip trivial, UI-only and cleanup commits.

## Authorship and commits

- Never mention Claude, AI or assistant authorship in anything that lands in the repo or is shared (docs, ADRs, PRs, commit messages, code comments). See Ownership & Attribution in global `CLAUDE.md`.
- Stage named paths only — never `git add -A` or `git add .`; no dotfiles or dot-directories unless told.
