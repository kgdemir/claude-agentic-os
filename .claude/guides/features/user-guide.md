# End-user guide (docs/user-guides/)

Applies to projects that have or create `docs/user-guides/`. When guide pages may change at all
(only on request): `~/.claude/guides/core/docs-updates.md`. Building the PDF:
`~/.claude/guides/tools/pdf-export.md`.

- Written for end users, not developers: task-oriented, step by step, UI language of the product, screenshots in `images/`.
- Required files: `README.md` (index/table of contents), `getting-started.md`, `troubleshooting.md`, `PROGRESS.md`, `combined.md`, `combined.pdf`, `images/`.
- One page per user-facing feature area, named by the project's features (e.g. for a shop: catalogue, cart, checkout, account). Names change per project; derive them from `capabilities.md`.
- `PROGRESS.md`: which pages are done, pending, or outdated, plus screenshot status. Update it on every guide change.
- `combined.md` = all pages concatenated in `README.md` order; `combined.pdf` generated from it, always A4. Both produced by a `tools/` script (e.g. `tools/build-user-guide.sh`), never edited by hand.
- Guide pages change only on user request (`~/.claude/guides/core/docs-updates.md`). When asked: update or add the page, `README.md` index, `PROGRESS.md`, then regenerate `combined.*`.
- Every image referenced exists, every file in `images/` is referenced.

## Updating combined.md and the PDF

- Any guide page change must reach `combined.md`. Links in `combined.md`: rewrite `http://localhost…` and cross-page links to in-document anchors (`#section-anchor`); the PDF has no web server and no sibling files.
- Rebuild the PDF **only** when the change reaches the exported guide (a page under `docs/user-guides/` or `combined.md`). A README, ADR or `capabilities.md` change is not in the PDF: edit and stop.
  - How to build and verify the PDF (A4, converter quirks, anchor check): `~/.claude/guides/tools/pdf-export.md`.
