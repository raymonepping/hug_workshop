# Stage 2 — Provision local infrastructure with Terraform

Follow the [shared instructions](README.md#instructions-shared-by-every-prompt).
Prerequisite: stage 1's actual contracts, not assumptions about its implementation.

Implement `infra/` as a local Terraform root using a pinned Docker provider and
committed provider lockfile. Build PostgreSQL, Vault, backend, and frontend images/
containers from the declared image/source configuration. All instance lifecycle,
network, volume, and container ownership belongs to Terraform.

Requirements:

- Local state is explicitly selected per instance under `.workshop/`. Never run
  the old root HCP module by accident or require `terraform login`.
- Use the recorded unique prefix and ownership labels on every resource. Validate
  names/ports before apply. Allow multiple instances without shared secrets/state.
- Use an instance network and persistent PostgreSQL volume; default to native
  architecture. Verify chosen upstream image manifests for ARM64 and AMD64.
- Use disposable Vault dev mode as specified, bootstrap material in private files,
  and clear readiness checks. Never hardcode a common root token in Git.
- Implement staged bootstrap so containers can start before service configuration
  and restart with app credentials afterward. Missing AppRole files must produce a
  recoverable locked state rather than a missing mount or crash loop.
- Keep DB/bootstrap credentials out of ordinary Terraform outputs; use private
  files or mounts where practical. Inspect the resulting local state for secret
  exposure and document unavoidable fields without printing their values.
- Bind host ports to loopback and distinguish host URLs from container DNS URLs.
- Update Dockerfiles to build from committed lockfiles without `.env`, local state,
  assistant tooling, or installed host dependencies in image contexts.
- Export only the non-secret metadata needed by Ansible and verification.
- Define Terraform-supported running/stopped lifecycle behavior for `down` that
  preserves data volumes and lets `infra` recreate the running instance cleanly.

Do not configure Vault policies/users or the DB schema through Terraform. Do not
use `local-exec` as a replacement for an Ansible configuration stage or create
resources outside Terraform through Compose.

Run formatting, initialization, validation, and a reviewed local plan. When Docker
is available, build/apply only this lab, verify readiness/metadata, and verify a
second unchanged plan. Test `down`/recreate and destroy on an isolated instance,
including failure behavior. Never destroy an unrelated pre-existing lab to test.
Record evidence for AC-01/02/04/12 and architecture limitations under AC-03.
