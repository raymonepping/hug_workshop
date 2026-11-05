# Stage 6 — Complete Make orchestration and acceptance checks

Follow the [shared instructions](README.md#instructions-shared-by-every-prompt).
Prerequisites: stages 2–5 with their existing scripts/playbooks/tests.

Implement the full command contract in `docs/PRD.md`: help, doctor, init, build,
plan, infra, configure, seed, up, status, verify, test, down, destroy, reset.
Use thin Make recipes and portable helpers rather than embedding the application
or an entire orchestration program in a Makefile.

Requirements:

- All targets resolve paths from the repository root and share one instance/config
  contract. Pass overrides consistently. Validate inputs before doing destructive work.
- Root Terraform invocations explicitly select `infra/` and the correct instance
  state. Root Ansible calls consume non-secret Terraform metadata and private files.
- Dependencies must wait for actual readiness and stop on failures. `make -j` must
  not race provisioning/configuration/reset. Add an appropriate orchestration lock
  or prohibit unsafe parallel invocations with a clear error.
- `doctor` is read-only, checks engine/context/tool versions/ports/architecture,
  and does not require a working lab or its secrets. Help must always work.
- `up` assembles the lab but leaves the learner's exercise seam intact. A solution
  profile must be explicit and must not overwrite learner files.
- `status` reports real state without printing secret values. `verify` is an
  executable set of acceptance checks, not a list of successful HTTP connections.
- Verify persona authentication/permissions, strict-mode denial with fallback
  credentials present, AppRole access, read-only DB permissions, dataset order/limits,
  repeated configuration, and restart recovery. Expected negative outcomes are
  explicit assertions; unexpected failures must produce a nonzero result.
- `down` preserves data, `destroy` removes only selected instance resources, and
  `reset` deletes local state/credentials only after successful scoped destruction.
  Use explicit confirmation for destructive targets and an explicit CI override.
- Never run global Docker prune/stop/delete, auto-push images, or delete state as a
  shortcut around reconciliation errors. Preserve failed teardown state for retry.

Test dry-run/help and failures with meaningful checks. Then run the full command
sequence on an isolated instance, a repeated run, an interrupted/failed configure,
and down/up/destroy/reset. Verify unrelated resources remain intact. Record AC-02,
04–12 with exact commands and limitations. Do not create broad implementation-
mirroring tests for trivial recipes when the actual lifecycle test proves behavior.
