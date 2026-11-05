# Local workshop implementation prompts

These prompts implement [docs/PRD.md](../docs/PRD.md). They are instructions for
future implementation, not evidence that the local workshop already exists.

Read [the historical analysis](../docs/PROJECT_ANALYSIS.md) and
[cleanup record](../docs/CLEANUP.md) first. Execute one stage at a time, inspecting
the previous stage's actual files and verification results before proceeding.

| Order | Prompt | Dependency | Main result |
| --- | --- | --- | --- |
| 1 | [Foundation](01-foundation.md) | PRD | Layout, contracts, synthetic users, reproducible dependencies |
| 2 | [Local infrastructure](02-local-infrastructure.md) | 1 | Local images and Terraform-managed Docker services |
| 3 | [Ansible configuration](03-ansible-configuration.md) | 1–2 | DB, Vault, policies, personas, seed data |
| 4 | [Backend and Vault](04-backend-vault.md) | 1–3 | Real strict-mode access and learner/solution separation |
| 5 | [Frontend](05-frontend.md) | 4 | Accurate baseline/locked/unlocked feedback |
| 6 | [Make and verification](06-make-verification.md) | 2–5 | Complete command surface and meaningful checks |
| 7 | [Workshop documentation](07-workshop-documentation.md) | 1–6 | Participant/facilitator guides and legacy retirement |
| 8 | [Acceptance and portability](08-acceptance-portability.md) | 1–7 | Fresh-clone validation, recovery, isolation, release evidence |

## Instructions shared by every prompt

1. Read root and nested `AGENTS.md`, `docs/PRD.md`, and relevant implementation
   files. User instructions take precedence. Preserve unrelated/user changes.
2. Follow the PRD's division of ownership: Terraform provisions; Ansible configures;
   Make orchestrates; backend enforces access; frontend reports it.
3. Scope infrastructure to a unique recorded project/instance prefix. The PRD's
   `hug-` is a naming stem; append a stable unique project identifier before first
   provisioning and check collisions. Never affect unrelated resources.
4. Use exactly the synthetic identities `albert`, `brenda`, `charlie`, in that order.
   Do not bring back historical participant data or credential exports.
5. Keep generated state, credentials, and reports under ignored per-instance
   `.workshop/` paths. Do not print secrets or use an administrative token in the app.
6. Inspect official documentation for the versions selected. Pin and test actual
   dependencies; do not claim support merely because a configuration parses.
7. Run checks appropriate to the stage, report failures honestly, and update
   `docs/VALIDATION.md` and a stage-status table in `docs/IMPLEMENTATION.md`.
   A missing Docker engine is a reported limitation, not a passing integration test.
8. Before committing, inspect the full diff for unrelated files and secret values.
   Always commit and push using `commit_gh`, with scanning enabled. Keep assistant
   instructions/tooling local. Do not use `--tree`, release/tag options, image push,
   or history rewriting as a side effect of a stage.
9. Finish with the behavior delivered, checks/results, remaining limitations, and
   commit identifier. Do not claim completion of later stages.

The sequence deliberately fixes the PostgreSQL core before adding other database
choices, dynamic credential renewal, persistent Vault, or cloud extensions.
