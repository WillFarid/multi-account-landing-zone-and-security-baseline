# -----------------------------------------------------------------------------
# variables.tf
# More variables are added as each step needs them.
# -----------------------------------------------------------------------------
variable "project" {
  description = "Project name, used in tags."
  type        = string
  default     = "landing-zone"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project))
    error_message = "Project must be 3-30 characters: lowercase letters, numbers, hyphens."
  }
}

variable "home_region" {
  description = "The organization's home region. AWS Organizations is a global service, but its API is served from us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "mock_mode" {
  description = "true = fake credentials and no calls to AWS (offline plan). false for a real deployment."
  type        = bool
  default     = true
}
