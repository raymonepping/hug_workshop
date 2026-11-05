# Troubleshooting

| Observation | Check or recovery |
| --- | --- |
| Missing tool/supported Python | Run `make doctor`; install Python 3.12–3.14 or set TOOLS_PYTHON. Ansible is isolated automatically. |
| Podman unreachable | Start your existing Podman machine or rootless socket. Do not restart another project's machine to fix this lab. |
| Wrong API engine | PODMAN_SOCKET must be Podman's Unix API socket and match the CLI connection; Docker is rejected. |
| Port conflict | Use explicit *_PORT overrides on a fresh instance; saved settings are reused afterward. |
| Another operation is running | Wait for the other Make mutation to finish. Read-only status/doctor are still available. |
| exercise_incomplete / HTTP 403 | Expected starter state. Complete the reader, build, then infra. |
| vault_denied / HTTP 403 | Check AppRole IDs and the app policy. Run configure after disposable Vault restart. |
| vault_unavailable / HTTP 503 | Check the selected Vault service/endpoint. The API never falls back to env credentials in required mode. |
| db_unavailable / HTTP 503 | Check PostgreSQL readiness/configuration; infra reconciles a stopped service, configure restores grants. |
| Baseline connected, verifier fails | Expected. Baseline proves connectivity but does not complete the Vault exercise. |
| No rows | Run configure then seed on the selected instance. |
| Viewer uses old URL | Edit the visible API URL or clear the workshopApi browser-local setting. |
| Enterprise startup fails | Check your own license and selected pinned image privately. Use VAULT_EDITION=community for the unlicensed lab. |
| State lost but containers remain | Restore instance state or use another instance/ports. Do not delete state or adopt resources blindly. |
| Reset/destroy refused | Pass CONFIRM equal to the selected INSTANCE. Wrong-owner state and symlinked directories are intentionally rejected. |
| Failed teardown | Keep the instance directory/state, inspect the error and retry. Do not remove state first. |

Use `make status INSTANCE=<name>` and your private `.workshop/<name>/` files to
identify the selected lab. Bootstrap secrets and license material must not be
copied into an issue, console transcript, or screenshot.
