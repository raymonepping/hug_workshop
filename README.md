# 🚀 The Zero-Trust League: A Near Mission Impossible Exercise

**Mission briefing**
Your enterprise has been targeted by shadowy adversaries who thrive on static secrets, open firewalls, and bad compliance reports. The board has called in the *Zero-Trust League* — and that means you.

Your objective:
Stand up a secure, scalable application platform using the **HashiCorp arsenal**. Each tool is a hero in its own right, but only when they work together you will succeed.

**Should you choose to accept**, your mission is to:

* **Terraform** the infrastructure (with Stacks to keep the chaos in order).
* **Trigger Ansible** through Terraform Actions to configure your nodes.
* **Vault** all secrets with dynamic creds — no `.env` sins allowed.
* **Boundary** the entry points. No open doors. No excuses.

Failure to comply means… well, you’ll never hear the end of it from our Security and Auditors..

---

## 🦸 The Heroes of HashiCorp

* **Terraform**: The Architect — builds worlds from code.
* **Stacks**: The Strategist — keeps the layers disciplined and ordered.
* **Actions**: The Enforcer — makes Ansible run exactly when needed.
* **Vault**: The Keeper — master of dynamic secrets, banisher of hardcoded keys.
* **Boundary**: The Gatekeeper — only way in, no public shortcuts.

---

## 🕹️ Your Choices

* Platform: **Kubernetes**, **Docker**, or **Nomad**.
* Database: dealer’s choice. DataStax, Couchbase, MySQL, Postgres,.. whatever you like.
* App: hello-world service, simple API, or your own build.

*Remember: the app itself doesn’t matter. What matters is that it’s secured, automated, and only reachable through Boundary.*

---

## 🗂️ Mission Objectives

### Chapter 1 — Assemble the Blueprint

* Use **HCP Terraform**.
* Build infra using **Stacks**.
* Show clear dependencies: network → platform → app → vault → boundary.

### Chapter 2 — Unleash Ansible

* Configure a **Terraform Action** that triggers Ansible when your app infra is ready.
* Prove Ansible installs/configures your app.

### Chapter 3 — Guard the Secrets

* Integrate **Vault**.
* Use dynamic secrets for your app or DB.
* No hardcoded tokens. Prove with Vault audit logs.

### Chapter 4 — Lock the Gate

* Configure **Boundary** to expose your app only through a target.
* Show `boundary connect` works.
* Prove direct access is blocked.

### Chapter 5 — The Test of Fire

* Scale up: add more nodes/pods. Ansible should re-apply automatically.
* Rotate a secret in Vault. App must stay alive.
* Run a smoke test through Boundary.

---

## 📦 Deliverables

Submit a **field report** (Markdown, slides, or PDF) with:

* Screenshots of Stack run graph and Action logs.
* Snippets from Ansible runs.
* Vault audit log snippet showing dynamic creds.
* Boundary session transcript.
* Smoke test results.
* A short reflection: what was easy, what was hard, what you’d improve.

---

## 🛠️ Workshop Scripts

To speed up your mission, we’ve prepared a couple of scripts under ./scripts/:

./
├── scripts/
│   ├── setup_stacks.sh*          # Clones the demo repos, runs fmt/validate/init
│   └── start_terraform_agent.sh* # Launches a local Terraform Agent
├── LICENSE
└── README.md

### 🔧 setup_stacks.sh

Clones both repositories into a local working directory, then runs:

terraform fmt → formats code

terraform stacks validate → validates configuration

terraform stacks init → initializes providers and dependencies

Result: you start with a clean, ready-to-go setup.

### 🚀 start_terraform_agent.sh

Starts a Terraform Agent connected to your HCP Terraform organization.
This is required for the workshop since Stacks will run in Agent execution mode.

---

## ⚠️ Warning

Your infra will self-destruct if you:

* Leave secrets lying around in `.env`.
* Open a public port to your app.
* Try to skip Stacks or Actions.

This document will not self-destruct, but your grade might..
