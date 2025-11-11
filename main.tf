# 1) Invite users into the org (this sends the invite if they’re not yet members)
resource "tfe_organization_membership" "org_membership" {
  for_each     = local.users
  organization = var.tfe_organization
  email        = each.key
}

# 2) Create a common team (Contributors) and add ALL users to it
resource "tfe_team" "common" {
  name         = var.common_team_name
  organization = var.tfe_organization

  organization_access {
    manage_vcs_settings = true
    read_workspaces     = false
    read_projects       = false
    manage_workspaces   = false
    manage_projects     = false
  }
}

resource "tfe_team_organization_members" "common_team_members" {
  team_id = tfe_team.common.id
  # all org membership ids
  organization_membership_ids = [
    for email, _username in local.users :
    tfe_organization_membership.org_membership[email].id
  ]
}

# Optional: create a token for the common team if you need automation scoped to it
resource "tfe_team_token" "common_team_token" {
  team_id     = tfe_team.common.id
  description = "Common team token"
}

# 3) For each user, create a dedicated project: project_<username>
resource "tfe_project" "user_project" {
  for_each     = local.users
  organization = var.tfe_organization
  name         = "${var.projects_prefix}_${each.value}"
}

# 4) Per-user team (contains only that user) with maintainer/admin on their project
resource "tfe_team" "personal" {
  for_each     = local.users
  name         = "team_${each.value}"        # e.g., team_repping
  organization = var.tfe_organization
}

resource "tfe_team_organization_members" "personal_team_members" {
  for_each = local.users
  team_id  = tfe_team.personal[each.key].id
  organization_membership_ids = [
    tfe_organization_membership.org_membership[each.key].id
  ]
}

# 5) Grant the per-user team access to the per-user project
# Note: In the tfe provider this is typically `tfe_project_team_access` with an `access` level.
# Valid values commonly include: "admin", "maintain", "write", "read" (check your provider version).
# Use "maintain" (or "admin") so the user can create/manage workspaces within the project.
resource "tfe_project_team_access" "personal_access" {
  for_each   = local.users
  project_id = tfe_project.user_project[each.key].id
  team_id    = tfe_team.personal[each.key].id

  access = "maintain"
  # If your provider version uses different names, swap to a valid one (e.g., "admin").
}
