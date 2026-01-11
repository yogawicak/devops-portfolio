# ============================================================================
# Validator Firewall
# ============================================================================

resource "digitalocean_firewall" "validator" {
  name = "${var.project_name}-${var.environment}-validator-fw"

  droplet_ids = digitalocean_droplet.validator[*].id

  # SSH from allowed CIDRs (direct access, no bastion needed)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidrs
  }

  # XRPL Peer Protocol (public)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "51235"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "51235"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Admin RPC from VPC only
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6006"
    source_addresses = [var.vpc_cidr]
  }

  # Prometheus metrics from monitoring
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = [var.vpc_cidr]
  }

  # Node exporter from monitoring
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9100"
    source_addresses = [var.vpc_cidr]
  }

  # Allow all outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ============================================================================
# Monitoring Firewall
# ============================================================================

resource "digitalocean_firewall" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  name = "${var.project_name}-${var.environment}-monitoring-fw"

  droplet_ids = [digitalocean_droplet.monitoring[0].id]

  # SSH from allowed CIDRs (direct access, no bastion needed)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidrs
  }

  # Grafana from VPC
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = [var.vpc_cidr]
  }

  # Prometheus from VPC
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = [var.vpc_cidr]
  }

  # Loki from VPC
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3100"
    source_addresses = [var.vpc_cidr]
  }

  # Alertmanager from VPC
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9093"
    source_addresses = [var.vpc_cidr]
  }

  # Allow all outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
