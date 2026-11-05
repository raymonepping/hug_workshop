# Stage 1 — Define the runnable workshop foundation

Implement this stage following the [shared instructions](README.md#instructions-shared-by-every-prompt)
and [PRD](../docs/PRD.md). Read the existing app and historical analysis first.

Create the repository foundation for the local Terraform/Ansible/Make workshop.
Preserve useful application code and synthetic data. Do not remove working legacy
provisioning until its replacement is available.

Deliver:

- `docs/IMPLEMENTATION.md` with the stage checklist, tool ownership, final directory
  choices, configuration schema, and a requirement-to-file/test map using AC IDs.
- `docs/ARCHITECTURE.md` with host/browser/container endpoint distinctions,
  bootstrap-to-app secret flow, per-instance naming/state boundaries, and restart
  behavior. Define exact `/health` and data endpoint status codes for baseline,
  locked, Vault-denied, DB-unavailable, and success states.
- `workshop/users.yml`, ordered albert/brenda/charlie with the PRD policy assignments;
  keep generated passwords out of this file.
- A canonical dataset under `workshop/`, validating unique IDs, ordering, title
  shape, and its 32-letter puzzle. Consolidate duplicate source locations with
  references updated; do not make the plaintext puzzle a claimed security control.
- A small configuration contract for project ID, instance, prefix, ports, endpoints,
  DB names, Vault paths, and private runtime files. Specify how later stages consume
  it without making Terraform and Ansible independently invent defaults.
- Reproducible application dependencies: resolve and commit both npm lockfiles,
  verify `npm ci` against them, and revise ignore rules narrowly. Preserve existing
  local environment values. Explicitly declare/pin provider and Ansible dependencies
  as those components are introduced; commit their appropriate lockfiles.
- A tracked Vault-reader starter that imports successfully and reports an intentional
  unimplemented/locked state. Preserve any existing ignored local solution before
  replacing its path; do not publish it as the learner's implementation.
- Root `make help` and read-only `make doctor` foundation. Future unsupported targets
  must fail with a clear pending-stage message rather than silently succeed.

Choose an isolated supported Python/Ansible installation strategy. Host Node is
optional for the delivered container workflow. Record actual tested tool versions
without inventing portability results.

Check configuration uniqueness/validation, synthetic user order, dataset shape,
fresh dependency installation, runnable starter imports, and help/doctor behavior.
Doctor must not require credentials or create infrastructure. Record AC-01 and
the foundation coverage for AC-03/06/09/11; remaining acceptance stays pending.
