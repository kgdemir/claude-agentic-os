# Observability (logging, tracing, metrics)

Applies to projects that log beyond the console or export traces/metrics (Serilog, OpenTelemetry,
Prometheus, a log table or sink).

- **Tokens never appear in URLs that get logged.** Client libraries log the URLs they call, and proxies log query strings. Where a token must travel in a query string (WebSocket / SignalR negotiate `access_token`), set the client library's log level explicitly (Warning in production) and drop query strings from proxy access logs.
  *Cost: a realtime client left at its default log level printed the negotiate URL with a live JWT into every user's browser console in production; a proxy access log stored WebSocket `?token=` values.*
- **User-supplied values are neutralised before they enter a log line:** strip CR, LF and the Unicode line and paragraph separators (`U+2028`, `U+2029`), or log them as structured properties only.
  *Cost: stripping only `\r\n` from a user-controlled name was incomplete; a second fix had to strip `U+2028`/`U+2029` too.*
- **Route errors by what they mean, not by their exception type.** A sink that diverts "database exceptions" away from the database log must divert only connection-level failures; a constraint violation on a healthy connection is a normal error and must reach the normal log.
  *Cost: a foreign-key violation that broke first login was invisible in all the places an operator looks, because every `SqlException` was routed to a disk file on the theory that the database was down.*
- **Structured logs, not formatted strings;** never log secrets, tokens, passwords or full personal data.
  *Why: structured fields can be searched and redacted; a formatted string cannot.*
- **Metric labels have bounded values** (status code, route template, never user id, raw URL or message text).
  *Why: every distinct label value is a new time series; unbounded labels exhaust the metrics store.*
