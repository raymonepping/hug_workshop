# Completed participant exercise run

Date: 5 November 2026. Instance: `hug-b1e7c4-default`, macOS ARM64,
Podman, local Vault Enterprise 2.2.1 with a private license.

This run follows the five core exercises in [the participant guide](EXERCISES.md).
The ideas in [follow-up labs](EXTENSIONS.md) are separate projects, not additional
implemented participant exercises.

## Boundaries demonstrated

Terraform owns the four service containers, their network and retained database
volume. Ansible converges the PostgreSQL roles, dataset, Vault mounts, policies,
userpass users and application AppRole. Make sequences those operations.

Baseline mode obtains DB credentials from private environment configuration. It
can read data while `unlocked=false`; DB connectivity does not prove Vault access.
The completed participant reader uses AppRole, retrieves only the approved KV v2
credentials, and revokes its temporary token. It never uses a human or root token.

The persona decision matrix is independent of the application's service identity:

| Persona | Read approved KV | Write approved KV | Vault administration |
| --- | --- | --- | --- |
| albert | Allowed | Denied | Denied |
| brenda | Allowed | Allowed | Denied |
| charlie | Denied | Denied | Denied |

All three can authenticate. Charlie's successful login does not grant access to
the secret. The application's AppRole can read but cannot write the KV path;
the PostgreSQL service role can select but cannot insert or create tables.

The 32 ordered title initials reveal **WE ARE THE GUARDIANS OF OUR OWN SYSTEMS**.
Ordering and access decisions are verified by actual API requests. This public
acrostic is a teaching puzzle, not a cryptographic protection mechanism.

A policy denial is an authorization failure (`vault_denied`); Vault transport or
service failure is `vault_unavailable`. A DB failure occurs after credentials
are obtained and reports `db_unavailable`. Strict mode withholds data on failure;
baseline connectivity never substitutes for a failed Vault authorization.

## Execution evidence

- `make doctor`, `make plan`, and `make up PROFILE=starter MODE=baseline
  AUTO_APPROVE=1` passed. Actual baseline health reported DB ready, channel `env`,
  and `unlocked=false`; the API returned 32 rows.
- Repeated `make configure` and `make seed` passed with `changed=0`, `failed=0`.
- Implemented the learner reader in `backend/vault.js`, keeping `PROFILE=starter`.
  Direct reader checks passed for bounded requests, flat credential output,
  denied-path error mapping and token revocation on success and denial.
- `make build`, `make infra PROFILE=starter MODE=required AUTO_APPROVE=1`,
  `make test`, `make verify` and `make test-browser` passed. The completed
  participant implementation, rather than the facilitator profile, served the
  real Vault unlock. Python's eight checks, seven backend tests and two Chromium
  tests passed; the verifier proved real policy denial/recovery, 500 seeded rows,
  read-only DB privileges, API limits/order, private-file boundaries and runtime
  privacy.
- All nine `make persona USER_NAME=... ACTION=...` combinations passed with the
  expected decisions above.

Private command logs and the temporary completed reader are retained under
`.workshop/exercise-run/`. They are ignored by Git. The tracked learner stub is
restored before resetting, so the next participant receives the original exercise.

## Reset and shutdown

`make reset INSTANCE=default PROFILE=starter MODE=required CONFIRM=default
AUTO_APPROVE=1` passed after the original learner stub was restored. Private
fingerprint comparisons confirmed regeneration of all three persona passwords,
the app password, PostgreSQL admin password and Vault root token. No values were
printed. Post-reset checks passed for 500 seeded rows, persona/AppRole scope,
read-only DB privileges and runtime privacy. The starter reported
`exercise_incomplete`, `unlocked=false`, and denied item reads with HTTP 403.

`make down INSTANCE=default AUTO_APPROVE=1` then passed. Scoped Podman checks
confirmed no default-instance containers or network remain, while
`hug-b1e7c4-default-data` is retained. The saved profile is `starter` and mode
`required`. Restart with `make up`; the workshop begins at the original learner
checkpoint with the new UI.
