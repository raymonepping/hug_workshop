# Workshop analysis

Reviewed on 5 November 2026 against commit `31b3b24` on `main`.

## Scope and limits

This review covers the tracked workshop documentation, Terraform configuration,
application source, Docker configuration, environment examples, shell scripts,
dataset, generated reports, and the contents of the two tracked credential ZIPs.
It also accounts for local ignored application files, especially `backend/vault.js`,
local dependency lockfiles, environment file structure, and attendee conversion
scripts. Credential values and attendee identities are deliberately omitted here.

Installed dependencies, provider binaries, Git internals, and assistant tooling
are supporting local material, rather than workshop source. External articles,
external Stacks repositories, registry images, and live HCP/Vault services have
not been reviewed. Findings describe this checkout; they do not establish current
vendor support, licensing, or service behavior.

This was a source review with local static checks. No infrastructure was deployed,
no database was seeded or cleaned, and no credentials were used against a service.

## What the workshop is trying to teach

The workshop is called **Unlock the Data**. Its intended participant journey is:

1. Access HCP Terraform and configure a local Terraform agent.
2. Write Terraform to provision one local database container.
3. Seed that database with the provided dataset.
4. Run the Node/Express backend and frontend viewer.
5. Implement a Vault integration to obtain database credentials.
6. Demonstrate the transition from locked data to data accessed through Vault.
7. Decode a message from the initials of ordered record titles.

`EXERCISE.md` sets a two-hour duration, allows teamwork and AI, and scores database
provisioning, successful queries, Vault KV integration, and explaining the hidden
message. Dynamic credentials and agent execution receive bonus points. Agent
setup is also presented as a required step, which makes its bonus status unclear.

The dataset contains 500 records with `id`, `idx`, and `title`. The first 32 titles
encode **WE ARE THE GUARDIANS OF OUR OWN SYSTEMS**. The frontend's default limit is
32, which includes the phrase. The phrase is already recoverable from the tracked
plaintext dataset and appears in the dataset generator's examples. The puzzle is
therefore a learning device, not a security boundary.

The strongest teaching concept is the visible change in credential provenance:
environment credentials, Vault KV credentials, then potentially leased dynamic
credentials. The documentation also mentions Boundary and Terraform Stacks as
later extensions, but neither has an implementation in this repository.

## Repository map

| Area | Actual responsibility |
| --- | --- |
| `README.md`, `EXERCISE.md`, `OVERVIEW.md` | Orientation, participant challenge, and execution flow |
| `CONSTRUCTION.md` | Image construction and local Compose deployment |
| `SCRIPTS.md`, `LOADING_USERS.md` | Script overview and organizer onboarding instructions |
| `ARTICLE_INDEX.md` | Links to official documentation and narrative articles |
| Root Terraform files | Organizer provisioning of HCP Terraform memberships, teams, projects, and access |
| Root tfvars and `bootstrap.json` | Organizer inputs, including the selected shared assignment mode |
| `backend/server.js` | Health, ping, and gated item API |
| `backend/db.js` | Credential selection, database initialization, and connector dispatch |
| `backend/connectors/` | PostgreSQL, MySQL, MongoDB, and Couchbase access |
| Local ignored `backend/vault.js` | Working example of reading KV v2 and default-mount dynamic credentials |
| `frontend/frontend.js` | Express static server and environment-driven runtime configuration |
| `frontend/index.html` | Viewer, health indicators, API selection, and inline browser logic |
| Dockerfiles and Compose | App images and deployment onto an existing database network |
| Dataset scripts | Generate, encrypt, import, verify, and remove workshop records |
| Agent/build scripts | Run an HCP Terraform agent and build/push application images |
| Onboarding scripts | Convert attendee input and generate Terraform user inputs |
| `tfc_*.sh` | Rights extraction and configuration/live drift reports |
| `credentials/`, `scripts/output/` | Historical workshop packages and generated reports |
| `prompts/` | Empty directory reserved for later work |

There is no provided Terraform database deployment, Vault provisioning, Boundary
configuration, automated test suite, or CI workflow in the tracked tree. Writing
database Terraform and the Vault reader is explicitly participant work today.

## Application behavior

The browser calls the backend directly. The backend reads credentials from Vault
and then connects directly to the database. Vault is not a proxy in the database
query path, despite the linear diagram in the README.

`db.js` supports `required`, `preferred`, and `env_only` authentication modes.
`preferred` can fall back to environment credentials when the secondary mode is
`env_fallback`. The backend reports the credential source as `vault-kv`,
`vault-dynamic`, or `env`.

The database handle is initialized and cached. Once a connection exists, health
checks do not perform a fresh database query or Vault authorization check.
Credential changes and dynamic lease expiry are not handled during runtime.

The viewer fetches `/health`, then `/api/items`, and shows the returned records.
It provides editable API selection, browser-local persistence, query-string
override, and a health debug drawer. It does not assemble or conditionally reveal
the motto in the footer; the footer quote is always present.

## Findings that affect a fresh workshop

### 1. The default unlock behavior contradicts the mission

`backend/server.js:34` allows data access with environment credentials in
`preferred` plus `env_fallback`. That combination is recommended in the exercise
and backend environment example. `env_only` also permits access.

Consequently, participants can see the dataset without completing the Vault
integration. This is more than a wording issue: the success condition in the
exercise and the success condition in the API differ.

Revision implication: define whether environment credentials represent a deliberate
baseline stage, and define a separate, explicit Vault completion criterion.

### 2. A fresh clone cannot build the provided images as written

Both Dockerfiles run `npm ci`, but `.gitignore:111` excludes `package-lock.json`.
Neither application's lockfile is tracked. Local lockfiles currently make this
checkout look more complete than a fresh clone.

In addition, `db.js` statically imports `vault.js`, while that file is deliberately
absent from Git. A participant who follows the documented backend startup before
implementing it encounters a missing-module error before getting a locked UI.

Revision implication: distinguish a runnable starter from a completed solution,
and make dependency installation reproducible.

### 3. Database support is inconsistent

| Database | Findings |
| --- | --- |
| PostgreSQL | Seeder and reader agree on `messages`; the reader honors its supplied limit and orders by ID. This is the most coherent baseline path from source inspection. |
| MySQL | Seeder and reader agree on `messages`, but the reader hardcodes `LIMIT 100` and ignores the supplied limit. Documentation alternates between host port 3307 and the driver's default 3306. |
| MongoDB | Seeder accepts `mongo`, while the backend requires `mongodb`. Seeder writes `messages`, while the backend reads `items`. Seeded IDs use `_id`, while the viewer displays `id`. The reader also hardcodes its limit and does not sort. |
| Couchbase | Seeder writes the `app.messages` scope/collection by default, while the backend queries the bucket's default collection. The query hardcodes its limit and has no ordering. It assumes an index, which the seeder does not create. |

`DB_TLS` is parsed and passed onward, but the connectors do not implement it.
MongoDB also fixes the authentication database to `admin`, which needs deliberate
alignment with any dynamic credential role.

Revision implication: use one verified primary database path before promising
equivalent experiences across all four choices.

### 4. Dynamic credential configuration is only partly connected

Examples advertise `DB_CRED_SOURCE`, `VAULT_DB_MOUNT`, and `VAULT_DB_ROLE`, but
`db.js` does not consume those settings. It chooses dynamic behavior by recognizing
a secret path starting with `database/creds/`.

The local ignored Vault reader supports KV v2 and the default `database` mount,
but does not send a Vault namespace header, set a request timeout, or preserve
lease metadata for renewal/replacement. Its path handling is not a general
implementation for arbitrary database engine mount names.

Revision implication: define an explicit reader interface and decide whether
dynamic credentials mean one-time retrieval or a full credential lifecycle lab.

### 5. Setup instructions disagree about paths and configuration

- `OVERVIEW.md` places environment files at the root, while the applications load
  `.env` from their working directories and Compose requires `backend/.env`.
- `SCRIPTS.md` copies example files without renaming them into files consumed by
  the applications.
- Root-level seed commands use defaults that look for `dataset.jsonl.enc` and
  `.database.env` in the current directory; those files live under `scripts/`.
- The agent script expects `scripts/.env`. It requires agent settings even before
  handling help or status. Running it without a command only shows help.
- The documented `construct_container.sh backend` and `frontend` commands do not
  match the implemented required directory flags. The construction guide also
  uses typographic dashes and omits shell line continuations.
- Compose hardcodes `DB_HOST=pg`, even when a participant selects another DB.
- Compose mounts `frontend/public/config.json`, but no such file is supplied.
  The frontend serves configuration from its `/config.json` route using environment
  variables; the mounted file is not the route's configuration source.
- Compose health checks accept any successful `/health` response, while that
  endpoint returns HTTP 200 and `ok: true` even if `dbReady` is false.

Revision implication: choose one canonical working directory, configuration
layout, and supported startup flow, then derive all instructions from it.

### 6. Organizer Terraform has broken bootstrap/locked-mode wiring

The root configuration provisions HCP Terraform organization resources, rather
than the participant's database infrastructure. That distinction is not prominent
enough for someone following the workshop from the repository root.

Specific mismatches:

- `main.tf:21` hardcodes `local.using_locked = false`; `var.using_locked` has no
  effect on it.
- Effective bootstrap emails come from `bootstrap.json`; `var.emails` is unused.
- The membership resource remains enabled in both branches of
  `org_membership_map`, contrary to the variable documentation's promise that
  locked mode does not create memberships.
- `generate_tfvars_from_json.sh:35` requests `credentials_map`, but `outputs.tf`
  does not define that output. The script can apply changes and then fail during
  output conversion.
- The common team lookup is still performed when common access is disabled,
  unless an explicit team ID is supplied.
- Shared mode is selected in the checked-in inputs, but `project_names` only
  reports per-user projects.
- The configuration uses `local_file` without explicitly declaring the local
  provider under `required_providers`.

The checked-in organization access settings allow managing projects, workspaces,
and agent pools at organization scope. They need a conscious organizer/participant
access model before reuse.

### 7. Historical material includes participant and credential data

Both ZIP files under `credentials/` are tracked and contain unencrypted entries.
The workshop package includes attendee exports and participant environment files;
the packages also contain credential/token material. Generated reports include
real participant identifiers and organization details.

Their age does not establish whether the credentials are still valid. This review
did not try them. Before redistribution, establish which material can be retained,
replace examples with synthetic data, and assess whether credentials need revoking.
Removing files from the current tree alone would not remove them from Git history.

### 8. Supporting scripts need reliability work

- The seeder assigns defaults before saving its supposed exported-environment
  overrides. Those nonempty defaults can overwrite values subsequently loaded
  from `.database.env`, contrary to its documented precedence.
- Its `--env` flag loads values during argument parsing, making precedence depend
  on argument order.
- Interactive dataset decryption prints a prompt to stdout inside a command
  substitution that is supposed to return only a temporary filename.
- SQL seeding repeatedly calls `docker exec` for individual rows and parses JSON
  with regular expressions. This is slow and fragile for general input.
- Database host/port flags do not turn the seeder into a remote database client;
  the actual operations use local Docker containers.
- `login_vault.sh` uses `mapfile`, unavailable in macOS's bundled Bash 3.2, and
  requires a namespace even though local Vault need not use namespaces.
- The image builder initializes `VERSION` before sourcing optional settings, so
  its default tag can be `1.0.0` rather than Compose's `v1.0.0`.
- `setup_stacks.sh` uses a string comparison for its Terraform minor version
  check. The external Stacks repositories are outside this review.
- `clean_tf_artifacts.sh` removes local state and lockfiles, stages all changes,
  commits, and pushes. Its broad behavior needs to be explicit before workshop use.

The drift toolkit has a confirmed JSON-generation defect: fields such as
`object: ($object | select(. != "null"))` and
`team_email: ($email | select(. != ""))` can suppress the entire output object
when optional values are absent. The address-only path can therefore write a
zero-byte report. Two such empty reports are already tracked. A minimal local
`jq` reproduction produced zero output bytes.

The configuration-diff script runs a normal refreshing plan, so its result is not
a pure comparison of configuration with the existing saved state. Targeted plan
exit codes can also reflect changes beyond the report's selected resource.

### 9. Smaller application and maintenance gaps

- The frontend statically serves its application directory, exposing files such
  as package manifests and source through ordinary static routes.
- The UI infers unlock state from the credential channel instead of using
  `health.unlocked` as the authority. Its refresh shortcut also runs while typing
  in the API input.
- The backend has no in-flight initialization guard, reconnection strategy,
  connection shutdown, or ongoing readiness probe. It returns database error
  messages directly to API clients.
- The frontend escapes titles, but interpolates `id` and `idx` into HTML without
  escaping. The supplied dataset uses numbers; a generalized dataset needs a
  stronger rendering contract.
- Version declarations vary between Node requirements in the docs, Node 20 Docker
  images, Terraform `>= 1.3.0`, and `.terraform-version` at 1.13.4.
- The root license is GPL v3, while backend package metadata says ISC.
- Generated folder trees and reports are historical snapshots, not authoritative
  descriptions of the current starter.

## Verification performed

| Check | Result |
| --- | --- |
| Bash parsing | All 16 local shell scripts passed `bash -n` |
| JavaScript parsing | All eight application JS files, including local `vault.js`, passed `node --check` |
| ShellCheck | 12 findings: one error, five warnings, six informational findings |
| Terraform formatting | `terraform fmt -check -diff` produced no formatting differences |
| Terraform validation | Incomplete: installed local/tfe provider processes failed their schema-loading handshake in this execution environment |
| Dataset structure | 500 valid JSON records with unique IDs |
| Drift report defect | Minimal `jq` reproduction confirmed an empty output object stream |
| Deployment and integration | Not exercised |

Passing syntax checks does not resolve the cross-component contract problems above.

## Proposed revision sequence

1. Agree on the revised audience, duration, and primary learning objective.
2. Define the visible stages and completion criteria: connected using environment
   credentials, authenticated through Vault KV, and optionally using dynamic leases.
3. Separate organizer provisioning, participant starter files, facilitator solutions,
   and historical artifacts so each has an obvious entry point.
4. Establish one reproducible baseline, preferably PostgreSQL based on the current
   source, with documented setup and an observable locked-to-unlocked transition.
5. Repair configuration paths, builds, API/data contracts, and organizer bootstrap.
6. Add focused acceptance checks for fresh-clone startup, denied access, Vault
   success/failure, dataset ordering, and any supported credential lifecycle.
7. Rewrite the workshop instructions around the verified flow, with explicit
   prerequisites, checkpoints, recovery steps, and teardown.
8. Extend database choices and optional Stacks/Boundary material only after the
   baseline is repeatable.
9. Create the prompts in `./prompts` against those agreed stages and contracts.

Potential future prompt topics are workshop redesign, repository separation,
baseline infrastructure, backend authentication, connector parity, frontend
feedback, organizer onboarding, and end-to-end validation. These are candidate
scopes, not prompts or an approved implementation plan.

The important design decisions still open are whether the next version remains
a two-hour workshop, which parts participants should implement, whether HCP is
mandatory, which database choices remain first-class, how AI assistance should
be used, and whether Boundary/Stacks belong in the core or in follow-up labs.
