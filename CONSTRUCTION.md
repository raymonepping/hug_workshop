# 🏗️ Construction Guide — Building, Running, and Preparing for Terraform Deployment

This document explains how to:

1. Build the **backend** and **frontend** containers
2. Run them locally using **Docker Compose**
3. Understand the networking / environment logic
4. Prepare for the next phase → **Terraform + Vault + Boundary**

This is the *hands-on assembly manual*, not the story.  
Think: *LEGO booklet, but with slightly better taste and fewer screaming children.*

---

## 1) Requirements

Make sure you have:

| Tool | Version Recommendation | Notes |
|------|------------------------|------|
| Docker | Latest Desktop (Mac/Win/Linux) | Apple Silicon users: we build **linux/amd64** |
| Node.js | 20+ | Only needed if running backend/frontend without Docker |
| Vault (optional) | Local dev mode or HCP Vault | Only required if testing dynamic authentication |

---

## 2) Build the Containers

Use the provided helper script:

cd scripts
./construct_container.sh 
–backend-dir ../backend 
–frontend-dir ../frontend 
–repo repping 
–version v1.0.0 
–platform linux/amd64 
–push false

### What it does:
- Builds the backend and frontend Docker images
- Ensures platform compatibility (`linux/amd64`) even on M-series Macs
- Produces:

repping/hug-backend:v1.0.0
repping/hug-frontend:v1.0.0

### Optional:
Push the images to Docker Hub:

./construct_container.sh 
–backend-dir ../backend 
–frontend-dir ../frontend 
–repo repping 
–version v1.0.0 
–platform linux/amd64 
–push true 
–latest true

---

## 3) Running the Workshop Stack (Local)

The stack expects one thing:

A **Docker network** that already exists and hosts your chosen database container(s).

For example, if your Postgres/MySQL/Mongo/Couchbase are deployed using Terraform or docker-compose earlier:

docker network ls

You should see:

workshop-net

If not, create it:

docker network create workshop-net

---

## 4) Start Backend + Frontend

From project root:

docker compose up -d

### Result:
| Service   | URL | Behavior |
|----------|-----|----------|
| Backend  | http://localhost:3004 | API + Vault-aware DB connector |
| Frontend | http://localhost:5173 | Reads data from backend |

Check backend health:

curl -s http://localhost:3004/health | jq

You’ll see something like:

```json
{
  "ok": true,
  "dbReady": true,
  "mode": "preferred",
  "channel": "env",
  "unlocked": true
}
```
If Vault is configured and reachable, channel will flip automatically.

⸻

5) Understanding the Environment Logic

The backend connects to DB based on this env:

backend/.env

Important values:

Key	Meaning	Typical Value
DB_HOST	Name of DB container on Docker network	pg, mysql, or mongo
DB_AUTH_MODE	How to authenticate	preferred (= try Vault → fallback env)
DB_CRED_SOURCE	Cred lookup style	kv or dynamic
VAULT_ADDR	URL Vault is reachable from inside container	http://host.docker.internal:8200

When Vault is not available → falls back cleanly to .env credentials.
When Vault is reachable → credentials are retrieved securely.

No drama. No guessing. Transparency is intentional.

⸻

6) Verify Your Dataset (The Codex Test)

./scripts/seed_dataset.sh verify --db-type postgres --limit 32

Example output:

🔓 Verification unlocked: Vault reachable and token valid.

🛡️  Guardian acknowledged.
✨ The initials reveal themselves:
🔐 Codex: ------------------------

If Vault is missing:

🔒 Verification locked

Exactly as intended.

⸻

7) Next Phase — Terraform Deployment

Once the stack works locally, the goal is to:
	1.	Use Terraform (HCP, Agent mode) to deploy a database
	2.	Seed the database (same script, different connection)
	3.	Deploy backend & frontend using images we built here
	4.	Replace .env DB credentials with Vault-issued dynamic creds
	5.	Optionally add Boundary to access the database securely

After this step, you no longer manually docker run anything.

Terraform becomes the orchestrator.
Vault becomes the keeper of trust.
Boundary becomes the gate.

Full-circle.

⸻

Closing Notes

This setup is intentionally:
	•	Transparent — so you see where trust shifts
	•	Reversible — students can experiment + break things safely
	•	Extensible — we will use the same images in Terraform later

Remember:

The stack is not the lesson.
The progression is the lesson.
Vault + Terraform + Boundary are the arc.

We build → We run → We secure → We hand over trust to automation.

🛡️ Guardianship is an action, not a title.
