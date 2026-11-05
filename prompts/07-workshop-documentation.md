# Stage 7 — Publish a coherent local workshop guide

Follow the [shared instructions](README.md#instructions-shared-by-every-prompt).
Prerequisites: stages 1–6. Write from commands and behavior that actually exist.

Rewrite root README as the concise entry point and create new material under
`docs/`: setup, participant exercises, facilitator guide, architecture, troubleshooting,
and extension guidance. Update the PRD's status/implementation references honestly.

Requirements:

- Cover macOS/Linux/WSL2 prerequisites, tested version ranges, architectures, Docker
  context/ports, initial download expectations, and root-directory commands.
- Explain tool ownership and actual browser/backend/Vault/DB communication.
  Vault issues credentials; it is not a database query proxy.
- Use albert, brenda, charlie in canonical order. Explain persona ACL exercises,
  application AppRole separation, generated private credentials, and recovery after
  disposable Vault restart. No real identity or historical password examples.
- Provide a realistic two-hour agenda with checkpoints, expected observations,
  verification, common failures, recovery, and scoped teardown. Mark unpiloted timing.
- Keep participant tasks and facilitator solutions distinct. Document the runnable
  locked starter and explicit solution profile without silently solving the task.
- Explain why baseline environment access is different from a Vault unlock and why
  the acrostic dataset is a puzzle rather than encrypted access control.
- Explain local state/credential handling and the dev-mode lifecycle in context.
- Use copyable commands with actual flags, ASCII dashes, correct working directories,
  and matching environment filenames. Verify links after any moves.
- Label or relocate the previous workshop docs under `docs/legacy/`; preserve the
  historical analysis/cleanup record as baseline records, not current instructions.
- Once replacements pass, retire HCP-only root Terraform/tfvars, onboarding/agent/
  drift scripts, real-organization defaults, and obsolete Compose/registry flows.
  Check references first; keep genuinely useful generic helpers with updated docs.
- Mention unsupported connectors only as unvalidated extensions. Keep optional
  dynamic credentials, persistent Vault, Boundary, and cloud labs out of core steps.

Check every local Markdown link and file reference, exercise commands on a fresh
instance, and verify no core step requires HCP. Record AC-13/14 coverage and any
remaining platform or instructional gaps. Commits/pushes use `commit_gh`.
