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

## Stage 5

Two Chromium/Playwright tests pass against the actual viewer: real AppRole unlock,
32 rows and the acrostic; 404 for private/source/package paths; mobile layout and
typing an r inside the API input. Intercepted API fixtures prove baseline remains
labelled, even a vault-kv channel cannot override unlocked=false, denied/unavailable
transitions clear old rows/reveal, and id/idx/title hostile HTML renders as text.
A mobile screenshot was inspected and remains in ignored .workshop/. The viewer
serves only public assets and a non-secret runtime endpoint.

## Stage 6

`make test INSTANCE=check`: eight Python contract/lifecycle safety tests plus seven
backend tests inside a scoped ephemeral Podman test container pass. `make verify`
asserts real persona/AppRole policies, read-only DB privileges, API shape/order/limits,
policy denial with valid baseline credentials, recovery, frontend private-path denial,
private permissions and credential exclusion from state. It intentionally performs
one same-value brenda write and a temporary app-policy denial/restoration.

`python3 tests/live_lifecycle.py` passed against disposable community-Vault instance
cycle on ports 35432/38200/33004/35173: up/verify; configure/seed with changed=0;
down/up retaining data and credentials; Vault restart and missing app-file recovery;
DB interruption and recovery; reset with new credentials; verify/destroy. All prior
container IDs survived, including the separate licensed check instance. Logs are
private under .workshop/validation. A port-preflight TIME_WAIT false positive was
fixed and the full lifecycle rerun passed. Overlapping mutation processes fail
clearly; status/doctor remain read-only and available. Destruction without matching
CONFIRM and wrong-owner state are rejected; failed teardown retains runtime data.

## Stage 7

New setup, participant, facilitator, troubleshooting and extension guides describe
the implemented Podman/Make flow. Sixty-eight local Markdown links/anchors resolve.
The old guides/connectors are explicitly historical under docs/legacy; HCP root
Terraform, onboarding/agent/drift scripts, Compose, old env examples and encrypted
seed workflow are retired. The canonical plaintext puzzle and portable generator
remain. Local .env/license and other ignored user files were preserved.
Application lockfiles were refreshed and both clean npm installs passed after
removing unused dotenv. The incomplete-error unit fixture now injects that error
so completing a learner file will not make unrelated unit tests fail. A real
fresh-clone starter checkpoint is checked separately in stage 8.
