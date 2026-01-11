# ============================================================================
# Validator Firewall
# ============================================================================

resource "digitalocean_firewall" "validator" {
  name = "${var.project_name}-${var.environment}-validator-fw"

  droplet_ids = digitalocean_droplet.validator[*].id

  # SSH from allowed CIDRs 
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_cidrs
  }

  # ICMP from allowed CIDRs 
  inbound_rule {
    protocol         = "icmp"
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
