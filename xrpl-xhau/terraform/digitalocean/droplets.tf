# ============================================================================
# Note: No bastion host needed for DigitalOcean
# All droplets have public IPs - use firewall rules to control SSH access
# ============================================================================

# ============================================================================
# Validator Droplets
# ============================================================================

resource "digitalocean_droplet" "validator" {
  count = var.validator_count

  name     = "${var.project_name}-${var.environment}-validator-${count.index + 1}"
  region   = var.do_region
  size     = var.validator_size
  image    = "ubuntu-24-04-x64"
  vpc_uuid = digitalocean_vpc.main.id

  user_data = templatefile("${path.module}/templates/validator-userdata.sh.tpl", {
    network_type  = var.network_type
    region        = var.do_region
    root_password = var.root_password
  })

  tags = concat(
    ["${var.project_name}", "${var.environment}", "validator"],
    var.additional_tags
  )
}

