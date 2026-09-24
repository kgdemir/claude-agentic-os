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
   - `docs/adr/README.md` — ADR index; rows must match `docs/adr/*.md` exactly (it goes stale easily)
   - `docs/user-guides/*.md` — end-user guide, plus `PROGRESS.md`
3. Any guide page change must reach `combined.md`. Links in `combined.md`: rewrite `http://localhost…` and cross-page links to in-document anchors (`#section-anchor`); the PDF has no web server and no sibling files.
4. Rebuild the PDF **only** when the change reaches the exported guide (a page under `docs/user-guides/` or `combined.md`). A README, ADR or `capabilities.md` change is not in the PDF: edit and stop.
   - Rebuild only through the project's `tools/` guide script, never a hand-typed converter command. Put every converter quirk (env vars, stdin redirect, browser path) into that script.
   - Page size is always **A4** (≈`595 x 842 pts`; Chrome gives `594.96 x 841.92`, md-to-pdf `595.92 x 841.92` — both A4). Set it in the guide script (e.g. CSS `@page { size: A4; }` or the converter's A4 option), never rely on the tool default (often Letter).
   - Keep other PDF options at defaults; custom margins reflow the whole document.
   - Verify after rebuild: `pdfinfo combined.pdf` shows ≈`595 x 842 pts` (A4, not Letter `612 x 792`) and page count is close to the last export.
   - Anchor check: render `combined.md` to HTML, compare rendered `id="…"` values with `](#…)` links. The Markdown renderer's slugger decides ids, not GitHub's: a heading with an em dash or spaced slash can legitimately produce a double hyphen. Never "fix" those; editing them is what breaks them.
5. Bump the baseline hash in `capabilities.md` to the new `HEAD`.

## Never commit a baseline-only bump

- If every commit since the baseline already updated `capabilities.md` and the hash is the only change: do not commit. Say the content is current and stop.
- The hash moves only together with real content. (A baseline-only commit was once rolled back.)

## ADRs

- After a commit that lands an architectural decision (tech choice, pattern, API/auth/data-model design, infrastructure), record an ADR in `docs/adr/` from `~/.claude/templates/adr-template.md`: status `accepted`, date = commit date, Deciders `{{OWNER_NAME}}`, cite the commit SHA, link related ADRs. Add its row to `docs/adr/README.md`.
- Skip trivial, UI-only and cleanup commits.

## Authorship and commits

- Never mention Claude, AI or assistant authorship in anything that lands in the repo or is shared (docs, ADRs, PRs, commit messages, code comments). See Ownership & Attribution in global `CLAUDE.md`.
- Stage named paths only — never `git add -A` or `git add .`; no dotfiles or dot-directories unless told.
