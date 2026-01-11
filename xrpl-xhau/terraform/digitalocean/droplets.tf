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
  ssh_keys = [digitalocean_ssh_key.validator.fingerprint]

  user_data = templatefile("${path.module}/templates/validator-userdata.sh.tpl", {
    network_type = var.network_type
    region       = var.do_region
  })

  tags = concat(
    ["${var.project_name}", "${var.environment}", "validator"],
    var.additional_tags
  )
}

# ============================================================================
# Block Storage for Ledger
# ============================================================================

resource "digitalocean_volume" "ledger" {
  count = var.validator_count

  name                    = "${var.project_name}-${var.environment}-ledger-${count.index + 1}"
  region                  = var.do_region
  size                    = var.ledger_volume_size
  initial_filesystem_type = "xfs"
  description             = "XRPL ledger storage for validator ${count.index + 1}"

  tags = ["${var.project_name}", "${var.environment}", "ledger-storage"]
}

resource "digitalocean_volume_attachment" "ledger" {
  count = var.validator_count

  droplet_id = digitalocean_droplet.validator[count.index].id
  volume_id  = digitalocean_volume.ledger[count.index].id
}

# ============================================================================
# Monitoring Droplet
# ============================================================================

resource "digitalocean_droplet" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  name     = "${var.project_name}-${var.environment}-monitoring"
  region   = var.do_region
  size     = var.monitoring_size
  image    = "ubuntu-24-04-x64"
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [digitalocean_ssh_key.validator.fingerprint]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io docker-compose
    systemctl enable docker
    systemctl start docker
    usermod -aG docker root
    echo "Monitoring host ready" > /var/log/monitoring-ready.log
  EOF

  tags = concat(
    ["${var.project_name}", "${var.environment}", "monitoring"],
    var.additional_tags
  )
}

