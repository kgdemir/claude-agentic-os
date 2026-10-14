# Child processes

Applies whenever code starts another program and waits on it, in any language (.NET
`Process`, Python `subprocess`, Node `child_process`, Go `os/exec`). Each trap here was hit in
real code and fails silently: the call hangs or returns, and nothing reports the cause.

- **Drain both pipes.** When you redirect standard output and standard error, read both. A full pipe buffer blocks the child process, and the parent then waits for an exit that cannot happen.
- **Kill in `finally`.** A timeout usually arrives as a cancelled wait, not as a dead process. Unless the process is killed on every exit path, including cancellation, it keeps running after the call returns.
