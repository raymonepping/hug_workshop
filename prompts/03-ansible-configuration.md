# Stage 3 — Configure PostgreSQL, Vault, and synthetic identities

Follow the [shared instructions](README.md#instructions-shared-by-every-prompt).
Prerequisites: stages 1–2 and their endpoint/runtime contracts.

Implement pinned Ansible requirements, a localhost inventory, and readable roles/
playbooks that configure the Terraform-owned services. Prefer supported modules
or Vault's API through `ansible.builtin.uri`; use fully qualified collection names.
Do not create/destroy the infrastructure from Ansible.

Deliver:

- Bounded service-readiness waits with actionable failures.
- An instance PostgreSQL schema and table matching the canonical dataset.
  Separate administrator/seeder and application roles. The app receives only
  connect/schema usage/select privileges required by the lab.
- Idempotent dataset import using a real JSON parser and efficient database import,
  with explicit stable ordering. Avoid row-by-row Podman invocations and shell SQL
  assembled from unescaped input.
- KV v2 at the canonical mount/path; explicitly configure userpass and AppRole.
- Personas from `workshop/users.yml`, preserving alphabetical order and stable
  generated passwords. Enforce albert read/denied write, brenda scoped management,
  and charlie authenticated-but-denied DB-secret read. No persona receives root.
- A read-only application AppRole; save the minimum bootstrap artifacts privately
  for the backend. Do not conflate the app role with the human personas.
- Private runtime file rendering, restrictive permissions, Ansible `no_log`,
  and non-secret endpoint inventory derived from Terraform outputs.
- Explicit recovery after Vault recreation: reconcile persisted DB credentials,
  restore Vault setup and refresh dependent AppRole/runtime files. Preserve passwords
  on ordinary reruns; credential rotation must be a deliberate operation.

Idempotence must reflect actual service state. Do not set `changed_when: false` on
all API calls to manufacture a clean second run. Report unavoidable lease/token
issuance separately from desired configuration changes.

Check playbook syntax, initial configure/seed, repeated configure/seed, row counts,
DB read-only privileges, all persona allow/deny cases, and AppRole least privilege.
Compare authenticated permission denial with invalid authentication. Restart Vault
on an isolated instance and prove reconfiguration restores consistency. Record
AC-05/06/08/10/11 evidence; redact credentials in test output and reports.
