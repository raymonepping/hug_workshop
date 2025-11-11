output "dream_team_token" {
    value = tfe_team_token.team_token["DreamTeam"].token
    sensitive = true
}
