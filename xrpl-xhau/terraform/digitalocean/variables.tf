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

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "do_region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"

  validation {
    condition     = contains(["nyc1", "nyc3", "sfo2", "sfo3", "ams3", "sgp1", "lon1", "fra1", "tor1", "blr1"], var.do_region)
    error_message = "Region must be a valid DigitalOcean region."
  }
}

# ============================================================================
# Network Variables
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

# ============================================================================
# Droplet Variables
# ============================================================================

variable "validator_size" {
  description = "Droplet size for validator node"
  type        = string
  default     = "s-4vcpu-8gb" # Standard droplet - no tier restriction

  validation {
    condition     = contains(["s-2vcpu-4gb", "s-4vcpu-8gb", "s-8vcpu-16gb", "m-2vcpu-16gb", "m-4vcpu-32gb", "m-8vcpu-64gb"], var.validator_size)
    error_message = "Choose a valid droplet size. Standard (s-series) or memory-optimized (m-series if account allows)."
  }
}

variable "monitoring_size" {
  description = "Droplet size for monitoring stack"
  type        = string
  default     = "s-2vcpu-4gb"
}



variable "root_password" {
  description = "Root password for SSH access to droplets"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access to droplet"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================================================
# Storage Variables
# ============================================================================

variable "ledger_volume_size" {
  description = "Size of block storage volume for ledger (GB)"
  type        = number
  default     = 100 # Reduced for standard accounts (increase to 500GB for production)

  validation {
    condition     = var.ledger_volume_size >= 50
    error_message = "Ledger volume should be at least 50GB (500GB recommended for production)."
  }
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
  type        = list(string)
  default     = []
}
