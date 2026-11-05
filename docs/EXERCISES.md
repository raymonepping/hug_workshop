# Participant exercises

Allow two hours after [setup](SETUP.md) and downloads. The agenda is a teaching
proposal, not a measured completion-time guarantee. Use AI if helpful, and be able
to explain what each tool and credential is doing.

## 1. Provision and inspect — 20 minutes

Run `make doctor`, `make plan`, and `make up`. Inspect `infra/`, non-secret Terraform
outputs, and `make status`. Identify the network, retained DB volume, and four
containers. Explain why Terraform owns those resources and Ansible does not.

The viewer starts locked at <http://127.0.0.1:15173>. An incomplete exercise must
not crash the backend. `curl -s http://127.0.0.1:13004/health` shows the state.

## 2. Configure and prove connectivity — 20 minutes

Inspect `ansible/configure.yml`, its database/Vault roles, and `ansible/seed.yml`.
Repeat `make configure` and `make seed`: configuration and row counts should
converge. Understand where private bootstrap files are generated and mounted.

```sh
make infra MODE=baseline
make status
```

Refresh the viewer. The database is connected and the source is `env`, but Vault
authorization is still locked. Explain why a successful DB query is not evidence
of Vault access. Return to strict mode:

```sh
make infra MODE=required PROFILE=starter
```

## 3. Complete the Vault reader — 40 minutes

Implement the tracked `backend/vault.js` interface:

```js
export async function readVaultSecret({ addr, roleId, secretId, path }) {
  // Authenticate, read the approved KV v2 path, return flat credentials.
}
```

Use `POST /v1/auth/approle/login` with the supplied role/secret IDs, then the returned
short-lived token to read `/v1/kv/data/workshop/db`. KV v2 wraps credentials under
`data.data`. Return `{username, password}` only. Revoke the temporary token in a
`finally` block; do not let cleanup failure hide the original failure.

The service supplies these arguments from private configuration. Do not hardcode
credentials, read the dev root token, or substitute a human user's login. Use
bounded request timeouts. Failures should throw `LabError` from `./errors.js`:
`vault_denied` with status 403 for rejected auth/path access, `vault_unavailable`
with default status 503 for transport/service failure, and `configuration_error`
for unusable configuration. Never return raw upstream response bodies to clients.

```sh
make build
make infra PROFILE=starter MODE=required
make status
```

Refresh the viewer. `/health` should say `unlocked: true`, `channel: vault-kv`, and
`dbReady: true`. Explain the AppRole policy and the DB user's read-only grants.
The facilitator reference is separately selected and is not copied into your file.

## 4. Distinguish authentication and authorization — 20 minutes

`workshop/users.yml` defines, in order:

| Persona | Read approved DB KV | Write approved DB KV | Administer Vault |
| --- | --- | --- | --- |
| albert | Allowed | Denied | Denied |
| brenda | Allowed | Allowed | Denied |
| charlie | Denied | Denied | Denied |

```sh
make persona USER_NAME=albert ACTION=read
make persona USER_NAME=albert ACTION=write
make persona USER_NAME=brenda ACTION=write
make persona USER_NAME=charlie ACTION=read
```

The helper performs real userpass logins, reports the decision, and revokes each
temporary token. It never prints passwords or returned DB secrets. A write by
brenda submits the existing approved credentials, so it does not break the app.
For manual API exploration, open the private persona-password JSON in your editor;
do not paste passwords into shared terminals, prompts, or screenshots.

Explain why charlie can authenticate successfully and still receive a denial, and
why none of these personas is the application's service identity.

## 5. Verify, decode, and clean up — 20 minutes

```sh
make verify
```

The verifier checks real policy denial/recovery, DB privileges, data order/limits,
and private-file boundaries. It briefly denies the app policy and restores it, so
expect a momentary locked state. An unfinished reader or baseline mode must fail.
Read the first letters of 32 ordered titles. This is an acrostic puzzle; its
plaintext source is public and is not an encryption/access-control boundary.

Explain how a Vault outage differs from denied policy or an unavailable DB, then
use scoped teardown:

```sh
make destroy CONFIRM=default
```

Completion evidence: a successful core verifier, correct persona decisions, and a
clear explanation of provision/configure/authenticate/authorize boundaries.
