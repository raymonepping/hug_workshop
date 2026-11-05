# Follow-up labs

The supported core is PostgreSQL, local Podman, disposable Vault, AppRole/KV, and
synthetic personas. Extend it only after the core verifier passes.

- Dynamic database credentials: configure Vault's DB engine, least-privilege role
  creation, lease expiry/revocation, and connection replacement. A one-time secret
  read is not a complete credential-lifecycle exercise.
- Persistent Vault: replace dev mode with explicit storage, initialization/unseal,
  restart recovery and private key handling. Do not imply the dev-mode lab is production.
- Other databases: historical connector source is retained under
  [legacy connectors](legacy/README.md). Add seeder/reader shape, ordering, limit,
  TLS, authentication and dynamic-role tests before advertising support.
- TLS: add local trust material and verified endpoints throughout; avoid silent
  certificate-verification bypasses.
- Offline packages: export images and prefetch pinned dependencies with integrity
  checks. The current first-run downloads require internet.
- Boundary, remote execution, cloud services and HCP are separate optional labs;
  they must never become prerequisites for the local core.
