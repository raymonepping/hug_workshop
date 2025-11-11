variable "tfe_organization" {
  type    = string
  default = "HUGS_NL"
}

variable "projects_prefix" {
  type    = string
  default = "project"
}

variable "common_team_name" {
  type    = string
  default = "Contributors"
}

variable "users_set" {
  type = set(string)
  default = [
    "repping@gmail.com",
    "cojan@gmail.com",
  ]
}
