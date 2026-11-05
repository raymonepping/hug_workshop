# HUG Workshop — **Unlock the Data**

> **Revision in preparation:** the next workshop will run locally with Terraform,
> Ansible, Make, and fictional users `albert`, `brenda`, and `charlie`.
> See the [new PRD](./docs/PRD.md), [implementation prompts](./prompts/README.md),
> and [cleanup record](./docs/CLEANUP.md). The implementation below and the older
> workshop guides still describe the previous version; the local variant is not
> implemented yet.

> Looking for deep-dive references? See **[ARTICLE_INDEX.md](./docs/ARTICLE_INDEX.md)**.

---

This repository contains the code and scripts for the **HUG Workshop** where you will deploy a database, 
secure access to it using **Vault**, 
and reveal a hidden message once your backend is properly **unlocked**.

The goal is not to build a fancy app.  
The goal is to prove that **access control matters** — and that your application should only speak when the *keeper* (Vault) is acknowledged.

---

## 🧠 What You Will Build

- A **local database** of your choice:
  - PostgreSQL
  - MySQL
  - MongoDB
  - Couchbase
- A **backend (Node/Express)** that retrieves credentials from **Vault**
- A **frontend** that displays your data and visually indicates whether your backend is **locked** or **unlocked**

Once unlocked, your data reveals an easter-egg message.  
(Yes, it’s intentional. No, we will not tell you what it is.)

---

## 🏗️ The Architecture (simple and to the point)

```

Frontend (localhost:5173)
│
▼
Backend (localhost:3004)
│
▼
Vault  ← credentials / access control
│
▼
Database (local Docker)

```

Unlocking = proving your backend **obtained DB credentials from Vault**, not from `.env` alone.

---

## 📂 Repository Structure

```

./
├── backend/              # Express API (you implement vault.js here)
│   ├── connectors/       # DB-specific connection logic
│   └── server.js
│
├── frontend/             # Static UI that calls the backend
│   └── frontend.js
│
└── scripts/
├── seed_dataset.sh   # Populates your database with workshop data
└── start_terraform_agent.sh (optional enhancement)

````

---

## 🚀 Quick Start (Local Only)

```bash
# 1) Seed your DB once it's running
./scripts/seed_dataset.sh seed --db-type <postgres|mysql|mongo|couchbase>

# 2) Start backend
cd backend
npm install
npm run dev

# 3) Start frontend
cd frontend
npm install
npm run start
````

Visit:
👉 [http://localhost:5173](http://localhost:5173)

If your backend is locked, the frontend will politely (or not) let you know.

---

## 🔐 Vault Integration (the real exercise)

You must implement:

```
backend/vault.js
```

This file is responsible for retrieving credentials from either:

* **Vault KV** (baseline)
* **Vault Dynamic DB Credentials** (bonus)

You choose the mode via environment variables.
No copy/paste config magic. Use logic. Understand what you're doing.

---

## 📜 The Exercise Guide

This README is orientation only.
The full workshop challenge, scoring, and step-by-step is here:

👉 **[EXERCISE.md](./docs/EXERCISE.md)**

Read it. Follow it.
Winning requires understanding, not just assembling parts.

---

## 🧱 Requirements

* Docker
* Terraform CLI (HCP Terraform account recommended)
* Node.js 18+ or 20+
* Vault (local or HCP Vault — either is fine)

If you want bonus points:
Use the provided Terraform agent script and run everything through **HCP Terraform** properly.

---

## 🤝 Optional Enhancements (if you finish early)

* Use **dynamic** DB credentials from Vault instead of static KV.
* Rotate those credentials **during runtime** without restarting the backend.
* Add TLS between backend ↔ DB.
* Add MFA to Vault login.
* Show before/after unlock in your demo.

---

## 🏁 Final Thought

If the data speaks without authorization, the system is lying to you.
If the data remains silent until properly unlocked, you’re doing it right.

---

🟣 Welcome to the *Workshop*.
🟡 The system is listening. The question is: are *you*?
