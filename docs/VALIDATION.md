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

## Stage 8 — current acceptance

Acceptance candidate application source: commit `1baac15`. The final record below
includes the source-operation lock added to the fresh-checkout harness. All dates
in this document use 5 November 2026, Europe/Amsterdam.

Executed commands and results:

| Command/check | Result |
| --- | --- |
| `python3 -m unittest discover -s tests -v` | 8 Python contract/safety tests pass |
| `make test INSTANCE=default` | Python suite and 7 backend tests in native ARM64 Podman pass |
| `make verify INSTANCE=default` with explicit solution | Full real-service verifier passes on Enterprise 2.2.1 |
| `make infra INSTANCE=default PROFILE=starter AUTO_APPROVE=1` | Restores intentional learner lock; status reports exercise_incomplete |
| `python3 tests/live_lifecycle.py` | Community lifecycle, convergence, DB/Vault interruption, reset and scoped teardown pass |
| `python3 tests/fresh_clone.py` | Clean checkout, uncached application layers, no developer env/node_modules, community starter/baseline/solution, unit/core/browser checks and teardown pass |
| `make test-browser` inside clean solution checkout | 2 real Chromium tests pass |
| `terraform -chdir=infra fmt -check` and validate with instance TF_DATA_DIR | Pass |
| Both Ansible playbook syntax checks | Pass |
| `python3 scripts/check_docs.py` | All current local Markdown links/anchors resolve |
| Invalid/reserved instance, occupied port, missing tool | Preflight fails correctly without creating an instance directory |
| Added UPDATE grant then configure/repeat | First run reports changed=1 and removes drift; repeat reports changed=0 |
| Provider checksums for darwin_arm64/darwin_amd64/linux_arm64/linux_amd64 | Downloaded/verified and committed |
| Node/PostgreSQL/community Vault/Enterprise Vault manifests | All include ARM64 and AMD64 |
| `commit_gh` staged secret scans | Pass at each implementation commit |

The final concurrency unit check issues 12 simultaneous requests, verifies one
shared in-flight Vault retrieval and 12 closed DB clients, then verifies a later
request performs a new Vault read. Completed authorization is never cached.

The fresh-checkout harness creates a separate clone under ignored `.workshop/`,
with unique instance names and distinct loopback ports. Its application builds
use `--no-cache`; public upstream image caches may be reused. It verifies that a
fresh starter returns 403, baseline remains unlocked=false and fails the core
verifier, and explicit solution mode passes the real authorization checks. Named
before/after snapshots check pre-existing container identities. An initial final
snapshot observed our intentionally concurrent default-backend rebuild; the harness
now holds the source checkout's operation lock, and the isolated rerun passes.

Private evidence/logs stay under `.workshop/validation/` and the generated clean
checkout. No logs containing credentials or licenses are committed. The earlier
101-container snapshot passed, and the final isolated run independently verifies
its own before/after resource set. Temporary cycle/fresh service resources are
removed; the final default lab remains available in the learner profile.

### Acceptance coverage

| Requirement | Current evidence |
| --- | --- |
| AC-01 | Clean checkout and uncached application installs/builds pass |
| AC-02 | Unlicensed community run with no HCP credentials/services passes |
| AC-03 | macOS ARM64 passes; other native host targets explicitly unverified below |
| AC-04 | Scoped Terraform state, non-secret outputs and service ownership checked |
| AC-05 | Repeated configure/seed changed=0; credential/data retention tested |
| AC-06 | Exact ordered identities and all read/write/admin permission cases tested |
| AC-07 | Baseline, real denial with valid DB credentials, strict lock and recovery tested |
| AC-08 | Actual AppRole/KV access, app write denial and read-only DB enforcement tested |
| AC-09 | 500 records, shape, limits, explicit order and 32-letter puzzle tested |
| AC-10 | Vault restart, missing app file, DB interruption and reconfigure recovery tested |
| AC-11 | Permissions, state exclusion, app bootstrap separation, log/route checks and staged scans pass |
| AC-12 | Down/reset/destroy, wrong owner, no confirmation and failed teardown preservation tested |
| AC-13 | Guide commands exercised; timed participant pilot remains outstanding |
| AC-14 | Active automation audit finds no HCP execution dependency; historical material is labelled |

### Portability matrix and remaining work

| Environment | Execution status |
| --- | --- |
| macOS ARM64 + Podman machine Linux ARM64 | Full tested path; Podman client 6.1.4/server 5.7.1, Terraform 1.14.2, Python tooling 3.13, Node image 22.21.1 |
| Native Linux ARM64 host | Provider/image availability verified; host orchestration not executed |
| Native Linux AMD64 host | Provider/image availability verified; full execution not performed |
| macOS AMD64 host | Provider/image availability verified; full execution not performed |
| WSL2 | Setup documented; full execution not performed |
| Native Windows/PowerShell | Outside the supported command interface |

A Linux container running in a Mac Podman VM is not a native Linux host validation.
No emulated/native AMD64 run is claimed. On each remaining host, a maintainer should
run the following from a fresh clone and record exact tool versions/results:

```sh
make doctor
make up PROFILE=solution VAULT_EDITION=community AUTO_APPROVE=1
make test
make verify
make test-browser
python3 tests/live_lifecycle.py
make destroy CONFIRM=default
```

Browser maintenance checks additionally require host Node/npm. Run lifecycle and
fresh-checkout acceptance without concurrent lab mutations. The source guard
coordinates this checkout; unrelated project automation may still change its own
resources, in which case inspect named snapshots rather than claiming isolation.
A timed participant pilot and the optional advanced labs are not release evidence.

Final isolated clean-checkout evidence: `.workshop/fresh-547317`, against application
commit `1baac15`; all phases and named resource preservation passed. Its source
operation lock prevented overlapping source-checkout mutations during the run.
The licensed default solution was independently rebuilt and verified on the same
application source, then restored to the starter. Actual local license, root/admin,
persona and app credential values were checked absent from tracked content and
all default service log/config-environment output without printing those values.
The temporary check instance was destroyed afterward; only default's four project
containers remain. Its viewer is http://127.0.0.1:15173 with the intentional learner lock.

## UI refresh: Vault daylight glass

The workshop viewer now shares the visual family of `vault_dance` and
`vault_crypto`. Scoped Podman builds and Terraform applies passed against the
licensed default instance. Both Chromium tests pass at the final UI build:
real AppRole unlock and 32-row reveal, static private-path denials, local font
and SVG delivery, section navigation, expandable health details, API input
shortcut handling, and no horizontal page overflow at 390px. Intercepted API
checks retain baseline labelling, denial/error clearing and hostile HTML escaping.

Desktop (1440px) and phone (390px) screenshots were inspected. Numeric IDs were
adjusted to remain on one line on phones. Screenshots remain private under
`.workshop/viewer-desktop.png` and `.workshop/viewer-mobile.png`. This is browser
regression and visual evidence, not a full automated accessibility audit.

The default lab was restored to `PROFILE=starter`; its final health response
reports `exercise_incomplete`, `unlocked=false`, with the updated viewer served.
