###############################################################################
# infra/backend.tf
#
# PURPOSE: Configures remote state storage in S3 with S3-native locking.
#
# LOCKING: use_lockfile = true enables S3-native state locking. Terraform
#          writes a .tflock file alongside the state file in S3. This replaces
#          the deprecated DynamoDB-based locking mechanism.
#
# SETUP: Replace the bucket placeholder below with the output from the
#        bootstrap workspace before running terraform init in this directory.
#
#   bucket = output: state_bucket_name (from bootstrap)
###############################################################################

terraform {
  backend "s3" {
    bucket       = "datavault-tfstate-dev-3fc2ed4a"
    key          = "datavault/dev/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
