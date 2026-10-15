# Background jobs and messaging

Applies to queues, message brokers, scheduled jobs and background workers (hosted services,
Hangfire, Quartz, RabbitMQ, Kafka, Azure Service Bus, SQS, Celery, BullMQ). .NET worker scopes:
`~/.claude/guides/stacks/dotnet-gotchas.md`. Retry policy for outbound calls:
`~/.claude/guides/features/resilience.md`.

- **Publish through a transactional outbox.** Write the message to an outbox table in the same transaction as the state change; a separate relay publishes it and marks it sent.
  *Why: "save, then publish" loses the message when the process dies between the two; "publish, then save" announces a change that was never stored.*
- **Assume at-least-once delivery; make every consumer idempotent.** Record processed message ids (an inbox table with a unique key) or make the handler's effect naturally repeatable.
  *Why: every broker redelivers after a timeout or crash; a non-idempotent handler then charges, mails or inserts twice.*
- **Retries are bounded, with exponential backoff and jitter, then a dead-letter queue** that someone is alerted about.
  *Why: unbounded immediate retries turn one bad message into a hot loop; a dead-letter queue nobody watches is data loss with extra steps.*
- **Messages carry ids and the minimum data, plus a schema version.** The handler loads current state by id.
  *Why: a message carrying a whole entity is stale by the time it runs, and an unversioned payload breaks consumers on the first field change.*
- **A scheduled job runs once across all instances.** Use the scheduler's clustering or a distributed lock with a lease (database row, Redis `SET NX PX`).
  *Why: scaling to two instances otherwise runs every nightly job twice.*
- **Long jobs are resumable.** Work in batches, commit a checkpoint per batch, and honour the cancellation token.
  *Why: a deploy or restart in the middle of a one-shot job either repeats all the work or leaves it half-done with no record.*
- **Every job logs a start, an end and a failure with its id,** and exposes its queue depth or lag as a metric.
  *Why: a stuck queue looks exactly like a quiet one until someone measures it.*
- **Graceful shutdown stops taking work, finishes or releases the current item, then exits** within the host's shutdown timeout.
  *Why: a worker killed mid-item leaves a message locked until its visibility timeout and work half-applied.*
