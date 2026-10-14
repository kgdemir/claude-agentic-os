# Realtime and media features

Applies when a project has realtime messaging (WebSocket, SignalR, Socket.IO, SSE) or live
audio/video (WebRTC, an SFU such as mediasoup or LiveKit). Adds to the core docs rules in
`~/.claude/guides/core/project-docs.md`.

- `README.md` architecture table: one line naming the realtime and media transport.
- `capabilities.md` tech stack: the realtime and media components with versions and the
  decision behind each.
- `capabilities.md` API section: realtime hubs or channels with their methods, server events and
  contracts, next to the HTTP routes.
