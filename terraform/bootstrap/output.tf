###############################################################################
# bootstrap/outputs.tf
#
# After applying, copy the bucket name into infra/backend.tf
###############################################################################

output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state. Copy this into infra/backend.tf."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the S3 state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the state bucket."
  value       = aws_kms_key.terraform_state.arn
}
