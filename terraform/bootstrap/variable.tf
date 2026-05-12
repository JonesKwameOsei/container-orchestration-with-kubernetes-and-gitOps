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

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, stating, prod."
  }
}

variable "global_bool" {
  description = "Set true as a global selector"
  type        = bool
  default     = true
}

variable "versioning_status" {
  description = "Status of S3 bucket versioning"
  type        = string
  default     = "Enabled"
}

variable "byte_length" {
  description = "Byte size length"
  type        = number
  default     = 4
}

variable "resource_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}