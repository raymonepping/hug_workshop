variable "tfe_organization" {
  type    = string
  default = "HUGS_NL"
}

variable "assignment_mode" {
  description = "Per-user: personal team+project per user. Shared: one team+project for all."
  type        = string
  default     = "per_user"
  validation {
    condition     = contains(["per_user", "shared"], var.assignment_mode)
    error_message = "assignment_mode must be either \"per_user\" or \"shared\"."
  }
}

variable "shared_project_name" {
  type        = string
  default     = "project_chicago"
  description = "Only used when assignment_mode = shared"
}

variable "shared_team_name" {
  type        = string
  default     = "team_bulls"
  description = "Only used when assignment_mode = shared"
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

variable "organization_access" {
  description = "Global organization-wide access settings applied to all workshop teams"
  type = object({
    read_workspaces            = bool
    read_projects              = bool
    manage_workspaces          = bool
    manage_projects            = bool
    manage_agent_pools         = bool
    manage_run_tasks           = bool
    manage_policies            = bool
    manage_policy_overrides    = bool
    manage_vcs_settings        = bool
    manage_providers           = bool
    manage_modules             = bool
    manage_membership          = bool
    manage_teams               = bool
    manage_organization_access = bool
    access_secret_teams        = bool
  })
}
