###############################################################################
# bootstrap/main.tf
#
# PURPOSE: One-time setup. Creates the S3 bucket that the main infra workspace
#          uses for remote state storage and S3-native locking.
#
# LOCKING: State locking is handled by S3 natively via use_lockfile = true in
#          infra/backend.tf. DynamoDB-based locking is deprecated as of recent
#          Terraform versions and has been removed from this project.
#
# IMPORTANT: This workspace uses LOCAL state intentionally. You cannot store
#            state in an S3 bucket that Terraform itself is creating.
#
# RUN ONCE: After applying, copy the bucket name from outputs into
#           infra/backend.tf, then never run this workspace again unless
#           you are rebuilding from scratch.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.resource_tags
  }
}

###############################################################################
# KMS Key — Customer-Managed Encryption for State Bucket
#
# Using a customer-managed key (CMK) instead of the AWS-managed default gives
# fine-grained control: you can rotate, disable, or audit key usage via
# CloudTrail. Required to pass tfsec aws-s3-encryption-customer-key.
###############################################################################

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "terraform_state" {
  description             = "CMK for VaultBridge Terraform state bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true # Rotate annually — security best practice

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM root permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.project_name}-tfstate-${var.environment}"
  target_key_id = aws_kms_key.terraform_state.key_id
}

###############################################################################
# S3 Bucket — Remote State Storage
# Logging is intentionally disabled: enabling it would require a second S3
# bucket to receive the logs, creating a circular bootstrap dependency.
# Acceptable trade-off for a Terraform-state-only bucket.
###############################################################################
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "terraform_state" {
  # Bucket names must be globally unique. The random suffix achieves this.
  bucket = "${var.project_name}-tfstate-${var.environment}-${random_id.suffix.hex}"

  # prevent_destroy removed — intentionally tearing down this environment.
  lifecycle {
    prevent_destroy = false
  }
}

resource "random_id" "suffix" {
  byte_length = var.byte_length
}

# Enable versioning so every state file change is preserved and recoverable.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = var.versioning_status
  }
}

# Encrypt state at rest using the customer-managed KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true # Reduces KMS API call costs
  }
}

# Block all public access. State files must never be publicly readable.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = var.global_bool
  block_public_policy     = var.global_bool
  ignore_public_acls      = var.global_bool
  restrict_public_buckets = var.global_bool
}
