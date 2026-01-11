# ============================================================================
# VPC Outputs
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = digitalocean_vpc.main.id
}

output "vpc_urn" {
  description = "URN of the VPC"
  value       = digitalocean_vpc.main.urn
}

# ============================================================================
# Droplet Outputs
# ============================================================================

output "validator_private_ips" {
  description = "Private IPs of validator droplets"
  value       = digitalocean_droplet.validator[*].ipv4_address_private
}

output "validator_public_ips" {
  description = "Public IPs of validator droplets"
  value       = digitalocean_droplet.validator[*].ipv4_address
}

output "validator_droplet_ids" {
  description = "IDs of validator droplets"
  value       = digitalocean_droplet.validator[*].id
}

# Project Output
# ============================================================================

output "project_id" {
  description = "ID of the DigitalOcean project"
  value       = digitalocean_project.validator.id
}

# ============================================================================
# Billing Estimates (Approximate)
# ============================================================================

output "billing_estimate_hourly" {
  description = "Approximate total hourly cost in USD"
  value       = format("$%.4f", local.total_hourly_cost)
}

output "available_sizes" {
  value = keys(local.sizes)
}
