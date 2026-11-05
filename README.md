# Unlock the Data

A local workshop in Terraform, Ansible, Make, Podman, and Vault. Provision a
PostgreSQL lab, configure fictional identities, and make an application retrieve
its database credentials through Vault. No HCP account or Docker installation.

```sh
make doctor
make up
make status
```

Terraform apply asks for confirmation. Use `AUTO_APPROVE=1` explicitly for automation.
The default tracked starter runs **locked**: implementing `backend/vault.js` is the
participant exercise. Open the viewer at <http://127.0.0.1:15173>.

Start with [setup](docs/SETUP.md), then [participant exercises](docs/EXERCISES.md).
Facilitators have an [explicit solution workflow](docs/FACILITATOR.md).

| Tool | Ownership |
| --- | --- |
| Terraform | Podman containers, network, volume and local instance state |
| Ansible | PostgreSQL roles/data, Vault configuration, synthetic users and policies |
| Make | Repeatable orchestration, diagnostics, verification, scoped teardown |
| Application | Real AppRole/KV retrieval and authorization feedback |

The personas are **albert**, **brenda**, **charlie**, always in that order. Their
passwords are generated locally. The backend has a separate read-only service
identity. Environment connectivity is labelled baseline; it never counts as Vault
unlock. PostgreSQL is the supported core; other databases are historical extensions.

If the root ignored `.env` contains `VAULT_LICENSE`, auto mode uses Vault Enterprise
2.2.1 through a private license file. Without it, the community Vault path works.
Use `VAULT_EDITION=community` to select the unlicensed path explicitly.

```sh
make persona USER_NAME=charlie ACTION=read
make verify                         # fails until the Vault exercise is completed
make down                           # remove services, keep database volume
make destroy CONFIRM=default         # remove this instance's infrastructure/data
```

See [architecture](docs/ARCHITECTURE.md), [troubleshooting](docs/TROUBLESHOOTING.md),
[validation evidence](docs/VALIDATION.md), [PRD](docs/PRD.md), and
[implementation status](docs/IMPLEMENTATION.md). [Implementation prompts](prompts/README.md)
record the migration sequence; [older guides](docs/legacy/README.md) are historical.

Tested locally on macOS ARM64 with Podman. Linux, WSL2, and native AMD64 are targets
with remaining execution checks listed in the validation matrix. The proposed
two-hour agenda has not been piloted with participants.
