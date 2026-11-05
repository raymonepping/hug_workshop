# Stage 4 — Implement the backend authorization boundary

Follow the [shared instructions](README.md#instructions-shared-by-every-prompt).
Prerequisites: stages 1–3; follow the agreed API contract and private bootstrap paths.

Refactor the backend for the PostgreSQL core, retaining useful code while making
the exercise seam explicit. Ship a tracked runnable starter interface and a
separately selected facilitator solution/reference. Do not auto-solve the learner
task during normal provisioning or hide essential code in ignored files.

Required behavior:

- Baseline env mode can demonstrate connectivity but never reports a Vault unlock.
- Required Vault mode logs in using the dedicated application AppRole and retrieves
  the canonical KV v2 DB credentials. It cannot silently fall back to `.env`.
- Authentication failure, authorized-path denial, Vault unavailability, DB connection
  failure, and an unimplemented exercise return the distinct agreed statuses. Never
  include credential values or raw upstream diagnostics in public error responses.
- Health reflects a bounded real readiness check and explicit authorization state,
  rather than trusting a forever-cached DB handle or arbitrary channel label.
- Define and implement the core's bounded reauthentication/authorization interval,
  recovery behavior, connection reuse/cleanup, and initialization concurrency guard.
  Document the distinction between Vault access and an already-open DB session.
- Serve items in canonical order with validated default/max limits and normalized
  `{id, idx, title}` fields. Database privileges enforce read-only app access.
- Honor declared TLS options or reject unsupported configuration clearly; do not
  parse and silently ignore them. Loopback-only lab HTTP must be labelled honestly.
- No bootstrap root token, persona password, or secret response reaches the browser.

Write meaningful tests with dependency seams for unit failures and real local
integration checks. Prove strict mode remains locked when valid environment DB
credentials are present but Vault is denied/unavailable. Verify concurrent first
requests, credential provenance, readiness after DB failure, Vault recovery, limits,
and public error redaction. Record AC-07/08/09/10/11 and remaining limits.

Dynamic database credentials/lease renewal are not a requirement of this stage.
