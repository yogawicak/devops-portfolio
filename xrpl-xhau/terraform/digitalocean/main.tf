# DigitalOcean Provider Configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.30"
    }
  }

  # backend "s3" {
  #   # DigitalOcean Spaces is S3-compatible
  #   endpoint                    = "https://nyc3.digitaloceanspaces.com"
  #   bucket                      = "xrpl-terraform-state"
  #   key                         = "digitalocean/validator/terraform.tfstate"
  #   region                      = "us-east-1" # Required but ignored for Spaces
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  # }
}

provider "digitalocean" {
  token = var.do_token
}

# Password Authentication
# Using root password authentication instead of SSH keys
# Password will be set via user_data script during droplet creation

# Project for organization
resource "digitalocean_project" "validator" {
  name        = "${var.project_name}-${var.environment}"
  description = "XRPL/Xahau Validator Infrastructure"
  purpose     = "Service or API"
  environment = var.environment == "production" ? "Production" : "Development"

  resources = [for droplet in digitalocean_droplet.validator : droplet.urn]
}

# ============================================================================
# Cost Estimation
# ============================================================================

data "digitalocean_sizes" "main" {}

locals {
  # Convert sizes list to a map for easy lookup
  sizes = { for s in data.digitalocean_sizes.main.sizes : s.slug => s }

  # Droplet costs
  validator_hourly  = try(local.sizes[var.validator_size].price_hourly, 0)
  monitoring_hourly = var.enable_monitoring ? try(local.sizes[var.monitoring_size].price_hourly, 0) : 0

  # Volume costs ($0.10/GB per month. Hourly using 672h monthly standard)
  volume_price_monthly_per_gb = 0.10
  volume_hourly_per_gb        = local.volume_price_monthly_per_gb / 672
  total_volume_hourly         = var.ledger_volume_size * var.validator_count * local.volume_hourly_per_gb

  # Reserved IP is free when assigned, so we assume $0 here

  total_hourly_cost = (local.validator_hourly * var.validator_count) + local.monitoring_hourly + local.total_volume_hourly
}
