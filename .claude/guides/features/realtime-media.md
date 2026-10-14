# Realtime and media features

Applies when a project has realtime messaging (WebSocket, SignalR, Socket.IO, SSE) or live
audio/video (WebRTC, an SFU such as mediasoup or LiveKit). Adds to the core docs rules in
`~/.claude/guides/core/project-docs.md`.

- `README.md` architecture table: one line naming the realtime and media transport.
- `capabilities.md` tech stack: the realtime and media components with versions and the
  decision behind each.
- `capabilities.md` API section: realtime hubs or channels with their methods, server events and
  contracts, next to the HTTP routes.

Code rules (SignalR, WebSocket hubs, SFU signaling):

- **Refuse new hub connections while the host is stopping** (return `503`, which clients retry) and write no disconnect or reconnect history once shutdown has begun.
  *Cost: clients reconnected into the stopping process, which then wrote late "reconnected"/"disconnected" events after the new process had started, and every graceful stop waited the full 30 s shutdown timeout.*
- **Order state broadcasts per entity with a sequence number** stamped under the same lock that changes the state; clients keep the newest number and drop older messages and snapshot entries.
  *Cost: a fast rejoin's "joined" event overtook the "reconnecting" event of the drop before it and left a peer stuck showing "reconnecting".*
- **A late message never recreates ended state.** Every handler except the one that creates the room/call/session is a no-op when the target no longer exists.
  *Cost: a mute or leave arriving after a call ended created a room that nothing removed for the life of the process.*
- **Rate-limit per-user state changes that write history or fan out** (e.g. 30 per 10 s), refuse starts before any SFU resource is created, and log one warning per window.
  *Cost: a client toggling media in a loop could fill the history writer's queue, dropping other users' rows.*
- **Client logging is set explicitly for every connection builder** (Warning in production); see `~/.claude/guides/features/observability.md` for tokens in negotiate URLs.
  *Cost: same incident as the token rule in `~/.claude/guides/features/observability.md`.*
- **Every hub method checks that the caller may act on the target** (member of the room, party to the call), not only that they are signed in.
  *Why: a signed-in user can call any hub method with any id.*
