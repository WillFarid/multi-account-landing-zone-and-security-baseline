# organization

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.70 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_home_region"></a> [home\_region](#input\_home\_region) | The organization's home region. AWS Organizations is a global service, but its API is served from us-east-1. | `string` | `"us-east-1"` | no |
| <a name="input_mock_mode"></a> [mock\_mode](#input\_mock\_mode) | true = fake credentials and no calls to AWS (offline plan). false for a real deployment. | `bool` | `true` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name, used in tags. | `string` | `"landing-zone"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
