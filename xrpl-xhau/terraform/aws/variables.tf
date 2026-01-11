# ============================================================================
# General Variables
# ============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "xrpl-validator"
}

variable "environment" {
  description = "Environment name (e.g., production, staging, testnet)"
  type        = string
  default     = "testnet"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

# ============================================================================
# Network Variables
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ============================================================================
# EC2 Variables
# ============================================================================

variable "validator_instance_type" {
  description = "EC2 instance type for validator node"
  type        = string
  default     = "r5.large"

  validation {
    condition     = contains(["r5.large", "r5.xlarge", "r5.2xlarge", "m5.xlarge"], var.validator_instance_type)
    error_message = "Validator requires memory-optimized instances. Use r5.large or larger."
  }
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for monitoring stack"
  type        = string
  default     = "t3.medium"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access to bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================================================
# Storage Variables
# ============================================================================

variable "ledger_volume_size" {
  description = "Size of EBS volume for ledger storage (GB)"
  type        = number
  default     = 500

  validation {
    condition     = var.ledger_volume_size >= 200
    error_message = "Ledger volume should be at least 200GB for validator operations."
  }
}

variable "ledger_volume_type" {
  description = "EBS volume type for ledger storage"
  type        = string
  default     = "gp3"
}

variable "ledger_volume_iops" {
  description = "IOPS for gp3 volume"
  type        = number
  default     = 3000
}

variable "ledger_volume_throughput" {
  description = "Throughput for gp3 volume (MB/s)"
  type        = number
  default     = 125
}

# ============================================================================
# XRPL/Xahau Configuration
# ============================================================================

variable "network_type" {
  description = "XRPL network type (mainnet, testnet, devnet, xahau)"
  type        = string
  default     = "testnet"

  validation {
    condition     = contains(["mainnet", "testnet", "devnet", "xahau", "xahau-testnet"], var.network_type)
    error_message = "Network type must be one of: mainnet, testnet, devnet, xahau, xahau-testnet."
  }
}

variable "validator_count" {
  description = "Number of validator nodes to deploy"
  type        = number
  default     = 1

  validation {
    condition     = var.validator_count >= 1 && var.validator_count <= 5
    error_message = "Validator count must be between 1 and 5."
  }
}

variable "unl_url" {
  description = "URL for the Unique Node List (UNL)"
  type        = string
  default     = "https://vl.xrplf.org"
}

# ============================================================================
# Monitoring Variables
# ============================================================================

variable "enable_monitoring" {
  description = "Enable monitoring stack deployment"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "changeme123!"
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

# ============================================================================
# Tags
# ============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
