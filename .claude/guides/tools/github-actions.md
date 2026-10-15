# GitHub Actions

Applies to repositories with `.github/workflows/`.

- **CI runs the same `tools/` scripts as a local run** (`tools/build.sh`, `tools/test.sh`, `tools/lint.sh`), not a second copy of the commands in YAML.
  *Why: two copies drift, and "passes locally, fails in CI" (or the reverse) follows.*
- **Third-party actions are pinned to a full commit SHA,** with the version in a comment: `uses: actions/checkout@<40-char-sha> # v4.2.2`. Let the dependency bot bump them (`package-ecosystem: github-actions`).
  *Why: a tag can be moved to malicious code after you reviewed it; a SHA cannot.*
- **Least-privilege token.** Set `permissions: contents: read` at the top of every workflow and grant more per job only where needed (`pull-requests: write`, `id-token: write`).
  *Why: the default token can be write-all; a compromised step then pushes code or edits releases.*
- **Untrusted input never goes straight into `run:`.** Pass `${{ github.event.pull_request.title }}`, branch names, issue bodies and similar through `env:` and quote the variable in the script.
  *Why: `${{ }}` is pasted into the script before the shell runs, so a crafted title becomes shell commands (script injection).*
- **No `pull_request_target` that checks out or runs the PR's code.**
  *Why: that trigger runs with repository secrets and a write token; running fork code under it hands both to the fork author.*
- **Cancel superseded runs and bound every job:** `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }` for PR workflows, and `timeout-minutes` on each job.
  *Why: the default job timeout is 6 hours; a hung step burns runner minutes and blocks the queue.*
- **Secrets come from repository or environment secrets, or OIDC** (`id-token: write` with a cloud role) instead of long-lived cloud keys. Deploy jobs use a protected `environment:` with required reviewers.
  *Why: a long-lived key in secrets is one leak away from permanent access; OIDC tokens expire in minutes.*
- **Cache by lockfile hash** (`actions/setup-node` `cache:`, `actions/setup-dotnet` with `cache: true`, or `actions/cache` keyed on `hashFiles('**/packages.lock.json')`).
  *Why: a cache keyed on anything else restores stale dependencies after an update.*
- **Required checks are set in branch protection** for the default branch, matching the job names CI actually runs.
  *Why: a green workflow that nothing requires does not stop a red merge.*
