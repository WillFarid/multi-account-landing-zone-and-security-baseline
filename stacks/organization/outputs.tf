# -----------------------------------------------------------------------------
# outputs.tf (organization stack)
# Nothing here is secret. The account IDs are the inputs of the next stack.
# -----------------------------------------------------------------------------
output "organization_id" {
  description = "ID of the organization."
  value       = aws_organizations_organization.this.id
}

output "root_id" {
  description = "ID of the organization root. Policies attached here apply to every account."
  value       = aws_organizations_organization.this.roots[0].id
}

output "ou_ids" {
  description = "IDs of the organizational units, keyed by short name. Policies attach to these."
  value       = local.ou_ids
}

output "account_ids" {
  description = "IDs of the member accounts, keyed by role. The baseline stack needs them to assume a role in each account."
  value       = { for key, account in aws_organizations_account.member : key => account.id }
}

output "scp_ids" {
  description = "IDs of the service control policies, keyed by name."
  value       = { for key, policy in aws_organizations_policy.scp : key => policy.id }
}
