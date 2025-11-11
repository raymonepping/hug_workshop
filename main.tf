provider "tfe" {}

########################################
# Load bootstrap emails (if file exists)
########################################
locals {
  bootstrap_obj    = try(jsondecode(file("${path.module}/bootstrap.json")), { emails = [] })
  bootstrap_emails = toset([for e in local.bootstrap_obj.emails : lower(e)])
}

########################################
# Mode selection & username derivation
########################################
locals {
  using_locked = false # true

  # Effective email set:
  # - locked mode: keys of var.users
  # - bootstrap mode: emails from bootstrap.json
  effective_emails = local.using_locked ? toset(keys(var.users)) : local.bootstrap_emails

  # Derive usernames:
  # - locked: provided via var.users
  # - bootstrap: sanitize local-part (., +, -) -> _
  usernames = (
    local.using_locked ?
    { for e, u in var.users : e => u.username } :
    { for e in local.effective_emails :
      e => replace(replace(replace(lower(element(split("@", e), 0)), ".", "_"), "+", "_"), "-", "_")
    }
  )
}

########################################
# Common team (by name or ID override)
########################################
data "tfe_team" "common" {
  count        = var.existing_team_id == "" ? 1 : 0
  name         = var.common_team_name
  organization = var.tfe_organization
}

locals {
  common_team_id = var.existing_team_id != "" ? var.existing_team_id : data.tfe_team.common[0].id
}

########################################
# Bootstrap memberships (now always declared)
########################################
locals {
  org_membership_map = local.using_locked ? { for email in local.effective_emails : email => email } : { for email in local.effective_emails : email => email }
}

resource "tfe_organization_membership" "org_membership" {
  for_each     = local.org_membership_map
  organization = var.tfe_organization
  email        = each.key

  lifecycle {
    ignore_changes  = [email]
    prevent_destroy = true
  }
}

# Resolve IDs for both modes
locals {
  membership_ids = (
    local.using_locked
    ? { for e, u in var.users : e => u.membership_id }
    : { for e, m in tfe_organization_membership.org_membership : e => m.id }
  )
  user_ids = (
    local.using_locked
    ? { for e, u in var.users : e => try(u.user_id, "") }
    : { for e in local.effective_emails : e => "" }
  )
}

########################################
# Per-user project, per-user team
########################################
resource "tfe_project" "user_project" {
  for_each     = local.usernames
  organization = var.tfe_organization
  name         = "${var.projects_prefix}_${each.value}"
}

resource "tfe_team" "personal" {
  for_each     = local.usernames
  organization = var.tfe_organization
  name         = "${var.personal_team_prefix}_${each.value}"
}

resource "tfe_team_organization_members" "personal_team_members" {
  for_each = local.usernames
  team_id  = tfe_team.personal[each.key].id

  organization_membership_ids = [local.membership_ids[each.key]]
}

# Personal team -> their project
resource "tfe_team_project_access" "personal_access" {
  for_each   = local.usernames
  team_id    = tfe_team.personal[each.key].id
  project_id = tfe_project.user_project[each.key].id
  access     = "maintain"
}

# Optional: common team -> each project
resource "tfe_team_project_access" "contributors_access" {
  for_each   = var.enable_common_access ? local.usernames : {}
  team_id    = local.common_team_id
  project_id = tfe_project.user_project[each.key].id
  access     = "maintain"
}

########################################
# Persist credentials for steady-state
########################################
locals {
  users_to_persist = local.using_locked ? var.users : {
    for e in local.effective_emails : e => {
      username      = local.usernames[e]
      membership_id = local.membership_ids[e]
      user_id       = local.user_ids[e]
    }
  }
}

resource "local_file" "persist_credentials" {
  count    = local.using_locked || !var.write_credentials_file ? 0 : 1
  filename = "${path.module}/credentials.auto.tfvars.json"
  content = jsonencode({
    users = local.users_to_persist
  })
}
