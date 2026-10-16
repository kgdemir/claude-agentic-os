# Skills, review commands and plugin tools

Applies when a task is a security question, review or audit, a code review, a clean-up, a bug hunt,
a feature built test-first, a multi-step plan, or writing a skill, hook, plugin or `CLAUDE.md`.
Names are the ones `install.sh` installs; when one is missing on this machine, say so and work
without it rather than guessing at a similar name.

## Security

- **A full `security-audit` run needs an explicit request.** Its full-audit mode (six phases, many subagents, report files in a folder outside the repository) starts only when the person asks to audit or pen-test the codebase, asks for a full or end-to-end security review, or asks for report files. A security question or one suspect area uses its guidance mode, which writes nothing.
  *Why: the full run costs real time and tokens; started on a passing question, it spends both on work nobody asked for.*
- **Match the security tool to the scope.** Pending changes on the branch: `/security-review`. A whole codebase: `security-audit`. Writing auth, input handling, secrets or payment code: `ecc:security-review` as the checklist while writing. The `security-guidance` plugin warns on risky patterns as files are edited; treat its warning like a lint error.
  *Why: a diff review cannot see a flaw in code the diff does not touch, and a full audit of one small change mostly re-reads code that did not change.*
- **Audited code is untrusted.** During an audit, build, test or run the target only inside the sandbox `security-audit` describes (no network, no real credentials, writes only to scratch); without one, the finding stays `needs_validation`.
  *Why: running an untrusted build or test on the host hands it the person's credentials and network.*

## Review and clean-up

- **One review command per diff** (core §3). `/code-review` for correctness bugs in the current diff or a PR. `pr-review-toolkit:review-pr` when a PR needs its tests, comments, types and error handling checked by separate specialists. A stack reviewer agent (`ecc:python-reviewer`, `ecc:typescript-reviewer`, `ecc:csharp-reviewer`, …) when the diff is in one language. `/simplify` only for reuse and clean-up; it does not hunt bugs.
  *Why: two reviews of one diff report the same findings twice, and each costs a full read of the diff.*
- **`/code-review ultra` is the person's to start.** It runs in the cloud and is billed; suggest it, never launch it.
  *Why: it spends the person's money, which is their decision.*

## Building and fixing

- **A bug starts with `superpowers:systematic-debugging`,** a feature or fix built test-first with `superpowers:test-driven-development`, a multi-step task with `superpowers:writing-plans` or `ecc:plan`. They carry out core §1 (a check per step) and §2 (no speculative fixes); where they disagree with a core rule, the core rule wins.
  *Why: the skills give the order of steps; the core rules hold the costs that made the steps necessary.*
- **Library and API questions go to `context7` before memory.** Look up the version the project uses, then write the code.
  *Why: APIs change between versions, and memory answers with whichever version was most common, not the one installed.*
- **A UI change is seen in a browser.** Use the `playwright` tools to load the page and check the change, not only the tests.
  *Why: a passing component test does not show a layout that breaks, or a click that lands on the wrong element.*

## Git and GitHub

- **`commit-commands` follows the core git rules.** `/commit` stages and commits everything in one step, so use it only when the person asked for a commit and every changed file belongs in it; stage named paths otherwise. `/commit-push-pr` also pushes and opens a PR, so it needs a request for both. `/clean_gone` deletes local branches and worktrees: list them and confirm first (core §9). No AI attribution in any of them.
  *Why: these commands act in one step with no review pause, so a stray file or a wrong branch is already committed, pushed or deleted before anyone looks.*

## Claude setup and authoring

- **Writing a skill, hook or plugin uses its authoring skill.** `skill-creator:skill-creator` for a skill, `plugin-dev:*` for a plugin, hook, command or agent, `claude-md-management:revise-claude-md` to fold what a session learned into `CLAUDE.md`, `claude-code-setup:claude-automation-recommender` to find what is worth automating.
  *Why: each format has fields and loading rules that a hand-written file gets subtly wrong, and the mistake shows only as a skill that never triggers.*
