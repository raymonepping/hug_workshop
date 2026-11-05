# Facilitator guide

Use the same [setup](SETUP.md) as participants. No workshop organization or real
attendee onboarding is needed. Ship synthetic identities only. Pre-download images
and dependencies before the proposed two-hour session; pilot the agenda before
promising that timing.

## Explicit reference solution

```sh
make up PROFILE=solution AUTO_APPROVE=1
make verify
make status
```

`PROFILE=solution` selects `backend/solutions/vault.js`; it never overwrites the
participant's `backend/vault.js`. A new instance defaults to the incomplete starter.
A previously selected profile persists. Return explicitly with
`make infra PROFILE=starter MODE=required`.

Enterprise auto-selection reads your private license if present. Test the reusable
unlicensed path explicitly with `VAULT_EDITION=community`; participants need no
license. The current local validation exercised Enterprise 2.2.1 and community 1.21.1.

## Checks

```sh
make test
make verify
make test-browser
```

Unit tests use a transient, prefixed Podman test container; persistent lab services
remain Terraform-owned. Build first. Browser checks additionally need host Node/npm,
download Chromium into ignored `.workshop/`, and require an unlocked solution lab.
They use the selected instance's frontend URL.

`python3 tests/live_lifecycle.py` creates the reserved test instance `cycle`, uses
ports 35432/38200/33004/35173, and deliberately restarts/stops its services. It refuses
to reuse existing cycle containers/volumes and destroys its infrastructure on success.
Run it with no other workshop mutation in progress. Inspect its private logs if it
fails; retry after an explicit scoped cleanup. Never clean up unrelated resources.

The core verifier briefly mutates/restores the app ACL and submits a same-value
brenda KV write. It is an active lab test, not a production readiness probe.

## Recovery and assessment

Vault is intentionally disposable dev mode. After a restart, run `make configure`
to recreate its mounts, users, policies and AppRole artifacts. Passwords remain
stable on ordinary reruns. PostgreSQL data survives down/up; reset explicitly
regenerates credentials and data. This makes rebuild/reconfigure behavior visible.

Assess the visible checkpoints, real denial behavior and participant explanation.
Do not score the cosmetic presence of a token variable or a UI badge. The viewer
uses the backend decision; the verifier makes actual requests with real policies.

[Validation evidence](VALIDATION.md) separates executed tests from untested platform
targets. Native AMD64, Linux-host and WSL2 runs and a timed participant pilot still
need a maintainer with those environments.

Use `commit_gh` for commits/pushes, leave secret scanning enabled, and never stage
local assistant instructions or private runtime files.
