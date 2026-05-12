# ─── Outputs ─────────────────────────────────────────────────────────────

# Keypair id
output "ec2_public_id" {
  description = "Public IP of the k3s EC2 instance — use this to SSH in"
  value       = aws_instance.k3s_node.public_ip
}

# Instance id
output "ec2_instance_id" {
  description = "EC2 instance ID — useful for AWS console lookups"
  value       = aws_instance.k3s_node.id
}

# ECR details
output "aws_ecr_repository_url" {
  description = "ECR repository URL — used in CI pipeline to push images"
  value       = aws_ecr_repository.datavault_api.repository_url
}


output "aws_ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.datavault_api.name
}

# Output the Secret ARN (NOT the key material itself)
output "ssh_key_secret_arn" {
  value = aws_secretsmanager_secret.ssh_key.arn
}