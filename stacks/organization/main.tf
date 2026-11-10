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

# =============================================================================
# Service control policies (SCPs): the guardrails
# =============================================================================
# HOW AN SCP DIFFERS FROM AN IAM POLICY
#   An IAM policy GRANTS permissions to a user or role.
#   An SCP grants NOTHING. It sets the MAXIMUM that anyone in an account can ever
#   be given. Effective permissions are the INTERSECTION of the two: an action
#   works only if an IAM policy allows it AND no SCP denies it. A Deny in an SCP
#   cannot be overridden by anyone, including an account administrator and the
#   account's root user.
#
# WHAT SCPs DO NOT COVER
#   They never apply to the MANAGEMENT account, and never to service-linked roles.
#   That is why the management account must be kept almost empty and tightly
#   locked down by other means.
#
# STRATEGY: DENY LIST
#   AWS attaches a built-in "FullAWSAccess" policy to the root by default. We keep
#   it and add policies that DENY specific things. The alternative, an allow
#   list, is stricter but breaks every time a new service is needed.
#
# THE RISK
#   A wrong SCP can lock everyone out of an account, and the account's own admins
#   cannot undo it. Test every new SCP on a sandbox OU before it reaches the root.
# =============================================================================
locals {
  # Services whose API is global: a request to them is not tied to one region, so
  # the region restriction must not block them. If a service you need turns out
  # to be global, it fails with an explicit deny from a service control policy
  # (SCP). Add it here.
  global_service_actions = [
    "account:*",
    "aws-portal:*",
    "budgets:*",
    "ce:*",
    "cloudfront:*",
    "cur:*",
    "ec2:DescribeRegions",
    "globalaccelerator:*",
    "health:*",
    "iam:*",
    "organizations:*",
    "pricing:*",
    "route53:*",
    "route53domains:*",
    "s3:GetAccountPublicAccessBlock",
    "s3:ListAllMyBuckets",
    "s3:PutAccountPublicAccessBlock",
    "shield:*",
    "sts:*",
    "support:*",
    "trustedadvisor:*",
    "waf:*",
    "waf-regional:*",
    "wafv2:*",
  ]

  scps = {
    # 1. Nobody can take an account out of the organization. Leaving would remove
    #    every other guardrail with it.
    deny_leave_organization = {
      name        = "deny-leave-organization"
      description = "Member accounts cannot leave the organization."
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "DenyLeaveOrganization"
          Effect   = "Deny"
          Action   = ["organizations:LeaveOrganization"]
          Resource = "*"
        }]
      })
    }

    # 2. The root user of a member account can do anything, cannot be limited by
    #    IAM, and has no accountability. Deny all of its actions. IMPORTANT: attach
    #    this only AFTER each account's root user has MFA set up (or use AWS's
    #    centralized root access management), because setting MFA is itself a
    #    root action.
    deny_root_user = {
      name        = "deny-root-user"
      description = "The root user of a member account cannot perform any action."
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "DenyRootUser"
          Effect   = "Deny"
          Action   = "*"
          Resource = "*"
          Condition = {
            StringLike = {
              "aws:PrincipalArn" = ["arn:aws:iam::*:root"]
            }
          }
        }]
      })
    }

    # 3. Only approved regions. Anything requested in another region is denied,
    #    except the global services listed above. This shrinks the attack surface
    #    (an attacker cannot quietly mine crypto in a region nobody watches) and
    #    keeps spending visible.
    restrict_regions = {
      name        = "restrict-regions"
      description = "Deny all actions outside the allowed regions, except global services."
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid       = "DenyOutsideAllowedRegions"
          Effect    = "Deny"
          NotAction = local.global_service_actions
          Resource  = "*"
          Condition = {
            StringNotEquals = {
              "aws:RequestedRegion" = var.allowed_regions
            }
          }
        }]
      })
    }

    # 4. Nobody can switch off the audit and detection services. The one exemption
    #    is the named security admin role, so Terraform can still manage them.
    protect_security_baseline = {
      name        = "protect-security-baseline"
      description = "Deny disabling or deleting CloudTrail, Config, GuardDuty and Security Hub, except by the security admin role."
      content = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "DenyDisablingSecurityServices"
          Effect = "Deny"
          Action = [
            "cloudtrail:DeleteTrail",
            "cloudtrail:PutEventSelectors",
            "cloudtrail:StopLogging",
            "cloudtrail:UpdateTrail",
            "config:DeleteConfigurationRecorder",
            "config:DeleteDeliveryChannel",
            "config:StopConfigurationRecorder",
            "guardduty:DeleteDetector",
            "guardduty:DisassociateFromAdministratorAccount",
            "guardduty:DisassociateFromMasterAccount",
            "guardduty:DisassociateMembers",
            "guardduty:StopMonitoringMembers",
            "guardduty:UpdateDetector",
            "securityhub:BatchDisableStandards",
            "securityhub:DisableSecurityHub",
            "securityhub:DisassociateFromAdministratorAccount",
            "securityhub:DisassociateMembers",
          ]
          Resource = "*"
          Condition = {
            ArnNotLike = {
              "aws:PrincipalARN" = "arn:aws:iam::*:role/${var.security_admin_role_name}"
            }
          }
        }]
      })
    }
  }
}

resource "aws_organizations_policy" "scp" {
  for_each = local.scps

  name        = each.value.name
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.content

  # SCPs can only be created after the organization has switched the policy type on.
  depends_on = [aws_organizations_organization.this]
}

# Attached at the ROOT, so each policy applies to every member account, present
# and future. In a real rollout you would attach to a sandbox OU first.
resource "aws_organizations_policy_attachment" "root" {
  for_each = aws_organizations_policy.scp

  policy_id = each.value.id
  target_id = aws_organizations_organization.this.roots[0].id
}
