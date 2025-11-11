resource "tfe_project" "project" {
  for_each = var.projects_set
  name = each.value
  organization = var.tfe_organization
}

resource "tfe_team" "team" {
  for_each = var.teams_set
  name         = each.value
  organization = var.tfe_organization
  organization_access {
    manage_vcs_settings = true
    read_workspaces = false
    read_projects = false
    manage_workspaces = false
    manage_projects = false
  }
}

resource "tfe_organization_membership" "orgmembership" {
  for_each = var.users_set
  organization = var.tfe_organization
  email = each.value
}

resource "tfe_team_organization_members" "teamorgmembers" {
  for_each = var.teams_set
  team_id = tfe_team.team[each.key].id
  organization_membership_ids = [for user in var.users_set : tfe_organization_membership.orgmembership[user].id]
}

resource "tfe_team_token" "team_token" {
  for_each = var.teams_set
  team_id = tfe_team.team[each.key].id
  description = "Dream team token"
}

