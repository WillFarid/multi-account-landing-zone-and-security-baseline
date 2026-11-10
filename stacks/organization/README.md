# organization

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.70 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_organizations_account.member](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_account) | resource |
| [aws_organizations_organization.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organization) | resource |
| [aws_organizations_organizational_unit.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_organizational_unit.workloads](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_home_region"></a> [home\_region](#input\_home\_region) | The organization's home region. AWS Organizations is a global service, but its API is served from us-east-1. | `string` | `"us-east-1"` | no |
| <a name="input_member_accounts"></a> [member\_accounts](#input\_member\_accounts) | The member accounts to create, keyed by a short role name.<br/>Every account needs its own, globally unique root email address. In real use<br/>employ plus-addressing on a mailbox you control, e.g. you+log-archive@example.com. | <pre>map(object({<br/>    name  = string<br/>    email = string<br/>    ou    = string<br/>  }))</pre> | <pre>{<br/>  "log_archive": {<br/>    "email": "aws-log-archive@example.com",<br/>    "name": "log-archive",<br/>    "ou": "security"<br/>  },<br/>  "security": {<br/>    "email": "aws-security@example.com",<br/>    "name": "security",<br/>    "ou": "security"<br/>  },<br/>  "workloads_dev": {<br/>    "email": "aws-workloads-dev@example.com",<br/>    "name": "workloads-dev",<br/>    "ou": "workloads"<br/>  },<br/>  "workloads_prod": {<br/>    "email": "aws-workloads-prod@example.com",<br/>    "name": "workloads-prod",<br/>    "ou": "workloads"<br/>  }<br/>}</pre> | no |
| <a name="input_mock_mode"></a> [mock\_mode](#input\_mock\_mode) | true = fake credentials and no calls to AWS (offline plan). false for a real deployment. | `bool` | `true` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name, used in tags. | `string` | `"landing-zone"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_account_ids"></a> [account\_ids](#output\_account\_ids) | IDs of the member accounts, keyed by role. The baseline stack needs them to assume a role in each account. |
| <a name="output_organization_id"></a> [organization\_id](#output\_organization\_id) | ID of the organization. |
| <a name="output_ou_ids"></a> [ou\_ids](#output\_ou\_ids) | IDs of the organizational units, keyed by short name. Policies attach to these. |
| <a name="output_root_id"></a> [root\_id](#output\_root\_id) | ID of the organization root. Policies attached here apply to every account. |
<!-- END_TF_DOCS -->
