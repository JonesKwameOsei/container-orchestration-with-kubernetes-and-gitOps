# ── ECR Repository ────────────────────────────────────────────────────────────────
# Stores Docker images built by the Github Actions CI pipeline.
# The K3s cluster pulls images from here during deployments.

resource "aws_ecr_repository" "datavault_api" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = var.immutability

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.app.arn
  }

  tags = merge(var.resource_tags, {
    Name        = "${var.project_name}-api"
    Environment = var.environment
    ManagedBy   = var.manage
  })
}

# ── Security Group ────────────────────────────────────────────────────────────────
# Controlling what traffic can reach the EC2

resource "aws_security_group" "k3s_sg" {
  name        = var.project_name
  description = "Security group for the VaultBridge application server"

  tags = merge(var.resource_tags, {
    Name        = "${var.project_name}-k3s-sg"
    environment = var.environment
    ManagedBy   = var.manage
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSH - for initial setup and debugging

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "SSH access from operator IP only"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_ssh_cidr
}

# HTTP
resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "HTTP traffic"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# HTTPS
resource "aws_vpc_security_group_ingress_rule" "ec2_https" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "HTTPS traffic"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# Kuberbetes API server - kubectl and ArgoCD to use this
resource "aws_vpc_security_group_ingress_rule" "k3s_api_server" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "k3s api traffic"
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "argo_ui" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "ArgoCD web UI"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "Kubernetes NodePort service"
  from_port         = 30000
  to_port           = 32767
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all_egress" {
  security_group_id = aws_security_group.k3s_sg.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}


# ─── IAM Role for EC2 ─────────────────────────────────────────────────────────
# Allows the EC2 instance to pull images from ECR without storing credentials.
# This is the AWS-native way — no passwords, no access keys on the server.

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.resource_tags, {
    Name = "${var.project_name}-ec2-role"
  })
}

# Attach policy
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile" #
  role = aws_iam_role.ec2_role.name
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────
# The single node that runs k3s (Kubernetes) + ArgoCD + the DataVault app.

# # Generate the private key
# resource "tls_private_key" "main" {
#   algorithm = var.keypair_algor
#   rsa_bits  = var.keypair_bits
# }

# # Create the EC2 Key Pair
# resource "aws_key_pair" "datavault_key" {
#   key_name   = "${var.project_name}-key"
#   public_key = tls_private_key.main.public_key_openssh

#   tags = merge(var.resource_tags, {
#     Environment = var.environment
#     ManagedBy   = var.manage
#   })
# }

# # Securely store the private key in Secrets Manager
# resource "aws_secretsmanager_secret" "ssh_key" {
#   name        = "${var.project_name}/${var.environment}-deployer"
#   description = "Private SSH key for production EC2 instances"
#   kms_key_id  = aws_kms_key.app.arn

#   # Best Practice: Force deletion without recovery window only if needed for testing
#   recovery_window_in_days = 7
# }

# resource "aws_secretsmanager_secret_version" "ssh_key_val" {
#   secret_id     = aws_secretsmanager_secret.ssh_key.id
#   secret_string = tls_private_key.main.private_key_pem
# }

resource "aws_instance" "k3s_node" {
  ami                         = data.aws_ami.amiID.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.datavault_key.key_name
  vpc_security_group_ids      = [aws_security_group.k3s_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  user_data                   = templatefile("user_data.tftpl", { 
    department = var.user_department 
    name = var.user_name 
    hostname = var.hostname
    })

  # IMDSv2 — require session token for all metadata requests.
  # Blocks SSRF attacks that attempt to steal IAM credentials via the metadata endpoint.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_size = var.ec2_volume_size
    volume_type = var.ec2_volume_type
    encrypted   = true
    kms_key_id  = aws_kms_key.app.arn
  }

  tags = merge(var.resource_tags, {
    Name        = "${var.project_name}-k3s-node"
    Environment = var.environment
    ManagedBy   = var.manage
    Purpose     = "k3s-single-node-cluster"
  })
}

