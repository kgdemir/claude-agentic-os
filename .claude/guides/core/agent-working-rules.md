# Agent Working Rules

Project-agnostic. Each rule earned its place by costing something; the cost is recorded so a later
reader can judge whether it still applies instead of deleting a rule that looks like fussiness.
A rule marked *Why* instead of *Cost* is preventive: no incident is recorded yet, only the failure
it stops. When one happens, replace the *Why* line with its *Cost*.

## 1. Verification

- **Read exit codes, never output text.** `npm run lint 2>&1 | tail -1` prints the same wrapper line whether lint passed or failed, and a pipe returns the exit status of the *last* command, so `$?` belongs to `tail`. Use `set -o pipefail` and check `$?`, or run the gate unpiped.
  *Cost: a lint error reached the main branch and broke CI; twice in one session, same cause.*
- **`cd x && <edit> && <test>` is the same trap by another route.** When the shell is already in `x`, `cd x` fails, `&&` short-circuits, the edit never happens — and the test still runs against the previous state and reports green. Use absolute paths, or separate the steps.
- **Never claim a gate is green without having run it in that state.** Re-run after the last edit, not before it.
- **Report what did not run.** Name every gate not run, every step skipped and every check that could not be done here. Never write "should work" about code that was not run.
  *Why: a summary that reads as done is acted on as done; the skipped step surfaces later, in someone else's run.*
- **Prove a test fails without its fix.** Remove the guard or revert the fix, re-run, confirm red, restore. A test that cannot fail is not coverage.
  *Cost: a concurrency test passed with the guard removed — the in-memory database serialized every command, so there was no seam to interleave.*
- **Give a multi-step task a plan with a check per step.** Before starting, write the steps and, for each, the check that proves it done: the test, gate or command, and the result expected. "Make it work" is not a check.
  *Why: without a named check, "done" means "looks done", and a step that never worked is found only at the end, under the steps built on it.*

## 2. Diagnosis and ambiguity

- **Name the assumption before building on it.** When a request has two readings that lead to different code, ask through `AskUserQuestion` before writing it. When one reading is clear enough to act on, act, and state the assumption in the reply. When a simpler way reaches the same goal, say so before building the harder one.
  *Why: a silent guess becomes a finished diff that the person has to read to find out it was the wrong guess, then undo.*
- **No speculative fixes.** When a bug reproduces, find the mechanism that predicts the *observed detail*: how many times the error prints, where in the output, in what order. A plausible story that explains "roughly this" is not a diagnosis.
- **Unchanged output disproves the diagnosis.** If a shipped fix does not change the output at all, stop and re-diagnose rather than layering the next theory on the last one.
  *Cost: four attempts at one error, three of them speculative, each committed and each needing a manual run against a live server. None changed a single line of output.*

## 3. Background work and delegation

- **One reviewer per diff.** If a specialist review already covers the change, do not also launch a general review pass over the same files.
- **Never review a tree that is still being edited.** The review snapshots the files, goes stale immediately, and its findings arrive already fixed.
- **`tail -f` is wrong for a one-shot outcome.** It never exits, so the watcher stays armed until timeout, long after the awaited line appeared. For "tell me when X finishes", poll: `until grep -q PATTERN file; do sleep 2; done`. Reserve a streaming follow for genuinely repeating events.
- **Stop what you started.** Before finishing, stop every dev server, watcher or background job you started, unless the user asked for it to keep running and knows how to stop it. Never leave a port bound.
  *Why: a forgotten server holds the port, and the next run fails with "address in use" or, worse, talks to the stale build.*
- **Do not idle-wait on work that reports back by itself.** Background jobs and subagents announce their own completion.
- **Know the subagent cache TTL before you wait on one.** Subagent prompt caches live 5 minutes by default. `install.sh` sets `subagentPromptCacheTtl` to `1h`, but `1h` is silently ignored while a Claude subscription is in overage. Without that setting, or when in doubt, assume 5 minutes. Once a subagent is idle past its TTL, its next request pays for its whole history again.
- **A subagent never waits past its TTL in one command:** at most 4 minutes on a 5-minute cache, 55 minutes on a 1-hour cache. Poll in short chunks (`until <check>; do sleep 30; done` with a bounded loop count, or repeated short checks) instead of one long `sleep` or one long blocking call.
- **Brief a subagent so it can finish without asking back.** Every brief has a `Goal:` line (one sentence), a `Files:` line (the files or paths involved, plus what is already known or ruled out) and a `Done:` line (the output wanted and how it is checked). If something is unclear, the agent picks the safest reading, says which one in its result, and does not stop to ask. A subagent waiting on a question sits idle while its cache expires. The `check-agent-brief.py` hook reminds you when a brief lacks one of the three lines (warn-only, never blocks); `Explore`, `claude-code-guide`, `statusline-setup` and forks are exempt.
- **Never message a subagent that has been idle past its TTL.** Its cache is gone, so waking it re-sends its whole history at full price — more than a new agent costs. Start a fresh one with a short brief: the goal, the files involved, what is already done. Within the TTL, messaging it is the cheaper option.

## 4. Reproducible tooling

- **Save a script the first time it works.** When a multi-line command sequence proves out, write it into the project's `tools/` directory (see `~/.claude/guides/core/project-tools.md`), reference it from the docs or workflow that needs it, and call the script from then on.
  *Cost: the same recipe retyped by hand on every run, with environment variables drifting between attempts.*
- **A saved script carries its own prerequisites** — environment variables, redirects, easy-to-forget flags. That is most of its value: a hand-typed invocation loses exactly those.

## 5. Documentation

- **Update docs only when asked**; **expensive regeneration only when the change reaches the output**; **baseline marker, never a hash-only commit.** Full rules and costs: `~/.claude/guides/core/docs-updates.md`.

## 6. Version control

- **Stage named paths.** Never `git add -A` or `git add .`, and never commit dotfiles or dot-directories unless explicitly told to.
  *Cost: a 7,674-file virtual-environment directory committed before `.gitignore` covered it, needing a branch cleanup.*
- **Run git from the repository root** (or use `git -C <root>`). From a subdirectory, path arguments do not resolve and commands fail with `pathspec did not match any files`.
- **Commit and push only when asked.** Pushing is outward-facing; approval for one does not carry to the next.
- No AI attribution in commits or anywhere else (Ownership & Attribution, global `CLAUDE.md`).

## 7. Code quality

- **No lint-disable comments without approval.** When a rule fires, fix the cause. If a disable is genuinely needed, ask first (via `AskUserQuestion`) — naming the rule, the line and why a real fix is not feasible — and, once approved, put the reason in a comment directly above it. Disables accumulate as debt and hide real problems.
- **Compiler and linter warnings are errors.** A build with warnings is not a clean build.
- **Change only what was asked.** No drive-by refactors, renames or reformatting outside the task. Match the surrounding style, even where you would write it differently. Remove the imports, variables and functions that your own change left unused; dead code that was already there is reported, not deleted. Problems noticed on the way are reported, not fixed.
  *Why: unrequested changes hide the real change in review and break things nobody asked to touch.*
- **Simplest code that does the task.** No features, options or settings nobody asked for, no abstraction with a single caller, no error handling for a case the code cannot reach. If the same result fits in a much shorter diff, shorten it before showing it.
  *Why: speculative code still has to be read, tested and kept working, and it is usually wrong about the future it was written for.*
- **No swallowed errors.** No empty `catch`/`except`, no catch that only returns a default. Log with enough context to find the cause, or rethrow.
  *Why: a swallowed error turns a crash with a stack trace into wrong output with no trace.*
- **No magic numbers or strings.** Any literal that is not self-evident becomes a named constant; shared ones are exported from one place.

## 8. Decisions and memory

- **Record architectural decisions where the code lives.** After a commit that lands a real architectural choice, write an ADR (`~/.claude/guides/core/docs-folder.md`, template `~/.claude/templates/adr-template.md`). Skip trivial, cosmetic and cleanup commits. Rationale kept only in commit messages is rationale nobody finds.
- **One fact per memory file, with an index of pointers.** Never inline content into the index, and leave no file the index does not reference.
- **Memory is context, not truth.** Verify anything a stored note claims about the code against the code before acting on it.

## 9. Safety

- **Secrets never leave their store.** Never print, log, commit or paste keys, tokens, passwords or connection strings. Add `.env` (and similar) to `.gitignore` before the first commit, and read `git diff --cached` for secrets before every commit.
  *Why: a pushed secret is public at once, and removing it from history does not un-leak it; it has to be rotated.*
- **Look before destroying.** Before `rm -rf`, `git reset --hard`, `git clean`, `git push --force`, a branch delete, or a database drop or migration outside a local database: look at the target, then confirm with the user. Use `git push --force-with-lease`, never plain `--force`.
  *Why: these cannot be undone, and the wrong path or branch is one typo away.*
- **Never edit an applied migration.** A migration that has run anywhere outside your machine is history: add a new migration instead.
  *Why: databases that already ran the old version never run the edited one, so schemas drift apart silently.*
- **Dependencies are a decision.** Add one only with a stated reason, commit the lockfile with it, and never upgrade a major version as a side effect of another task. Never hand-edit lockfiles or generated files; regenerate them with their tool.
  *Why: an unreviewed dependency is someone else's code running in the project; a hand-edited lockfile no longer matches what the tool installs.*

## Appendices

- Stack, tool, feature and plugin guides load on demand: see the add-on table in `~/.claude/CLAUDE.md`.
