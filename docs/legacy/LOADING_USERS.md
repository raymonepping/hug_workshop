> Historical workshop material. Commands and requirements below are obsolete.
> Start with [the current setup guide](../SETUP.md) and [exercises](../EXERCISES.md).

# 📦 Loading Users into Terraform Cloud: JSON to tfvars the Smart Way

Terraform Cloud user onboarding doesn't have to involve guesswork, duplication, or brittle hardcoding. In this short guide, we’ll walk through how to use a clean JSON input, a smart Bash script, and Terraform outputs to create a locked, reproducible `locked_users.auto.tfvars` file for consistent user management.

---

## 🔁 Workflow Overview

```bash
bootstrap.json → generate_tfvars_from_json.sh → credentials.auto.tfvars.json → locked_users.auto.tfvars
```

---

## 🧾 Input: `bootstrap.json`

This file contains your initial list of user emails:

```json
{
  "emails": [
    "raymoon.epping@hashicorp.com"
    "cojan.vanballegooijen@hashicorp.com",
    "mahil@hashicorp.com"
  ]
}
```

---

## 🔨 Script: `generate_tfvars_from_json.sh`

This script:

* Detects whether you're bootstrapping or loading credentials
* Runs `terraform apply` to resolve IDs
* Captures output and converts to HCL tfvars
* Handles cleanup if needed

Usage:

```bash
./scripts/generate_tfvars_from_json.sh bootstrap.json [--cleanup]
```

---

## 🔐 Intermediate Output: `credentials.auto.tfvars.json`

```json
{
  "users": {
    "cojan.vanballegooijen@hashicorp.com": {
      "username": "cojan_vanballegooijen",
      "membership_id": "ou-xxxxx",
      "user_id": "user-yyyy"
    },
    ...
  }
}
```

---

## 🧱 Final Output: `locked_users.auto.tfvars`

Terraform-compatible HCL file:

```hcl
users = {
  "cojan.vanballegooijen@hashicorp.com" = {
    username      = "cojan_vanballegooijen"
    membership_id = "ou-xxxxx"
    user_id       = "user-yyyy"
  }
  ...
}
```

---

## 📂 Folder Layout

```
.
├── bootstrap.json
├── credentials.auto.tfvars.json
├── locked_users.auto.tfvars
├── scripts/
│   └── generate_tfvars_from_json.sh
├── main.tf
├── variables.tf
├── outputs.tf
```

---

## ✅ Benefits

* 🧪 Reproducible across environments
* 💾 Locked inputs, versioned in Git
* 👥 Easy to onboard new users—just append email
* 🧼 No need to manually retrieve user IDs

---

This approach saves time, reduces risk, and aligns with Terraform best practices. Copy, adapt, or fork for your team.

---
