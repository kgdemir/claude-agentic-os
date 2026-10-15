# Personal data (privacy, KVKK / GDPR)

Applies to projects that store or process personal data: names, contact details, national ids,
location, recordings, health or payment data, or anything that identifies a person. Engineering
defaults, not legal advice. Tokens and logs: `~/.claude/guides/features/observability.md`.

- **Collect the minimum, each field with a stated purpose.** A personal field without a purpose written down (model comment, data inventory) is not added.
  *Why: data that is never collected cannot leak, and KVKK and GDPR both require purpose limitation.*
- **Keep a data inventory:** which personal data is stored where (tables, files, backups, third parties), why, and for how long (GDPR Art. 30 record of processing; KVKK data inventory).
  *Why: a deletion or breach request cannot be answered for data nobody knows exists.*
- **Every data class has a retention period, enforced by code** (a scheduled job that deletes or anonymises), not by a policy document alone.
  *Why: retention that nobody runs means everything is kept forever.*
- **Personal data never goes into logs, traces, error reports, analytics or URLs;** log ids, mask the rest.
  *Why: log stores are copied widely, kept long and rarely access-controlled like the database.*
- **Development and tests use synthetic or anonymised data,** never a production copy with real people in it.
  *Why: dev machines, CI artifacts and screenshots are where production copies leak from.*
- **Export and delete per person work end to end:** database rows, files, caches, search indexes, third-party processors; backups expire within the stated period.
  *Why: a delete that misses one store does not delete, and the request has a legal deadline.*
- **Sensitive fields are encrypted at rest at column or field level** (national id, health, payment), with keys outside the database; access to them is logged with who and when.
  *Why: disk encryption does not protect against a leaked backup or an over-broad query.*
- **Sending personal data to a new third party is a decision** (analytics, email, an AI API): listed in the inventory, with a processing agreement, and a check whether it leaves the country.
  *Why: KVKK and GDPR restrict transfers abroad, and an integration added "just to try" is a transfer.*
- **Consent is specific, recorded and withdrawable:** store what was agreed, the text version and the time; withdrawal is as easy as giving it.
  *Why: consent that cannot be shown later counts as no consent.*
