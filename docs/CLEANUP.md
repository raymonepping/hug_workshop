# Cleanup before the local workshop revision

Date: 5 November 2026.

This cleanup preserves the existing application and provisioning source while
removing generated artifacts and historical participant data. The user moved
the workshop documents into this directory; those moves are preserved.

## Removed

| Files | Reason |
| --- | --- |
| Root `terraform.tfstate` and its three backups | Explicitly authorized local state cleanup. Current state had zero resources; each backup recorded eight historical HCP resources. |
| `.terraform/` | Regenerable provider/module cache. |
| Root and backend `.DS_Store` | macOS metadata. |
| `scripts/dataset.out` | Byte-for-byte duplicate of `scripts/dataset.jsonl`. |
| `scripts/tickets.csv`, `scripts/tickets.json`, `scripts/tickets_extended.json` | Historical local attendee exports. |
| `scripts/lines.txt` | Historical generated scratch output. |
| `scripts/attendees.auto.tfvars.json` | Historical attendee data; not consumed by the root Terraform module. |
| Both ZIP files under `credentials/` | Historical unencrypted participant/credential packages. |
| All five JSON files under `scripts/output/` | Historical generated reports, including two empty files. |
| `scripts/FOLDER_TREE.md` | Obsolete generated directory snapshot. |

Deleting state files does not destroy or revoke anything in HCP. Old resource
records are no longer available locally for Terraform management. Remote resources
and credential validity were not inspected. The Git history still contains
previously committed exports; this cleanup does not rewrite history or revoke
credentials.

## Preserved

- Existing backend/frontend code and all database connectors.
- The dataset, encrypted dataset, and generator/seeder source.
- Existing HCP Terraform configuration and utility scripts, until their
  replacements are implemented through the prompts.
- Local `.env` files, the ignored Vault reader, installed Node dependencies,
  and dependency/provider lockfiles.
- Existing documents in `docs/`, including the historical project analysis.
- Local assistant tooling, excluded from commits.

During commit, `commit_gh` also removed `assignment_mode.auto.tfvars` and
`locked_users.auto.tfvars` from tracking because the user's global ignore rules
exclude `*.tfvars`. Both files remain on disk; their contents were not changed.

The PRD defines the intended replacement; the older source is not presented as
an already-working local Terraform/Ansible implementation. Generated credential
and report locations plus `.workshop/` and saved plans are now ignored.

## New planning material

- [PRD](PRD.md): scope, ownership, commands, identities, and acceptance criteria.
- [Prompt sequence](../prompts/README.md): staged implementation instructions.

Commits and GitHub pushes use the user's `commit_gh` workflow.

## Validation of this change

- All 31 local Markdown links across README, docs, and prompts resolve, including
  prompt-section anchors.
- The six moved workshop guides match their previous contents byte for byte.
- State/cache removal, preserved environment/lockfiles, and generated-file ignore
  rules were checked explicitly.
- Eight numbered prompts exist in dependency order; `git diff --check` passes.
- Runtime source and infrastructure configuration were not modified or executed.
  This change does not validate the future Terraform/Ansible implementation.
