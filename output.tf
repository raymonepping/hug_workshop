output "common_team_token" {
  value     = tfe_team_token.common_team_token.token
  sensitive = true
}

output "user_projects" {
  value = {
    for email, username in local.users :
    username => {
      project_name = tfe_project.user_project[email].name
      project_id   = tfe_project.user_project[email].id
      team_name    = tfe_team.personal[email].name
      team_id      = tfe_team.personal[email].id
    }
  }
  description = "Per-user project and team mapping"
}
