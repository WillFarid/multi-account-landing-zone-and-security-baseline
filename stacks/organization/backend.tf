# -----------------------------------------------------------------------------
# backend.tf
# Remote state with S3 native locking. Placeholder bucket until a real account.
# This stack has its OWN state, separate from the security baseline stack that
# comes later: the organization is created once and changed rarely, and the
# baseline needs the account IDs that this stack produces.
# -----------------------------------------------------------------------------
terraform {
  backend "s3" {
    bucket       = "REPLACE-ME-tfstate-bucket-landing-zone"
    key          = "landing-zone/organization/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
