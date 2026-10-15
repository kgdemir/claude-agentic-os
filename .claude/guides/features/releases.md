# Releases (Conventional Commits, SemVer, changelog)

Applies to projects that tag releases, publish packages or images, or keep a `CHANGELOG.md`.

- **Commit messages follow Conventional Commits 1.0.0:** `type(scope): description`, with `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`. A breaking change adds `!` after the type or a `BREAKING CHANGE:` footer.
  *Why: a structured history is what lets a version bump and a changelog be derived instead of remembered.*
- **Versions follow SemVer 2.0.0:** breaking change bumps MAJOR, `feat` bumps MINOR, `fix` bumps PATCH. Below `1.0.0`, say in the README that anything may change.
  *Why: consumers decide whether an update is safe from the version number alone.*
- **Releases are annotated git tags `vX.Y.Z` on a commit that passed CI,** and the published artifact is built from that tag.
  *Why: an artifact built from a working tree cannot be traced back to the code it contains.*
- **`CHANGELOG.md` follows Keep a Changelog:** an `## [Unreleased]` section on top, then one section per version with its date, grouped as `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`. Written for users, not a dump of commit subjects.
  *Why: users need what changed for them; a commit log tells them what changed for the developers.*
- **A released version is never changed.** A fix is a new version; a tag is never moved or re-pushed.
  *Why: anyone who already pulled the old artifact now has a different thing under the same name.*
- **Release automation is optional and a dependency decision** (release-please, semantic-release, GitVersion): adopt it with a stated reason, like any other dependency.
  *Why: the conventions above work by hand; a tool earns its place by removing a step people actually forget.*
