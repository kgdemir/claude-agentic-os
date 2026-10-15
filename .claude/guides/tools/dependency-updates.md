# Automated dependency updates

Applies to projects with package dependencies and a remote repository (GitHub Dependabot or
Renovate). The decision rule for adding dependencies is core: `~/.claude/guides/core/agent-working-rules.md` §9.

- **Every project with dependencies has an update bot,** covering each ecosystem it uses, including `github-actions` and `docker`.
  *Why: dependencies left alone collect known vulnerabilities, and a year of skipped updates becomes one risky big-bang upgrade.*
- **Group minor and patch updates; take majors one at a time.** Starting point for `.github/dependabot.yml` (one block per ecosystem: `nuget`, `npm`, `pip`, `docker`, `github-actions`):
  ```yaml
  version: 2
  updates:
    - package-ecosystem: "npm"
      directory: "/"
      schedule:
        interval: "weekly"
      open-pull-requests-limit: 10
      groups:
        minor-and-patch:
          update-types: ["minor", "patch"]
  ```
  Renovate equivalent: `"extends": ["config:recommended"]` with a `packageRules` group for `minor` and `patch`.
  *Why: one PR per patch floods review until people stop reading them; a grouped major hides which package broke the build.*
- **An update PR merges only with CI green,** the same gates as any other change. A major bump also gets a smoke test of the running app and a read of the release notes for breaking changes.
  *Why: a passing build proves it compiles, not that it behaves the same; majors are where behaviour changes.*
- **Security updates are not batched behind the weekly schedule.** Keep Dependabot security updates (or Renovate `vulnerabilityAlerts`) on, so they open as soon as an advisory lands.
  *Why: a known exploit waits for nobody's schedule.*
- **Never auto-merge a major,** and auto-merge minors and patches only where tests cover the dependency's use.
  *Why: auto-merge without coverage ships whatever the new version does.*
