# -----------------------------------------------------------------------------
# providers.tf
# This stack runs in the MANAGEMENT account, the one account that owns the
# organization. Everything that creates or governs accounts happens here.
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.home_region

  access_key = var.mock_mode ? "mock-access-key" : null
  secret_key = var.mock_mode ? "mock-secret-key" : null

  skip_credentials_validation = var.mock_mode
  skip_requesting_account_id  = var.mock_mode
  skip_metadata_api_check     = var.mock_mode

  default_tags {
    tags = {
      Project     = var.project
      ManagedBy   = "terraform"
      Repository  = "multi-account-landing-zone-and-security-baseline"
      AccountRole = "management"
    }
  }
}
