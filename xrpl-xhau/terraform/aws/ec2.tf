# ============================================================================
# IAM Role for Validator EC2
# ============================================================================

resource "aws_iam_role" "validator" {
  name = "${var.project_name}-${var.environment}-validator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "validator" {
  name = "${var.project_name}-${var.environment}-validator-policy"
  role = aws_iam_role.validator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.validator_keys.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = ["${aws_cloudwatch_log_group.validator.arn}:*"]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "validator" {
  name = "${var.project_name}-${var.environment}-validator-profile"
  role = aws_iam_role.validator.name
}

# ============================================================================
# Validator Node
# ============================================================================

resource "aws_instance" "validator" {
  count = var.validator_count

  ami                  = data.aws_ami.ubuntu.id
  instance_type        = var.validator_instance_type
  key_name             = aws_key_pair.validator.key_name
  subnet_id            = aws_subnet.private[count.index % length(aws_subnet.private)].id
  iam_instance_profile = aws_iam_instance_profile.validator.name

  vpc_security_group_ids = [aws_security_group.validator.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/validator-userdata.sh.tpl", {
    network_type = var.network_type
    region       = var.aws_region
    secret_arn   = aws_secretsmanager_secret.validator_keys.arn
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-validator-${count.index + 1}"
    Role = "validator"
  }
}

# ============================================================================
# EBS Volume for Ledger Storage
# ============================================================================

resource "aws_ebs_volume" "ledger" {
  count = var.validator_count

  availability_zone = aws_instance.validator[count.index].availability_zone
  size              = var.ledger_volume_size
  type              = var.ledger_volume_type
  iops              = var.ledger_volume_type == "gp3" ? var.ledger_volume_iops : null
  throughput        = var.ledger_volume_type == "gp3" ? var.ledger_volume_throughput : null
  encrypted         = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ledger-${count.index + 1}"
    Role = "ledger-storage"
  }
}

resource "aws_volume_attachment" "ledger" {
  count = var.validator_count

  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.ledger[count.index].id
  instance_id = aws_instance.validator[count.index].id
}

# ============================================================================
# Monitoring Instance
# ============================================================================

resource "aws_instance" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.monitoring_instance_type
  key_name      = aws_key_pair.validator.key_name
  subnet_id     = aws_subnet.private[0].id

  vpc_security_group_ids = [aws_security_group.monitoring.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io docker-compose
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    echo "Monitoring host ready" > /var/log/monitoring-ready.log
  EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-monitoring"
    Role = "monitoring"
  }
}
