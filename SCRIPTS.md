# 📘 SCRIPTS.md

Utility scripts included in this workshop

This page gives you a fast, practical overview of every script in the repo, what it does, and how to use it. Designed so both engineers and newcomers can get started immediately.

---

# 🚀 Getting Started

Before using any script:

1. Clone the repository

   ```bash
   git clone https://github.com/raymonepping/hug_workshop.git
   cd hug_workshop
   ```

2. Copy and adjust the relevant `.env` files:

   ```bash
   cp env_examples/_env_* .
   ```

3. Make scripts executable (if needed):

   ```bash
   chmod +x *.sh Vault/*.sh
   ```

You are ready to run backend, frontend, database, Vault, and Terraform workflows.

---

# 📂 Folder Structure

```
./
├── output/
│   └── credentials_pretty.json
├── Vault/
│   ├── login_vault.sh
│   └── unwrap_story.sh
├── construct_container.sh
├── seed_dataset.sh
└── start_terraform_agent.sh
```

---

# 🧰 Script Reference

---

## 🏗️ construct_container.sh

Builds the backend or frontend container image for local testing or later deployment through Terraform.

**Typical usage:**

```bash
./construct_container.sh backend
./construct_container.sh frontend
```

**What it does:**
Packages your chosen component into a container image, tags it, and prepares it for local runs or registry pushes.

---

## 🌱 seed_dataset.sh

Seeds any supported workshop database (MySQL, PostgreSQL, MongoDB, Couchbase) with the demo dataset.

**Typical usage:**

```bash
./seed_dataset.sh seed \
  --db-type postgres \
  --user workshop \
  --password workshop
```

**What it does:**
Initializes tables and loads the sample data used by the backend exercises.

---

## ⚙️ start_terraform_agent.sh

Controls your local Terraform agent used by HCP Terraform to run workloads on your machine.

**Typical usage:**

```bash
./start_terraform_agent.sh up
./start_terraform_agent.sh status
./start_terraform_agent.sh down
```

**What it does:**
Starts or stops the agent container, checks logs, and ensures runs from HCP Terraform execute locally.

---

# 🔐 Vault Scripts

## 🔑 Vault/login_vault.sh

Logs into Vault using credentials or wrapped tokens issued for the workshop.

**Typical usage:**

```bash
./Vault/login_vault.sh
```

**What it does:**
Authenticates you against the correct Vault namespace and stores a local Vault token for CLI usage.

---

## 📦 Vault/unwrap_story.sh

Unwraps the story tokens distributed to participants to retrieve hidden payloads or next steps.

**Typical usage:**

```bash
./Vault/unwrap_story.sh \
  token.something.wrappedvalue
```

**What it does:**
Exchanges a single-use wrapped token for real Vault content used in the exercise.

---

# 📤 Output Files

## 🗒️ output/credentials_pretty.json

A formatted JSON file containing generated workshop credentials or artifacts.
