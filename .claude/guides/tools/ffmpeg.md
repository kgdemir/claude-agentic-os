# ffmpeg / ffprobe

Applies whenever a project calls `ffmpeg` or `ffprobe`, from any language. Both traps below
return a plausible result instead of an error. Running them as child processes:
`~/.claude/guides/tools/child-processes.md`.

- **Media duration: read the packets, not the header.** A file cut short by a crash can keep a header claiming its full length, and a file still being written has no final duration at all. `ffprobe -show_entries format=duration` reported 30 s for a file holding 18 s of audio. Reading through the packets (`ffmpeg -i <file> -map 0 -c copy -f null - -progress pipe:1 -nostats`, take the last `out_time_us`) reported the true 18.1 s.
- **Put global ffmpeg options before `-i`.** Builds older than version 5 ignore options that trail the last output, so a progress report requested at the end silently produces nothing — and the caller sees an empty result rather than an error.
