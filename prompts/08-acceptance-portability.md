# Stage 8 — Validate the complete workshop and close remaining gaps

Follow the [shared instructions](README.md#instructions-shared-by-every-prompt).
Prerequisites: stages 1–7. Read their evidence; independently test the resulting flow.

Validate the delivered local workshop against every acceptance criterion in
`docs/PRD.md`. Fix concrete issues uncovered by the tests rather than producing
only a review. Preserve participant/solution separation and resource ownership.

Required evidence:

1. A clean-clone run with no ignored local Vault implementation, environment files,
   lockfiles, cached images, or host Node dependencies supplying hidden requirements.
   Use an isolated location/instance; do not delete the developer's working files.
2. Complete documented setup, baseline, locked starter, explicit facilitator solution,
   real AppRole/KV unlock, all human persona permission cases, and puzzle ordering.
3. Repeat configure/seed/up, DB/Vault interruption, Vault recreation/reconfigure,
   and recovery without stale UI authorization or credential mismatch.
4. Negative cases: valid env DB credentials plus failed Vault auth, authenticated
   charlie denial, missing prerequisites, occupied ports, bad configuration, and
   failed teardown. The verifier must detect failures.
5. Two independent instances with separate state, prefixes, ports, volumes, and
   credentials; destroy/reset one and prove the other remains healthy. Confirm an
   unrelated resource also remains untouched.
6. Image/build and command behavior on ARM64/AMD64 and macOS/Linux/WSL2. Record
   actual results separately from documentation review. Do not claim an untested
   platform passed; list remaining runs with exact instructions for a maintainer.
7. Secret exposure inspection of Git changes, public HTTP routes, logs, rendered
   frontend config, image contexts, test artifacts, Terraform outputs/state, and
   private-file permissions. Never include discovered credential values in reports.
8. Full tracked-tree dependency/reference audit: no active HCP requirement, no real
   attendee exports, no stale instructions pointing to removed files, no placeholder
   tests reported as integration coverage, and no hidden alternative resource owner.

Update `docs/VALIDATION.md` with dates, versions, platform, exact commands, results,
and AC coverage; update `docs/IMPLEMENTATION.md` with actual stage completion.
Document the remaining limits of the two-hour lab and optional extensions.
Do not declare the portability matrix complete without evidence. Use `commit_gh`
with scanning enabled to commit/push the final fixes and evidence, then report the
commit, supported/tested environments, and concrete outstanding limitations.
