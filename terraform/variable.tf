# ── General ────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "Aws region where all resources will be provisioned"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project identidier used to name all resources consistently"
  type        = string
  default     = "datavault"
}

variable "manage" {
  description = "IaC tool used to provisioned all resources consistently"
  type        = string
  default     = "IaC-terraform"
}

variable "environment" {
  description = "Deployment environment. Controls naming and tagging."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stating, prod."
  }
}

variable "resource_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}

# ── Compute ────────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type for K3s node"
  type        = string
  default     = "t3.small"
}

variable "keypair_algor" {
  description = "EC2 keypair algorithm"
  type        = string
  default     = "RSA"
}

variable "keypair_bits" {
  description = "EC2 keypair bits"
  type        = number
  default     = 4096
}

variable "allowed_ssh_cidr" {
  description = "CIDR block permitted to SSH into the EC2 instance. Use your IP, not 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block (e.g. 203.0.113.5/32)."
  }
}

variable "ec2_volume_size" {
  description = "The size of the volume attached to EC2 instance"
  type        = number
  default     = 20
}

variable "ec2_volume_type" {
  description = "The type of the volume attached to EC2 instance"
  type        = string
  default     = "gp3"
}

variable "hostname" {
  description = "Set custom hostname for EC2"
  type = string
  default = "datavault-k3s-node"
}



# ── ECR ────────────────────────────────────────────────────────────────

variable "immutability" {
  description = "Image tag immutability"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.immutability)
    error_message = "immutability must be MUTABLE or IMMUTABLE."
  }
}

# ── User Details ────────────────────────────────────────────────────────────────

variable "user_name" {
  description = "The user creating this infrastructure"
  type        = string
  default     = "terraform"
}

variable "user_department" {
  description = "The organization the user belongs to: dev, prod, qa"
  type        = string
  default     = "Platform team"
}
