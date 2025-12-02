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
  # true  -> create per-user projects/teams
  # false -> create a single shared project/team
  assignment_per_user = var.assignment_mode == "per_user"
}

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
    prevent_destroy = false
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
  for_each     = local.assignment_per_user ? local.usernames : {}
  organization = var.tfe_organization
  name         = "${var.projects_prefix}_${each.value}"
}

resource "tfe_team" "personal" {
  for_each     = local.assignment_per_user ? local.usernames : {}
  organization = var.tfe_organization
  name         = "${var.personal_team_prefix}_${each.value}"

  organization_access {
    read_workspaces            = var.organization_access.read_workspaces
    read_projects              = var.organization_access.read_projects
    manage_workspaces          = var.organization_access.manage_workspaces
    manage_projects            = var.organization_access.manage_projects
    manage_agent_pools         = var.organization_access.manage_agent_pools
    manage_run_tasks           = var.organization_access.manage_run_tasks
    manage_policies            = var.organization_access.manage_policies
    manage_policy_overrides    = var.organization_access.manage_policy_overrides
    manage_vcs_settings        = var.organization_access.manage_vcs_settings
    manage_providers           = var.organization_access.manage_providers
    manage_modules             = var.organization_access.manage_modules
    manage_membership          = var.organization_access.manage_membership
    manage_teams               = var.organization_access.manage_teams
    manage_organization_access = var.organization_access.manage_organization_access
    access_secret_teams        = var.organization_access.access_secret_teams
  }
}


resource "tfe_team_organization_members" "personal_team_members" {
  for_each                    = local.assignment_per_user ? local.usernames : {}
  team_id                     = tfe_team.personal[each.key].id
  organization_membership_ids = [local.membership_ids[each.key]]
}

resource "tfe_team_project_access" "personal_access" {
  for_each   = local.assignment_per_user ? local.usernames : {}
  team_id    = tfe_team.personal[each.key].id
  project_id = tfe_project.user_project[each.key].id
  access     = "maintain"
}

resource "tfe_team_project_access" "contributors_access" {
  for_each   = var.enable_common_access && local.assignment_per_user ? local.usernames : {}
  team_id    = local.common_team_id
  project_id = tfe_project.user_project[each.key].id
  access     = "maintain"
}

########################################
# Shared project + shared team (assignment_mode = "shared")
########################################

# One shared team for everyone
resource "tfe_team" "shared" {
  count        = local.assignment_per_user ? 0 : 1
  organization = var.tfe_organization
  name         = var.shared_team_name

  organization_access {
    read_workspaces            = var.organization_access.read_workspaces
    read_projects              = var.organization_access.read_projects
    manage_workspaces          = var.organization_access.manage_workspaces
    manage_projects            = var.organization_access.manage_projects
    manage_agent_pools         = var.organization_access.manage_agent_pools
    manage_run_tasks           = var.organization_access.manage_run_tasks
    manage_policies            = var.organization_access.manage_policies
    manage_policy_overrides    = var.organization_access.manage_policy_overrides
    manage_vcs_settings        = var.organization_access.manage_vcs_settings
    manage_providers           = var.organization_access.manage_providers
    manage_modules             = var.organization_access.manage_modules
    manage_membership          = var.organization_access.manage_membership
    manage_teams               = var.organization_access.manage_teams
    manage_organization_access = var.organization_access.manage_organization_access
    access_secret_teams        = var.organization_access.access_secret_teams
  }
}

# One shared project for everyone
resource "tfe_project" "shared" {
  count        = local.assignment_per_user ? 0 : 1
  organization = var.tfe_organization
  name         = var.shared_project_name
}

# Add all org memberships to the shared team
resource "tfe_team_organization_members" "shared_members" {
  count   = local.assignment_per_user ? 0 : 1
  team_id = tfe_team.shared[0].id

  # everyone who’s in effective_emails joins the shared team
  organization_membership_ids = [
    for e in local.effective_emails : local.membership_ids[e]
  ]
}

# Give the shared team access to the shared project
resource "tfe_team_project_access" "shared_access" {
  count      = local.assignment_per_user ? 0 : 1
  team_id    = tfe_team.shared[0].id
  project_id = tfe_project.shared[0].id
  access     = "maintain"
}

# Optional: also give your common/contributors team access to the shared project
resource "tfe_team_project_access" "shared_contributors" {
  count      = (!local.assignment_per_user && var.enable_common_access) ? 1 : 0
  team_id    = local.common_team_id
  project_id = tfe_project.shared[0].id
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
