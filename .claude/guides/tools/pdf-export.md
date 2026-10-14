# PDF export (Markdown to PDF)

Applies whenever a project exports Markdown to PDF (for example `docs/user-guides/combined.pdf`,
see `~/.claude/guides/core/docs-updates.md` for *when* to rebuild). This file is *how*.

- Rebuild only through the project's `tools/` guide script, never a hand-typed converter command. Put every converter quirk (env vars, stdin redirect, browser path) into that script.
- Page size is always **A4** (≈`595 x 842 pts`; Chrome gives `594.96 x 841.92`, md-to-pdf `595.92 x 841.92` — both A4). Set it in the guide script (e.g. CSS `@page { size: A4; }` or the converter's A4 option), never rely on the tool default (often Letter).
- Keep other PDF options at defaults; custom margins reflow the whole document.
- Verify after rebuild: `pdfinfo combined.pdf` shows ≈`595 x 842 pts` (A4, not Letter `612 x 792`) and page count is close to the last export.
- Anchor check: render `combined.md` to HTML, compare rendered `id="…"` values with `](#…)` links. The Markdown renderer's slugger decides ids, not GitHub's: a heading with an em dash or spaced slash can legitimately produce a double hyphen. Never "fix" those; editing them is what breaks them.
