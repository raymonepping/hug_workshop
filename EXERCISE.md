# EXERCISE.md — HUG Workshop: “Unlock the Data”

## 0) Overview

You’ll stand up a local database via Terraform, seed it, and wire a tiny backend + frontend that **only returns data when unlocked by Vault**. Your job is to make Vault the “keeper” of credentials and prove it end-to-end.

## 1) What you’ll build

* **Local DB** of your choice (PostgreSQL / MySQL / MongoDB / Couchbase).
* **Backend (Node/Express)** that reads DB creds via:

  * **Vault KV (baseline)** or
  * **Vault Dynamic DB creds (bonus)**
    Falls back to `.env` only if configured to do so.
* **Frontend (static)** that shows health, auth channel (env vs vault), item list, and the cryptic motto.

> Easter Egg:
> “**The data remains silent until the keeper is acknowledged.**”
> It appears only when your backend is **unlocked** (i.e., using Vault or permitted mode). Your team must also **explain** what it means.

---

## 2) Rules of engagement

* Use your **own local machine** for the database.
* Use **HCP Terraform** + **local Terraform Agent** (script provided) if you want the bonus points; plain Terraform is fine for baseline.
* **Do not** hardcode DB creds in code. `.env` is allowed **only** when your chosen mode permits it.
* You may choose **any one** supported DB.
* Timebox: we’ll guide you; expect ~2 hours.

---

## 3) Repo layout (what you get)

```
./
├── backend/
│   ├── connectors/ (drivers per DB)
│   ├── db.js        (auth gating & connector selection)
│   ├── server.js    (Express API: /health, /api/items)
│   └── vault.js     (you implement Vault fetch: KV or Dynamic)
├── frontend/
│   ├── index.html   (viewer UI w/ health & auth pills)
│   └── frontend.js  (serves index + /config.json)
├── scripts/
│   ├── seed_dataset.sh      (populate DB)
│   ├── start_terraform_agent.sh
│   └── ... (dataset helpers)
├── main.tf                 (you own this; DB infra)
└── README.md               (project readme)
```

---

## 4) Prereqs

* Node 18+ (or 20+)
* Terraform CLI
* Docker (if you run DBs in containers) or native services
* Vault (local) or HCP Vault (we’ll provide)
* HCP Terraform org/project access (we’ll provide)
  *Optional*: run the provided **local Terraform Agent** script.

---

## 5) Environment templates

### 5.1 Backend `.env` (you complete these)

```ini
# --- DB selection ---
DB_TYPE=postgres            # postgres | mysql | mongodb | couchbase
DB_NAME=workshop
DB_HOST=127.0.0.1
DB_PORT=5432                # mysql: 3307 (example), couchbase: 5432 (kv port not used here)

# --- Auth gating (readable, not a giveaway) ---
DB_AUTH_MODE=preferred      # required | preferred | env_only
DB_SECONDARY_MODE=env_fallback  # disabled | env_fallback  (used only when preferred)
DB_TLS=false
DB_CRED_SOURCE=kv           # kv | dynamic   (hint: dynamic == database/creds/<role>)

# Known creds for the workshop DB (used only when mode allows)
DB_USERNAME=workshop
DB_PASSWORD=workshop

# limits
DEFAULT_ITEMS_LIMIT=32
MAX_ITEMS_LIMIT=100

# --- Vault (point to HCP or local) ---
VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=                 # leave blank to force fallback logic
VAULT_DB_KV_PATH=kv/workshop # or kv/data/workshop or v1/kv/data/workshop

# Dynamic (only if DB_CRED_SOURCE=dynamic)
VAULT_DB_MOUNT=database      # secrets engine mount name
VAULT_DB_ROLE=workshop-role  # role that issues DB creds
```

**Auth behavior quick guide**

* `DB_AUTH_MODE=required` → must use Vault; `.env` creds are **ignored**.
* `DB_AUTH_MODE=preferred` + `DB_SECONDARY_MODE=env_fallback` → try Vault, else use `.env`.
* `DB_AUTH_MODE=env_only` → use `.env` creds; Vault is ignored.

### 5.2 Frontend `.env`

```ini
FRONTEND_API_BASE=http://localhost:3004
PORT=5173
ITEMS_LIMIT=32
```

---

## 6) Tasks (Step-by-step)

### Step 1 — Provision your DB with Terraform

* Use **HCP Terraform** (bonus) or local Terraform CLI.
* Create a minimal DB (single instance or container) reachable from the backend.
* **Output** the connection host/port if helpful.
* Verify DB is listening.

### Step 2 — Seed the database

* Start your DB.
* Run:

  ```bash
  ./scripts/seed_dataset.sh
  ```
* This creates the `messages` table/collection and inserts data (id, idx, title).

### Step 3 — Run the backend in “locked” mode first

* From `backend/`:

  ```bash
  npm install
  npm run dev      # uses: node --watch server.js
  ```
* With Vault unset or invalid it should **refuse** to serve `/api/items` when:

  * `DB_AUTH_MODE=required`, or
  * `DB_AUTH_MODE=preferred` **and** `DB_SECONDARY_MODE=disabled`.

Check:

```bash
curl -s http://localhost:3004/health | jq
# Expect: unlocked=false (or 403 on /api/items)
```

### Step 4 — Implement Vault fetch in `backend/vault.js`

Your function must support:

* **KV v2** path patterns (`kv/workshop`, `kv/data/workshop`, `v1/kv/data/workshop`)
* **Dynamic DB creds** (`database/creds/<role>`)

Return a flat object with `username` and `password` (accept aliases `user`, `pass`).

### Step 5 — Flip the backend to use Vault

* Set a **valid** `VAULT_TOKEN`.
* For **KV**: put `username`/`password` under `kv/workshop`.
* For **Dynamic**: enable DB engine, configure role, and set:

  ```
  DB_CRED_SOURCE=dynamic
  VAULT_DB_MOUNT=database
  VAULT_DB_ROLE=workshop-role
  ```
* Keep `DB_AUTH_MODE=required` to prove the lock opens **only** with Vault.

Verify:

```bash
curl -s http://localhost:3004/health | jq
# Expect: "channel": "vault-kv" or "vault-dynamic", "unlocked": true
```

### Step 6 — Run the frontend

* From `frontend/`:

  ```bash
  npm install
  npm run start    # node --watch frontend.js
  ```
* Visit `http://localhost:5173`
  You should see:

  * Health: OK
  * DB: ready
  * **Auth: Vault** (or Env if permitted)
  * Items listed in the table
  * Motto footer with **unlocked: vault** (or env)

---

## 7) Optional HCP Terraform Agent (bonus path)

* Use the provided script:

  ```bash
  ./scripts/start_terraform_agent.sh
  ```
* Wire the agent in HCP Terraform and run your workspace through it.
* Bonus points for Runs, Variables, Policies, and thoughtful use of HCP features.

---

## 8) Scoring

### A) Feature Score (max 10)

| Area                                              |   Points |
| ------------------------------------------------- | -------: |
| DB provisioned via Terraform                      |        2 |
| Backend connects and lists items                  |        2 |
| Vault **KV** credentials working (unlocked)       |        2 |
| **Dynamic DB creds** via Vault (rotation-capable) | +2 bonus |
| HCP Terraform + local agent used correctly        | +2 bonus |

> Feature subtotal caps at **10** (bonuses let you offset misses elsewhere, but we cap to keep balance).

### B) Decryption Score (max 10)

* **Displayed on frontend** after unlock (4)
* **Clear explanation** of the message’s meaning and your unlock path (6)

### C) Balance Rule

Neither A nor B can outweigh the other entirely. Final score = **min(A, B) + ½·max(A, B)** (rounded).
This keeps *features* and *story* in healthy tension.

---

## 9) Helpful checks

**Health**

```bash
curl -s http://localhost:3004/health | jq
# fields:
#   mode: "required" | "preferred" | "env_only"
#   channel: "vault-kv" | "vault-dynamic" | "env" | null
#   unlocked: true|false
```

**Locked response**

```bash
curl -s http://localhost:3004/api/items | jq
# 403 with message when locked
```

**Vault KV quick test**

```bash
curl -sH "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv/data/workshop" | jq '.data.data'
# Expect: { "username": "...", "password": "..." }  (aliases: user/pass)
```

---

## 10) Troubleshooting

* **DB ready but frontend shows “DB: not ready”**
  Check backend logs; verify host/port; verify seed ran.
* **Auth pill stuck on “Env”**
  Ensure `VAULT_TOKEN` is set and valid; check `VAULT_DB_KV_PATH` (or dynamic path); confirm `DB_AUTH_MODE`.
* **Dynamic creds**
  Verify your role path: `database/creds/<role>`, and that the DB engine at `VAULT_DB_MOUNT` is configured.
* **Fallback not working**
  With `DB_AUTH_MODE=preferred`, set `DB_SECONDARY_MODE=env_fallback` and ensure `DB_USERNAME/DB_PASSWORD` are present.

---

## 11) Deliverables

* Short 2-minute walkthrough: **how you approached it**.
* Show:

  * `/health` JSON
  * Frontend **Auth: Vault** (or permitted Env)
  * Items list
  * The motto + your explanation
* Optional: a quick look at your Terraform workspace or agent runs.

---

## 12) Stretch ideas (for fun)

* Rotate dynamic creds mid-demo and show seamless backend continuity.
* Add MFA to Vault auth for your operator token.
* Use TLS for DB connections.
* Add a tiny **/debug** page in the frontend that shows `/health` JSON live (already hinted with the collapsible footer).

---

## 13) Run commands (summary)

**Backend**

```bash
cd backend
npm install
npm run dev   # node --watch server.js
```

**Frontend**

```bash
cd frontend
npm install
npm run start # node --watch frontend.js
```

**Seed**

```bash
./scripts/seed_dataset.sh
```

**Health**

```bash
curl -s http://localhost:3004/health | jq
```

---

## 14) Final reminder

* The **keeper** is Vault.
* The **unlock** is proving your backend **obtained DB creds from Vault** (KV or Dynamic) and served data only then.
* Keep it clean, minimal, and reproducible.
* Have fun—and may your guardian approve your intent.
