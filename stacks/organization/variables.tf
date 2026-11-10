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

variable "member_accounts" {
  description = <<-EOT
    The member accounts to create, keyed by a short role name.
    Every account needs its own, globally unique root email address. In real use
    employ plus-addressing on a mailbox you control, e.g. you+log-archive@example.com.
  EOT
  type = map(object({
    name  = string
    email = string
    ou    = string
  }))

  default = {
    log_archive = {
      name  = "log-archive"
      email = "aws-log-archive@example.com"
      ou    = "security"
    }
    security = {
      name  = "security"
      email = "aws-security@example.com"
      ou    = "security"
    }
    workloads_dev = {
      name  = "workloads-dev"
      email = "aws-workloads-dev@example.com"
      ou    = "workloads"
    }
    workloads_prod = {
      name  = "workloads-prod"
      email = "aws-workloads-prod@example.com"
      ou    = "workloads"
    }
  }

  validation {
    condition     = alltrue([for a in values(var.member_accounts) : contains(["security", "workloads"], a.ou)])
    error_message = "Each account's ou must be either security or workloads."
  }

  validation {
    condition     = alltrue([for a in values(var.member_accounts) : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", a.email))])
    error_message = "Every account needs a valid email address."
  }

  # AWS refuses to create two accounts with the same root email. Catching it here
  # is far better than finding out halfway through an apply. Case is ignored
  # because email addresses are not case-sensitive in practice.
  validation {
    condition     = length(distinct([for a in values(var.member_accounts) : lower(a.email)])) == length(var.member_accounts)
    error_message = "Every account needs a different email address. AWS requires each account's root email to be unique."
  }

  validation {
    condition     = alltrue([for a in values(var.member_accounts) : length(a.name) >= 1 && length(a.name) <= 50])
    error_message = "Account names must be 1 to 50 characters."
  }
}
