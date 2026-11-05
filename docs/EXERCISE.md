# 🚀 HUG Workshop — *Unlock the Data*

> Looking for deep-dive references? See **[ARTICLE_INDEX.md](./ARTICLE_INDEX.md)**.

---

Your mission is simple to explain and surprisingly fun to execute:

You will deploy a database using **Terraform**, seed it with data, 
build a tiny backend that **only unlocks when Vault is acknowledged**, 
and view everything through a lightweight frontend. 
When everything works, a hidden message is revealed.

You have **2 hours**.
Teamwork + AI is allowed.
Hardcoding passwords is not.

---

## 1) Mission Outcome

At the end of this workshop, you will have:

| Component                  | Your Choice                            | Purpose                                      |
| -------------------------- | -------------------------------------- | -------------------------------------------- |
| **Database**               | Postgres / MySQL / MongoDB / Couchbase | Stores the message fragments                 |
| **Backend (Node/Express)** | Provided skeleton                      | Fetches data only when “unlocked”            |
| **Vault**                  | HCP Vault or local Vault               | Keeper of DB credentials                     |
| **Frontend**               | Provided static UI                     | Displays the data + reveals the hidden motto |

---

## 2) Access & Setup

### 2.1 Sign in to HCP

[https://portal.cloud.hashicorp.com](https://portal.cloud.hashicorp.com)

Create a trial account, or ask us for a **team workshop account**.

### 2.2 Access HCP Terraform

[https://app.terraform.io](https://app.terraform.io)

Log in with the same HCP identity.

→ Tell us your **organization name** so we can enable workshop license features.

---

## 3) Create Your Terraform Execution Environment

In HCP Terraform:

1. Create a **Terraform Agent Pool**
2. Run the provided script locally to connect to it:

```bash
./scripts/start_terraform_agent.sh
```

This allows Terraform to deploy resources into your **local Docker environment**.

> Yes — Terraform can orchestrate your laptop.
> No — you do not need Kubernetes today.
> We’re being kind. For now.

---

## 4) Provision Your Database (Your Choice)

Pick **one**:

| Database   | Recommended Port | Connector Provided? |
| ---------- | ---------------- | ------------------- |
| PostgreSQL | `5432`           | ✅ yes               |
| MySQL      | `3307`           | ✅ yes               |
| MongoDB    | `27017`          | ✅ yes               |
| Couchbase  | `8091`           | ✅ yes               |

Write the `.tf` files needed to **deploy the DB as a container**.

Minimal viable output:

* Container is running
* Port is reachable from backend
* DB has a `workshop` database/schema/bucket
* Credentials: `workshop / workshop`

---

## 5) Seed the Database

```bash
./scripts/seed_dataset.sh seed --db-type <your-db-type>
```

This loads the dataset and secretly encodes a phrase.
It is silent until the backend unlocks it.

Verification is locked down but included in the script:

```bash
./scripts/seed_dataset.sh verify --db-type postgres --limit 32
./scripts/seed_dataset.sh verify --db-type couchbase --limit 32
```

To run verification, ask one of us.

---

## 6) Backend Setup

Use this skeleton:

[https://github.com/raymonepping/hug_workshop/tree/main/backend](https://github.com/raymonepping/hug_workshop/tree/main/backend)

```bash
cd backend
npm install
npm run dev     # runs Express in watch mode
```

You **must implement `vault.js`** — we deliberately didn’t include it.

Connectors for DBs are here:

```
backend/connectors/
```

### Your `.env` (place in `/backend`)

```ini
DB_TYPE=postgres        # postgres | mysql | mongo | couchbase
DB_NAME=workshop
DB_HOST=127.0.0.1
DB_PORT=5432            # mysql=3307, couchbase logical port=5432
DB_AUTH_MODE=preferred  # required | preferred | env_only
DB_SECONDARY_MODE=env_fallback
DB_TLS=false
DB_CRED_SOURCE=kv       # kv | dynamic

DB_USERNAME=workshop
DB_PASSWORD=workshop

DEFAULT_ITEMS_LIMIT=32
MAX_ITEMS_LIMIT=100
```

#### Auth Modes Explained

| Mode                         | Meaning                       | Behavior                     |
| ---------------------------- | ----------------------------- | ---------------------------- |
| `required`                   | Vault must succeed            | `.env` creds ignored         |
| `preferred` + `env_fallback` | Try Vault, fallback to `.env` | For workshop realism         |
| `env_only`                   | Ignore Vault                  | Not recommended, but allowed |

---

## 7) The Vault Unlock

Your `vault.js` **must return**:

```js
{
  username: "<db-user>",
  password: "<db-pass>"
}
```

Supported sources:

| Source           | Path Example                        |
| ---------------- | ----------------------------------- |
| KV v2            | `kv/workshop` or `kv/data/workshop` |
| Dynamic DB Creds | `database/creds/workshop-role`      |

Try unlocking:

```bash
curl -s http://localhost:3004/health | jq
```

Expected:

```json
{
  "unlocked": true,
  "channel": "vault-kv"
}
```

---

## 8) Frontend Setup

[https://github.com/raymonepping/hug_workshop/tree/main/frontend](https://github.com/raymonepping/hug_workshop/tree/main/frontend)

```bash
cd frontend
npm install
npm run start
```

Visit:

```
http://localhost:5173
```

If unlocked:
✅ Items appear
✅ Footer shows the motto
✅ You realize the first letters form a meaningful sentence

If still locked:
❌ You only see frustration and reflection

Which, honestly, is also a learning outcome.

---

## 9) Scoring (Yes, there are winners)

| Category                          |   Points |
| --------------------------------- | -------: |
| DB deployed via Terraform         |        2 |
| Backend queries DB successfully   |        2 |
| Vault KV unlock working           |        2 |
| **Dynamic DB creds** working      | +2 bonus |
| HCP Terraform Agent used          | +2 bonus |
| Explanation of the hidden message |        2 |

Total score capped at **10** to keep it fair.

---

## 10) Troubleshooting

| Issue                     | Likely Cause                     | Fix                                             |
| ------------------------- | -------------------------------- | ----------------------------------------------- |
| Backend says “locked”     | Vault token missing or incorrect | Set `VAULT_TOKEN`                               |
| Frontend shows no data    | Backend not running              | `npm run dev` in `/backend`                     |
| Database not reachable    | Wrong port                       | Check `.env` + container port                   |
| KV lookup returns nothing | Wrong path                       | Try `kv/data/workshop` instead of `kv/workshop` |
| Dynamic creds denied      | Role misconfigured               | Re-check `database/roles/<role>` in Vault       |

---

## 11) Final Reminder

The hidden phrase only appears when **you earned it**.

Vault is the **keeper**.
Your backend must **acknowledge the keeper**.
Only then does data speak.

---

Good luck — and may your guardian approve your intent. 🛡️
