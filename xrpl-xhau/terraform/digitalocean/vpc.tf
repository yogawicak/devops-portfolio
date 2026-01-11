# ============================================================================
# VPC
# ============================================================================

resource "digitalocean_vpc" "main" {
  name        = "${var.project_name}-${var.environment}-vpc"
  region      = var.do_region
  ip_range    = var.vpc_cidr
  description = "VPC for XRPL/Xahau validator infrastructure"
}
