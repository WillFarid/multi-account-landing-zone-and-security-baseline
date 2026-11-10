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

variable "allowed_regions" {
  description = "The only regions member accounts may use. Everything else is denied by a service control policy. Include the home region."
  type        = list(string)
  default     = ["us-east-1", "us-west-2"]

  validation {
    condition     = length(var.allowed_regions) >= 1 && alltrue([for r in var.allowed_regions : can(regex("^[a-z]{2}-[a-z]+-[0-9]$", r))])
    error_message = "allowed_regions must list at least one valid region name, such as us-east-1."
  }

  # The Organizations API itself is served from the home region. Locking the
  # accounts out of it would make the organization impossible to manage.
  validation {
    condition     = contains(var.allowed_regions, var.home_region)
    error_message = "allowed_regions must include home_region."
  }
}

variable "security_admin_role_name" {
  description = <<-EOT
    The one role allowed to change the security services (CloudTrail, Config,
    GuardDuty, Security Hub) that the baseline policy protects. Terraform uses it
    to manage them. Production setups use a dedicated, tightly controlled role.
  EOT
  type        = string
  default     = "OrganizationAccountAccessRole"

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.security_admin_role_name))
    error_message = "security_admin_role_name must be a valid IAM role name (1 to 64 characters)."
  }
}
