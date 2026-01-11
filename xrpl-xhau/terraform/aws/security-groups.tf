# ============================================================================
# Bastion Host Security Group
# ============================================================================

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion-sg"
  }
}

# ============================================================================
# Validator Security Group
# ============================================================================

resource "aws_security_group" "validator" {
  name        = "${var.project_name}-${var.environment}-validator-sg"
  description = "Security group for XRPL/Xahau validator nodes"
  vpc_id      = aws_vpc.main.id

  # SSH from bastion only
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # XRPL Peer Protocol (public for peer discovery)
  ingress {
    description = "XRPL peer protocol TCP"
    from_port   = 51235
    to_port     = 51235
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "XRPL peer protocol UDP"
    from_port   = 51235
    to_port     = 51235
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Admin RPC (internal only)
  ingress {
    description = "Admin RPC from VPC"
    from_port   = 6006
    to_port     = 6006
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Prometheus metrics (internal only)
  ingress {
    description     = "Prometheus metrics from monitoring"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  # Node exporter (internal only)
  ingress {
    description     = "Node exporter from monitoring"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-validator-sg"
  }
}

# ============================================================================
# Monitoring Security Group
# ============================================================================

resource "aws_security_group" "monitoring" {
  name        = "${var.project_name}-${var.environment}-monitoring-sg"
  description = "Security group for monitoring stack"
  vpc_id      = aws_vpc.main.id

  # SSH from bastion only
  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Grafana (from VPC for now, can be exposed via ALB later)
  ingress {
    description = "Grafana from VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Prometheus (internal only)
  ingress {
    description = "Prometheus from VPC"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Loki (internal only)
  ingress {
    description = "Loki from VPC"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Alertmanager (internal only)
  ingress {
    description = "Alertmanager from VPC"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-monitoring-sg"
  }
}
