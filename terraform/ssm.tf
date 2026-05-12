
# ─── EC2 Keypair & Secret Manager ─────────────────────────────────────────────────────────────

# Generate the private key
resource "tls_private_key" "main" {
  algorithm = var.keypair_algor
  rsa_bits  = var.keypair_bits
}

# Create the EC2 Key Pair
resource "aws_key_pair" "datavault_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.main.public_key_openssh

  tags = merge(var.resource_tags, {
    Environment = var.environment
    ManagedBy   = var.manage
  })
}

# Securely store the private key in Secrets Manager
resource "aws_secretsmanager_secret" "ssh_key" {
  name        = "${var.project_name}/${var.environment}-deployer"
  description = "Private SSH key for production EC2 instances"
  kms_key_id  = aws_kms_key.app.arn

  # Best Practice: Force deletion without recovery window only if needed for testing
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "ssh_key_val" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = tls_private_key.main.private_key_pem

   lifecycle {
    ignore_changes = [secret_string] # Allow Lambda to manage values after deployment
  }
}