# Validation evidence

Date: 5 November 2026. Host: macOS ARM64, Podman client 6.1.4/server 5.7.1,
Terraform 1.14.2, Python 3.15.1, Node 25.2.1 (host-only checks).

Results are appended by implementation stage. Linux/WSL2 and native AMD64 runs
remain unverified until tested; a manifest check is not a native execution result.

## Stage 1

Contract tests cover invalid instance/port/profile inputs, distinct instance paths,
alphabetical personas, all 500 canonical records, and the 32-letter acrostic.
The original ignored Vault reader was preserved privately before creating the
tracked learner seam. Legacy app paths remain until their replacements exist.

## Stage 2

Both `npm ci` installs passed after reducing the backend to pinned PostgreSQL-core dependencies.
`make doctor`, provider init/validate, Podman builds and Terraform apply passed for
`INSTANCE=check` with ports 25432/28200/23004/25173. All four containers run.
`make down` followed by `make infra AUTO_APPROVE=1` recreated services and retained
the DB volume. A repeated plan reports no changes after handling Podman's injected
IPAM/RLIMIT defaults narrowly. Generated credential values are absent from local
Terraform state. PostgreSQL and Vault manifests include both ARM64 and AMD64.
Other native platform runs remain pending; raw state and logs stay ignored.

## Stage 3

Pinned isolated Ansible 2.21.3 on Python 3.13 configures DB roles/schema, KV v2,
userpass personas, scoped ACLs, AppRole, and private runtime files. Both playbooks
pass syntax checks. Configure/seed repeat with `changed=0`, `failed=0`. Real checks
pass for all three personas' authentication, read/write/admin denials, AppRole
read-only scope, 500 rows and denied DB inserts/table creation.

Per user steering, Podman remains the engine and a local nonempty VAULT_LICENSE
auto-selects Enterprise 2.2.1 (same version family as the read-only vault_crypto
reference). The value is read without executing .env, stored only in a 0600 file,
and mounted using VAULT_LICENSE_PATH. Community 1.21.1 and Enterprise 2.2.1 were
both exercised. Enterprise manifest includes ARM64/AMD64. Its configuration also
converges after recreation. Credentials and license were checked absent from local
Terraform state and Vault stdout/stderr logs. Python 3.15 cannot run this Ansible
version; tooling now explicitly selects supported Python 3.12–3.14 instead.

## Stage 4

Seven `npm test --prefix backend` tests pass: no env bypass on strict failures,
baseline provenance, 12 concurrent independent connections closing, failed probe
cleanup, incomplete starter, token revocation after denied KV reads, and HTTP
limit/error contract. Podman rebuild/apply proves the actual starter returns 403,
and explicit PROFILE=solution performs AppRole/KV access and reveals 32 ordered
initials. Temporarily denying the app policy yields 403 and unlocked=false despite
valid baseline DB credentials; restoring it recovers on the next request.
The reference checks authorization on every request and revokes its temporary token.
