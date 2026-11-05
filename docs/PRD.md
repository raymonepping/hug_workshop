# PRD — Unlock the Data: local workshop

Status: implementation specification; the new variant is not implemented yet.
Date: 5 November 2026.
Baseline: the existing HUG workshop reviewed in [PROJECT_ANALYSIS.md](PROJECT_ANALYSIS.md).

## Product intent

Turn the workshop into a repeatable local learning environment using Terraform,
Ansible, Make, Podman, PostgreSQL, and HashiCorp Vault. A participant can clone the
repository, provision the lab, configure services, demonstrate authorized and denied
access, and remove the lab without an HCP account or a facilitator's credentials.

The teaching sequence is **provision → configure → connect → secure → authorize →
verify**. Automation must expose these stages so participants can explain what
each tool owns. A facilitator convenience command must not obscure the exercises.

## Audience and delivery

- Engineers learning infrastructure automation and application secrets.
- Basic terminal, Git, and container familiarity; no HCP knowledge required.
- Target a two-hour core workshop after prerequisites and image downloads are
  complete. Validate that timing in a pilot; do not advertise it as measured yet.
- Self-paced and instructor-led delivery use the same repository.
- AI assistance is allowed. Completion requires observable behavior and an
  explanation of the trust flow, rather than a particular generated solution.

## Scope

The first release includes one working PostgreSQL path, local Vault, the existing
Node backend/frontend revised as needed, three synthetic identities, deterministic
data, readable automation, checkpoints, verification, and scoped teardown.

No required HCP organizations, agent pools, remote state, hosted Vault, registry
account, cloud subscription, real attendee data, Boundary, Kubernetes, or Terraform
Stacks. MySQL, MongoDB, and Couchbase remain historical source until separately
validated extensions; the new core must not advertise them as supported.

Dynamic database credentials are a follow-up lab. The core must genuinely use
Vault KV credentials and enforce its access boundary before extensions are added.
Full offline distribution and production hardening are outside the initial release.

## Portability contract

- Target macOS and Linux, plus Windows through WSL2; native PowerShell is outside
  the supported command surface.
- Target ARM64 and AMD64 without forcing x86 emulation. Verify the selected
  container images and dependencies on both architectures.
- Host tools: Git, GNU Make, Terraform, Python with an isolated Ansible install,
  and a reachable Podman engine. Application Node dependencies run in
  containers by default. List exact supported versions after verification.
- Respect the selected Podman API endpoint/connection; do not assume a fixed macOS socket.
- Use portable shell operations. Do not depend on GNU-only `sed`, `readlink -f`,
  Bash associative arrays, or `mapfile` without declaring/installing a compatible shell.
- Image and dependency downloads require internet during initial setup. Execution
  must not call HCP or a facilitator-operated service.
- Keep host-accessible endpoints bound to loopback. Use container DNS internally;
  separate browser URLs from container URLs.
- Provide configurable host ports and instance prefix, and diagnose conflicts.
  Multiple instances must have separate state, credentials, ports, and resource names.

## Tool ownership

| Component | Owner | Boundary |
| --- | --- | --- |
| Networks, volumes, images, containers | Terraform Docker provider against Podman’s compatible API | Local state, explicit resource labels and names |
| PostgreSQL roles/schema/grants and data | Ansible | Configure the existing DB; no competing container lifecycle |
| Vault mounts/auth methods/policies/users/KV | Ansible | Configure the existing Vault via supported API/modules |
| Local generated configuration | Ansible plus a small bootstrap helper | Private files, explicit schemas, no secrets in public output |
| Build/init/plan/apply/configure/verify ordering | Make | Delegate to tools; propagate failures |
| Secret retrieval, DB connections, API gating | Backend | Dedicated application identity |
| Health and authorized-data presentation | Frontend | Reflect backend authorization decisions |

Do not manage the same Podman resources with Compose and Terraform, or configure
the same Vault policies with both Terraform and Ansible. Compose may remain only
as a clearly labelled legacy/developer alternative outside the core lab.

Terraform output provides non-secret endpoint and instance metadata for Ansible.
Bootstrap secrets are generated privately outside Terraform where feasible and
mounted through ignored runtime files. Do not put credential values in Terraform
outputs or pretend that `sensitive = true` removes them from state.

## Proposed repository layout

```text
Makefile
infra/                  # local Docker Terraform root and committed provider lock
ansible/                # pinned requirements, localhost inventory, roles, playbooks
workshop/users.yml      # canonical ordered synthetic identity definition
workshop/dataset.jsonl  # canonical synthetic puzzle dataset
backend/                # tracked runnable starter and explicit exercise seams
frontend/               # viewer and public assets
scripts/                # small portable build/bootstrap/verification helpers
tests/                  # meaningful integration and contract checks
docs/                   # PRD, architecture, participant/facilitator guides
prompts/                # implementation prompt sequence
.workshop/              # ignored per-instance runtime files, state, credentials
```

Use `hug-` as a naming stem, followed by a short stable project identifier and a
trailing dash. Choose and check the unique literal prefix before first provisioning;
do not inherit a prefix copied from another project. Every destroy/reset operation
must scope itself to that project and the selected instance. Record the finalized
prefix and ownership conventions in local project instructions.

## Synthetic users and authorization

`workshop/users.yml` is the single ordered list: **albert, brenda, charlie**.
Use these exact lowercase names consistently. No surnames, email addresses,
company identities, HCP membership IDs, or copied historical passwords.

These are Vault workshop personas, not host OS accounts. The initial policy
assignments below are design defaults; make them data-driven and explain them:

| Identity | Core exercise role | Expected access |
| --- | --- | --- |
| albert | Reader | Authenticate and read the lab's approved DB KV secret; denied writes |
| brenda | Lab operator | Authenticate and manage the lab's approved KV secret; no Vault system administration |
| charlie | Restricted user | Authenticate successfully; denied reading the DB KV secret |

Use Vault `userpass` for these human CLI exercises. Keep the backend's service
identity separate: a dedicated AppRole with read-only access to the required KV
path. The DB application role is also separate and receives only the grants
needed to read the dataset. Seed/admin database credentials are not application
credentials. No browser persona dropdown may impersonate a user by changing a label.

Generate local persona passwords and bootstrap credentials once per instance;
retain them across normal reruns. Use an explicit local-only credential retrieval
step in the guide, not routine log output. Apply restrictive permissions to secret
files and `no_log` to Ansible tasks that handle secrets. Never send the bootstrap
Vault token to the frontend or backend.

## Local Vault lifecycle

For the core, use a disposable local Vault dev server with an explicitly documented
in-memory lifecycle. This avoids making initialization/unsealing a prerequisite
for a two-hour workshop. It is a lab mode, not a production configuration.

Generate a local bootstrap token outside source control; do not commit a shared
root token. Configure KV v2 and the persona/AppRole policies through Ansible.
An ordinary rerun must reuse a healthy running Vault. Restarting/recreating it
loses Vault configuration and requires `make configure`, which must restore it
and refresh any dependent application bootstrap files/connections.

PostgreSQL data may persist in its instance volume. Reconfiguration must reconcile
existing DB passwords and newly created Vault secrets without silently diverging.
Persistent Vault with explicit initialize/unseal steps is a possible advanced lab.

## Learning stages

1. **Preflight:** identify prerequisites, chosen instance, ports, and Podman API endpoint.
2. **Provision:** inspect the Terraform plan, then create infrastructure locally.
3. **Configure:** run Ansible, inspect non-secret task results, and seed the dataset.
4. **Baseline:** demonstrate connectivity with environment credentials, explicitly
   labelled as baseline. Baseline data access must never count as a Vault unlock.
5. **Secure:** complete the Vault-reader exercise and obtain credentials through
   the application AppRole. Strict mode denies data if Vault retrieval fails.
6. **Authorize:** demonstrate albert's allowed read/denied write, brenda's scoped
   write, and charlie's authenticated-but-denied read.
7. **Verify:** prove ordered data, real credential provenance, and denial behavior.
8. **Teardown:** remove only this instance and explain what was deleted.

Ship a runnable starter with a tracked `backend/vault.js` interface that can report
an intentional unimplemented/locked state. Facilitator solutions must be separate
and explicitly selected. Do not rely on an ignored local solution to make a build
work. Do not automatically copy a solution into participant code.

## Command contract

All commands run from the repository root. `make help` is the default target.
Use `INSTANCE=default` and documented port overrides consistently across targets.

| Target | Required behavior |
| --- | --- |
| `make doctor` | Read-only prerequisite, daemon, version, architecture, and port diagnostics; useful nonzero failures |
| `make init` | Initialize the per-instance runtime directory, pinned tooling, provider backend/state location |
| `make build` | Build local images from tracked source and lockfiles; never push automatically |
| `make plan` | Preview infrastructure changes for this instance without applying |
| `make infra` | Provision/update infrastructure; interactive apply by default, explicit automation override |
| `make configure` | Wait for services, configure Vault and PostgreSQL, generate private runtime files; safe to repeat |
| `make seed` | Idempotently import the canonical dataset |
| `make up` | Facilitator convenience: init/build/infra/configure/seed in dependency order; does not solve the learner task |
| `make status` | Report real service/DB/auth state without printing secrets |
| `make verify` | Run positive/negative core acceptance checks; fail clearly on an unfinished exercise |
| `make test` | Run implementation tests; clearly declare Podman prerequisites |
| `make down` | Remove instance containers/network while preserving named data volumes and state needed for reconciliation |
| `make destroy` | Terraform-managed removal including this instance's volumes; explicit destructive confirmation |
| `make reset` | Confirm destruction, destroy, remove this instance's runtime credentials/state only after success, and rebuild |

Implement `down` through the Terraform configuration/lifecycle, not unmanaged
Docker deletion that silently leaves Terraform state inconsistent. Dry runs/help
must not require credentials. Avoid embedding large shell programs in Make recipes.
`make -j` must not race destructive or ordering-sensitive targets.

## API, data, and UI contract

- Preserve `GET /ping`, `GET /health`, and `GET /api/items?limit=N` where practical.
- `/health` distinguishes process liveness, database readiness, mode, credential
  source, and authorization. Never claim readiness solely because a handle exists.
- Core data shape is `{id: integer, idx: integer, title: string}`. Return rows in
  explicit puzzle order and honor validated limits consistently.
- The existing 500-record synthetic dataset may be reused. Document that its
  initials are a puzzle and the plaintext file is not a security boundary.
- Required Vault mode cannot silently fall back to environment credentials.
  Denied Vault access produces a locked API response; unavailable infrastructure
  produces a distinguishable readiness error. Define exact status codes in the
  implementation contract and test them.
- Health polling and repeated initialization must not leak connections or issue
  uncontrolled concurrent Vault logins. Define bounded retries/timeouts and cleanup.
- Reconfigure/restart transitions must not keep displaying obsolete authorization.
  Define the core's authorization-check interval; immediate DB-session revocation
  is not implied by a cached Vault login. Dynamic lease renewal is outside core.
- The viewer consumes the backend's `unlocked` decision, differentiates baseline
  from Vault access, escapes all displayed values, and exposes no secret values.
- Serve frontend public assets from a dedicated directory, not the project root.
  Runtime configuration has one source and separate browser/container endpoints.

## Acceptance criteria

| ID | Evidence required |
| --- | --- |
| AC-01 | Fresh clone builds using tracked manifests/lockfiles and no private files. |
| AC-02 | Core runs without HCP credentials, accounts, agents, or external workshop services. |
| AC-03 | macOS/Linux/WSL2 instructions and ARM64/AMD64 support have recorded results or explicit unverified status. |
| AC-04 | Terraform owns only labelled instance resources; non-secret outputs feed Ansible. |
| AC-05 | Repeated configure/seed converge without duplicate rows or accidental password rotation. |
| AC-06 | Exactly albert, brenda, charlie appear in canonical order; policies enforce every allow/deny row above. |
| AC-07 | Baseline env mode never reports Vault unlock; failed Vault authorization never exposes dataset rows in strict mode. |
| AC-08 | Dedicated AppRole obtains KV DB credentials; application DB user can read but cannot administer the DB. |
| AC-09 | Data ordering, shape, limits, and the 32-letter puzzle are verified. |
| AC-10 | Vault outage/restart and reconfigure have documented, tested failure/recovery behavior. |
| AC-11 | Generated credentials/state stay ignored and private; routine logs/artifacts contain no credential values. |
| AC-12 | Scoped down/destroy/reset preserve unrelated Podman resources and never delete state before successful teardown. |
| AC-13 | Participant can finish with documented checkpoints and independently reproduce verification. |
| AC-14 | Final supported flow has no dependency on legacy HCP configuration or historical attendee exports. |

## Delivery and migration

Follow [the prompt sequence](../prompts/README.md). Keep the current source until
replacement paths exist; then remove or clearly archive HCP-only provisioning,
agent/drift/onboarding scripts, registry assumptions, and obsolete Compose flows.
Historical docs in this directory must be labelled historical or moved under
`docs/legacy/` with links repaired. Keep the PRD and new guides authoritative.

Track implementation status honestly. A static check is not an integration test;
testing one laptop is not proof of the entire portability matrix. Record exact
commands, environment, result, and remaining limits in `docs/VALIDATION.md`.

Use `commit_gh` for all commits and GitHub pushes. Do not bypass its secret scan,
stage local assistant tooling, rewrite Git history, or publish container images as
a side effect of ordinary workshop commands.

## Technical references

These describe capabilities and constraints; implementation must pin and test
actual versions rather than copying an unverified latest-version assumption.

- [Terraform local state and its handling](https://developer.hashicorp.com/terraform/language/state).
- [Terraform Docker provider against Podman’s compatible API](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs).
- [Ansible URI module for service configuration](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/uri_module.html).
- [Ansible on Windows through WSL or containers](https://docs.ansible.com/projects/ansible/latest/os_guide/intro_windows.html).
- [Vault dev-server lifecycle](https://developer.hashicorp.com/vault/docs/concepts/dev-server).
- [Vault AppRole](https://developer.hashicorp.com/vault/docs/auth/approle).

The duration, PostgreSQL-only core, persona permissions, AppRole application auth,
and disposable Vault default are specification choices to validate during delivery.
