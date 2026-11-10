# -----------------------------------------------------------------------------
# main.tf (organization stack)
# The skeleton of the landing zone: the organization, two organizational units
# (OUs), and the member accounts that live in them.
#
#   Root
#   |-- Security OU    log-archive, security
#   `-- Workloads OU   workloads-dev, workloads-prod
#
# Why accounts at all? An AWS account is the strongest boundary AWS offers:
# separate permissions, separate limits, separate bills, and a blast radius of
# one. Putting logs, security tooling and workloads in different accounts means
# the people who run the workloads cannot touch the evidence.
#
# Why OUs? Policies attach to an OU and apply to every account inside it, so
# the OU layout decides how the guardrails in step 3 are applied.
# -----------------------------------------------------------------------------

locals {
  ou_ids = {
    security  = aws_organizations_organizational_unit.security.id
    workloads = aws_organizations_organizational_unit.workloads.id
  }
}

# =============================================================================
# The organization
# =============================================================================
# The management account (the one running this code) owns the organization.
# IMPORTANT for a real account: if an organization already exists, bring it
# under Terraform first with `terraform import aws_organizations_organization.this <org-id>`.
# Applying this on top of an existing organization would otherwise fail.
resource "aws_organizations_organization" "this" {
  # ALL = consolidated billing PLUS the governance features (policies, delegated
  # administrators). The alternative, BILLING_ONLY, cannot use service control policies.
  feature_set = "ALL"

  # AWS services that are allowed to work across the whole organization. Each of
  # these is switched on here so that later steps can use them organization-wide.
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",               # one trail for every account
    "config.amazonaws.com",                   # configuration history
    "config-multiaccountsetup.amazonaws.com", # organization-wide Config rules
    "guardduty.amazonaws.com",                # threat detection
    "securityhub.amazonaws.com",              # security findings in one place
    "sso.amazonaws.com",                      # IAM Identity Center
  ]

  # Service control policies (SCPs) are the guardrails added in step 3.
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
}

# =============================================================================
# Organizational units
# =============================================================================
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

# =============================================================================
# Member accounts
# =============================================================================
resource "aws_organizations_account" "member" {
  for_each = var.member_accounts

  name      = each.value.name
  email     = each.value.email
  parent_id = local.ou_ids[each.value.ou]

  # Billing stays with the management account. IAM users inside a member account
  # cannot see or change billing.
  iam_user_access_to_billing = "DENY"

  # Removing the account from this code takes it OUT of the organization only.
  # It does not close the account. Closing is a separate, deliberate act.
  close_on_deletion = false

  tags = {
    AccountPurpose = each.key
  }

  lifecycle {
    # An account is not something to lose to a typo or a refactor. Terraform
    # refuses any plan that would destroy one. (To retire an account on purpose,
    # remove this line first.)
    prevent_destroy = true

    # AWS cannot change these two settings after creation. Without this, a harmless
    # difference would make Terraform propose replacing the whole account.
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}
