# Local architecture and contracts

Podman is the engine and builder. Terraform's `kreuzwerker/docker` provider talks
only to the selected Podman compatibility socket; Docker Desktop/CLI is unnecessary.
Terraform owns containers, networks, volumes, and instance state. Ansible owns
service configuration and data. Make calls the portable Python orchestrator.

`workshop/config.json` defines the project ID, unique prefix, default host ports,
images, database, and KV path. Environment overrides are validated once by
`scripts/lab.py`. Each instance has `.workshop/<instance>/` and private files.
Human personas come only from `workshop/users.yml` (JSON is valid YAML).

The browser calls the backend on the loopback host port. The backend reads KV
credentials from Vault using a dedicated AppRole, then connects directly to
PostgreSQL using the read-only DB user. Internal services use container DNS;
Vault is not a DB proxy. Host URLs never leak into internal DB addressing.

## HTTP contract

`/ping`: HTTP 200 means the process is alive. `/health` always returns HTTP 200
with `ok` (process), `dbReady`, `mode`, `channel`, `unlocked`, and `state` fields;
readiness is a real query, not container/process liveness.

| State | `/api/items` | `unlocked` | Meaning |
| --- | --- | --- | --- |
| baseline | 200 | false | Environment DB credentials; no Vault completion |
| ready | 200 | true | AppRole and KV read succeeded, DB probe succeeded |
| exercise_incomplete | 403 | false | Runnable learner seam is incomplete |
| vault_denied | 403 | false | Authentication or path authorization denied |
| vault_unavailable | 503 | false | Vault unreachable or timed out |
| db_unavailable | 503 | false | DB authentication/query/connection unavailable |
| configuration_error | 503 | false | Missing/invalid private configuration |

Public errors contain only stable state codes. Limits default to 32, cap at 100,
and invalid/nonpositive values return HTTP 400. Rows are `{id, idx, title}`, ordered
by `idx, id`. The health endpoint never returns secrets. Authorization is rechecked
on strict-mode requests (bounded network timeouts); overlapping reads share only
an in-flight operation, never a completed credential result. No stale DB handle grants
access. Requests use their own short-lived DB connection and close it reliably.

## Secrets and lifecycle

Bootstrap files live in the instance's `bootstrap/` directory (0700, files 0600).
Only PostgreSQL receives its admin password file; only Vault receives its dev root
token file. The backend mounts only `app/`, containing app DB baseline credentials
and AppRole IDs, never human passwords or the Vault root token. JSON contracts are
private; ordinary status and Terraform outputs show endpoint/naming metadata only.

Vault dev storage disappears on restart. Re-run `make configure` to recreate
mounts, ACLs, personas and AppRole artifacts using the retained DB credentials.
`down` reconciles a Terraform setting that removes containers/network but preserves
the DB volume. `destroy` deletes the selected instance's Terraform resources;
`reset` removes its runtime directory only after successful destruction.

## Fixed core schema

Database `workshop`, application role `workshop_app`, and KV mount/path
`kv/data/workshop/db` are fixed core schema invariants, documented in config.json.
They are not operator overrides: changing them requires updating the DB/Vault roles
and backend contract together. Instance names, prefixes, ports, profile, edition
and image choices provide the reusable environment controls. A temporary prefixed
Podman test container is a test process, not a competing persistent service owner.
