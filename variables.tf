variable "tfe_organization" {
  type = string
  default = "HUGS_NL"
}

variable "projects_set" {
  type = set(string)
  default = ["Zero-Trust-Infrastructure", "HUG-Workshop"]
}

variable "teams_set" {
  type = set(string)
  default = ["DreamTeam"]
}

variable "users_set" {
  type = set(string)
  default = [
    "repping@gmail.com",
    "cojan@gmail.com",
  ]
}
