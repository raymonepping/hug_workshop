# Setup

Run every command from the repository root. Initial downloads need internet;
running the lab never calls HCP or a facilitator's service.

## Prerequisites

Install Git, GNU Make, Terraform (>=1.6,<2), Podman, and Python 3.12–3.14 for
Ansible. Terraform 1.14.2 is pinned in `.terraform-version` for version managers.
The orchestrator can run on newer Python but selects 3.13, 3.14, or 3.12 for its
isolated tooling; set `TOOLS_PYTHON=/path/to/python3.13` if automatic discovery
cannot find yours. Do not install Ansible globally for this workshop.

Application Node dependencies run inside Podman images. Host Node/npm is optional
and only needed for browser maintenance checks or editing/testing outside containers.

On macOS, initialize/start a Podman machine if you do not already have one:

```sh
podman machine init
podman machine start
```

Do not initialize a second machine or restart an existing machine serving other
projects. The workshop detects a running machine's forwarded API socket. It does
not change your machine or global Podman settings.

On Linux (including a native Podman installation in WSL2), enable the user's API
socket using your distribution's supported setup, typically:

```sh
systemctl --user enable --now podman.socket
```

The default rootless socket is `$XDG_RUNTIME_DIR/podman/podman.sock`. Set
`PODMAN_SOCKET=/absolute/path/to/podman.sock` if different. It must address the same
local Podman engine used by your CLI. Docker sockets are rejected. Remote hosts
without a shared project directory are outside this local bind-mount workflow.

Native Windows/PowerShell is outside the command contract. Use a Linux filesystem
and shell inside WSL2. Linux/WSL2 instructions are targets, not completed test runs;
see [validation](VALIDATION.md).

## First run

```sh
git clone https://github.com/raymonepping/hug_workshop.git
cd hug_workshop
make doctor
make init
make build
make plan
make infra
make configure
make seed
make status
```

`make up` runs init/build/infra/configure/seed in that order. It keeps the learner
exercise incomplete. On a new lab `/health` reports `exercise_incomplete`, the
viewer shows no data, and `/api/items` returns 403. That is the expected checkpoint.

`make help` is the default and always works without credentials. `make doctor`
checks tools, supported Python, Podman API identity, architecture, and ports without
creating a runtime directory or changing services. `make init` creates a private
instance directory and isolated pinned Ansible tooling, and initializes Terraform.

## Instance settings

Default host ports:

| Service | Loopback port |
| --- | --- |
| PostgreSQL | 15432 |
| Vault | 18200 |
| Backend | 13004 |
| Frontend | 15173 |

Create another instance with distinct ports:

```sh
make up INSTANCE=practice POSTGRES_PORT=25432 VAULT_PORT=28200 BACKEND_PORT=23004 FRONTEND_PORT=25173
make status INSTANCE=practice
```

Settings are saved per instance; subsequent commands need only `INSTANCE` unless
changing a setting explicitly. `PROFILE=starter|solution`, `MODE=required|baseline`,
and `VAULT_EDITION=auto|community|enterprise` persist. Port overrides use the names
above. The default prefix is recorded in `workshop/config.json` and local project
instructions. `PREFIX=hug-<unique-project-id>-` may be selected on a fresh instance;
an existing instance cannot change its prefix. Never reuse another project's names.
If resources exist without local state, restore state or choose a new instance;
the automation does not adopt them silently.

## Optional Enterprise license

Put only your own valid license in the ignored root `.env` (`.env.example` shows
its key), or export `VAULT_LICENSE` in your shell. Auto mode uses Enterprise when
a nonempty license is available; `VAULT_EDITION=community` requires none. Explicit
enterprise mode fails if a license is missing. The root file is parsed, not sourced;
only this key is read. Other settings belong in Make overrides, not `.env`.

The license is written as mode 0600 into the private Vault runtime directory and
read through `VAULT_LICENSE_PATH`. It never goes into Terraform inputs/state,
application configuration, or normal command output. Do not put actual licenses
in examples, prompts, screenshots, or Git.

## Private files and teardown

Each `.workshop/<instance>/` is mode 0700. Its files contain local state, bootstrap
secrets, persona passwords, and application bootstrap material. Keep it out of Git.
The app mounts only its own subdirectory; it receives no human passwords or root token.

```sh
make down INSTANCE=practice AUTO_APPROVE=1
make up INSTANCE=practice
make destroy INSTANCE=practice CONFIRM=practice
```

Down removes containers/network through Terraform and retains the data volume.
Vault dev configuration is in memory, so up/configure restores it. Destroy also
removes the instance's data volume but retains private files/state for inspection.
Local build/base image caches remain; no global prune is performed.

`make reset INSTANCE=practice CONFIRM=practice AUTO_APPROVE=1` destroys, then removes
that instance's runtime files, regenerates credentials, and rebuilds. It never
removes runtime state before successful destruction. Mutation commands are serialized;
status/doctor remain available. A failed mutation can be retried after inspection.
