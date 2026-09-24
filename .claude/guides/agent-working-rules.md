# Agent Working Rules

Project-agnostic. Each rule earned its place by costing something; the cost is recorded so a later
reader can judge whether it still applies instead of deleting a rule that looks like fussiness.

## 1. Verification

- **Read exit codes, never output text.** `npm run lint 2>&1 | tail -1` prints the same wrapper line whether lint passed or failed, and a pipe returns the exit status of the *last* command, so `$?` belongs to `tail`. Use `set -o pipefail` and check `$?`, or run the gate unpiped.
  *Cost: a lint error reached the main branch and broke CI; twice in one session, same cause.*
- **`cd x && <edit> && <test>` is the same trap by another route.** When the shell is already in `x`, `cd x` fails, `&&` short-circuits, the edit never happens — and the test still runs against the previous state and reports green. Use absolute paths, or separate the steps.
- **Never claim a gate is green without having run it in that state.** Re-run after the last edit, not before it.
- **Prove a test fails without its fix.** Remove the guard or revert the fix, re-run, confirm red, restore. A test that cannot fail is not coverage.
  *Cost: a concurrency test passed with the guard removed — the in-memory database serialized every command, so there was no seam to interleave.*

## 2. Diagnosis

- **No speculative fixes.** When a bug reproduces, find the mechanism that predicts the *observed detail*: how many times the error prints, where in the output, in what order. A plausible story that explains "roughly this" is not a diagnosis.
- **Unchanged output disproves the diagnosis.** If a shipped fix does not change the output at all, stop and re-diagnose rather than layering the next theory on the last one.
  *Cost: four attempts at one error, three of them speculative, each committed and each needing a manual run against a live server. None changed a single line of output.*

## 3. Background work and delegation

- **One reviewer per diff.** If a specialist review already covers the change, do not also launch a general review pass over the same files.
- **Never review a tree that is still being edited.** The review snapshots the files, goes stale immediately, and its findings arrive already fixed.
- **`tail -f` is wrong for a one-shot outcome.** It never exits, so the watcher stays armed until timeout, long after the awaited line appeared. For "tell me when X finishes", poll: `until grep -q PATTERN file; do sleep 2; done`. Reserve a streaming follow for genuinely repeating events.
- **Do not idle-wait on work that reports back by itself.** Background jobs and subagents announce their own completion.

## 4. Reproducible tooling

- **Save a script the first time it works.** When a multi-line command sequence proves out, write it into the project's `tools/` directory (see `project-tools.md`), reference it from the docs or workflow that needs it, and call the script from then on.
  *Cost: the same recipe retyped by hand on every run, with environment variables drifting between attempts.*
- **A saved script carries its own prerequisites** — environment variables, redirects, easy-to-forget flags. That is most of its value: a hand-typed invocation loses exactly those.

## 5. Documentation

- **Update docs only when asked**; **expensive regeneration only when the change reaches the output**; **baseline marker, never a hash-only commit.** Full rules and costs: `docs-updates.md`.

## 6. Version control

- **Stage named paths.** Never `git add -A` or `git add .`, and never commit dotfiles or dot-directories unless explicitly told to.
  *Cost: a 7,674-file virtual-environment directory committed before `.gitignore` covered it, needing a branch cleanup.*
- **Run git from the repository root** (or use `git -C <root>`). From a subdirectory, path arguments do not resolve and commands fail with `pathspec did not match any files`.
- **Commit and push only when asked.** Pushing is outward-facing; approval for one does not carry to the next.
- No AI attribution in commits or anywhere else (Ownership & Attribution, global `CLAUDE.md`).

## 7. Code quality

- **No lint-disable comments without approval.** When a rule fires, fix the cause. If a disable is genuinely needed, ask first (via `AskUserQuestion`) — naming the rule, the line and why a real fix is not feasible — and, once approved, put the reason in a comment directly above it. Disables accumulate as debt and hide real problems.
- **Compiler and linter warnings are errors.** A build with warnings is not a clean build.
- **No magic numbers or strings.** Any literal that is not self-evident becomes a named constant; shared ones are exported from one place.

## 8. Decisions and memory

- **Record architectural decisions where the code lives.** After a commit that lands a real architectural choice, write an ADR (`docs-folder.md`, template `~/.claude/templates/adr-template.md`). Skip trivial, cosmetic and cleanup commits. Rationale kept only in commit messages is rationale nobody finds.
- **One fact per memory file, with an index of pointers.** Never inline content into the index, and leave no file the index does not reference.
- **Memory is context, not truth.** Verify anything a stored note claims about the code against the code before acting on it.

## Appendices

- .NET: `dotnet-gotchas.md`.
