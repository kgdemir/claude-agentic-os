# memsearch plugin

Applies when the memsearch plugin is installed.

- **Each project Claude runs for uses its own memsearch database.** Never search or write one
  project's memory from another; a shared database mixes unrelated facts and returns answers
  from the wrong codebase (ADR-0004 in the rules pack).
