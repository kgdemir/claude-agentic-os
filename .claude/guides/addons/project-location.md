# Project location

Optional add-on: every project lives under one root folder, and a session started anywhere else
first asks which project to load. `install.sh` asks whether to enable it.

- **ALL** projects live at `{{PROJECT_ROOT}}/<project-name>/`. No exceptions.
- On session start, check working directory:
  - Inside `{{PROJECT_ROOT}}/<project-name>/` (or subfolder): proceed normally.
  - Anywhere else (including `{{PROJECT_ROOT}}/` root, `~`, or any other path): **before any other work**, list folders in `{{PROJECT_ROOT}}/` (`ls -d {{PROJECT_ROOT}}/*/`) and ask user which project to load via `AskUserQuestion` selector. Options: up to 3 existing projects (most recently modified first), then **"Create new project"** always as last option. User can type other existing name via "Other".
  - "Create new project" chosen: ask for project name, create `{{PROJECT_ROOT}}/<name>/`, load it.
  - After selection: treat `{{PROJECT_ROOT}}/<chosen>/` as project root. Use absolute paths into it for all reads/writes, and load its `CLAUDE.md` if present.
  - No projects exist: ask user for new project name, create `{{PROJECT_ROOT}}/<name>/`.
- New projects: always create under `{{PROJECT_ROOT}}/<project-name>/`, never elsewhere.
