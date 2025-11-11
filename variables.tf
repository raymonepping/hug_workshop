variable "tfe_organization" {
  type    = string
  default = "HUGS_NL"
}

variable "common_team_name" {
  type    = string
  default = "Contributors"
}

variable "existing_team_id" {
  description = "Optional: If set, we skip lookup by name and use this team ID directly."
  type        = string
  default     = ""
}

variable "projects_prefix" {
  type    = string
  default = "project"
}

variable "personal_team_prefix" {
  type    = string
  default = "team"
}

variable "enable_common_access" {
  description = "Grant the common team access to each per-user project."
  type        = bool
  default     = true
}

variable "write_credentials_file" {
  description = "When bootstrapping, write credentials.auto.tfvars.json with resolved IDs."
  type        = bool
  default     = true
}

# Locked/steady-state input. Key = email (lowercase), value contains IDs & username.
# When this map is non-empty, memberships are NOT created; values are reused.
variable "users" {
  type = map(object({
    username      = string
    membership_id = string
    user_id       = optional(string) # can be empty/omitted
  }))
  default = {}
}

variable "emails" {
  type        = list(string)
  description = "List of user email addresses to bootstrap"
  default     = []
}

variable "using_locked" {
  type        = bool
  description = "Whether to use locked tfvars with user IDs"
  default     = false
}

