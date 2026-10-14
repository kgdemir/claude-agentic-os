# Docker and Docker Compose

Applies to projects with a `Dockerfile` or `docker-compose*.yml` / `compose*.yml`.

- **Every Dockerfile builds in CI or a `tools/` script, after every project rename or move.** Build contexts stay inside the repository (no `../../` escapes), and each Dockerfile targets a project that still exists.
  *Cost: after a service split, one Dockerfile still built a deleted project and another escaped its build context; both were caught only in a final review, not by any build.*
- **Base images are pinned** to a version tag (`node:24.11-alpine`, `mcr.microsoft.com/dotnet/aspnet:10.0`), not `latest`.
  *Why: `latest` changes under you, and the same Dockerfile builds a different image tomorrow.*
- **No secrets in images:** not in `ENV`, `ARG`, copied files or layers. Pass them at runtime (env file outside git, Compose `secrets`, the orchestrator's secret store). `.dockerignore` excludes `.env`, `.git`, `node_modules`, `bin`, `obj`.
  *Why: every layer of a pushed image is readable by anyone who can pull it.*
- **Run as a non-root user** (`USER app`) unless the container truly needs root.
  *Why: a compromised process in a root container is root on everything the container can reach.*
- **Each long-running service has a `healthcheck`,** and `depends_on` uses `condition: service_healthy`.
  *Why: a started container is not a ready one; dependents otherwise connect too early and crash-loop.*
- **Hardware-specific settings live in an override file** (`docker-compose.gpu.yml`), not in the base file.
  *Why: a GPU reservation in the base file breaks `docker compose up` on every machine without that GPU.*
