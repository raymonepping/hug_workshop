output "usernames" {
  description = "Derived usernames per email"
  value       = local.usernames
}

output "project_names" {
  description = "Per-user projects created"
  value       = { for e, p in tfe_project.user_project : e => p.name }
}

output "contributors_team_id" {
  description = "Contributors/common team id"
  value       = local.common_team_id
}

output "granted_access_level" {
  value = "maintain"
}

