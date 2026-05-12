###############################################################################
# kms.tf
#
# PURPOSE: Customer-managed KMS keys for application-level encryption.
# Covers: ECR image encryption, Secrets Manager SSH key encryption,
#         EC2 root volume encryption.
#
# WHY CMK OVER AWS-MANAGED:
#   - Full audit trail of every encrypt/decrypt via CloudTrail
#   - Instant revocation capability (disable the key)
#   - Required for FCA compliance — you must control your own keys
###############################################################################

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "app" {
  description             = "CMK for DataVault application resources — ECR, Secrets Manager, EBS"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Root admin access — prevents accidental key lockout.
        # Without this, if all IAM policies are removed, the key becomes unmanageable.
        Sid    = "EnableRootAdminAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        # Secrets Manager needs explicit permission to use this key
        # for envelope encryption of stored secrets.
        Sid    = "AllowSecretsManagerEncryption"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.resource_tags, {
    Name      = "${var.project_name}-app-cmk"
    ManagedBy = var.manage
  })
}

resource "aws_kms_alias" "app" {
  name          = "alias/${var.project_name}-${var.environment}-app"
  target_key_id = aws_kms_key.app.key_id
}
