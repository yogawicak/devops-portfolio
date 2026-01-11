# ============================================================================
# VPC Outputs
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

# ============================================================================
# EC2 Outputs
# ============================================================================

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_public_dns" {
  description = "Public DNS of the bastion host"
  value       = aws_instance.bastion.public_dns
}

output "validator_private_ips" {
  description = "Private IPs of validator nodes"
  value       = aws_instance.validator[*].private_ip
}

output "validator_instance_ids" {
  description = "Instance IDs of validator nodes"
  value       = aws_instance.validator[*].id
}

output "monitoring_private_ip" {
  description = "Private IP of monitoring instance"
  value       = var.enable_monitoring ? aws_instance.monitoring[0].private_ip : null
}

# ============================================================================
# Security Group Outputs
# ============================================================================

output "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  value       = aws_security_group.bastion.id
}

output "validator_security_group_id" {
  description = "Security group ID for validator nodes"
  value       = aws_security_group.validator.id
}

output "monitoring_security_group_id" {
  description = "Security group ID for monitoring stack"
  value       = aws_security_group.monitoring.id
}

# ============================================================================
# Secret Outputs
# ============================================================================

output "validator_keys_secret_arn" {
  description = "ARN of the Secrets Manager secret for validator keys"
  value       = aws_secretsmanager_secret.validator_keys.arn
  sensitive   = true
}

# ============================================================================
# SSH Connection Commands
# ============================================================================

output "ssh_bastion_command" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -i your-key.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_validator_command" {
  description = "SSH command to connect to validator through bastion"
  value       = "ssh -i your-key.pem -o ProxyCommand='ssh -i your-key.pem -W %h:%p ubuntu@${aws_instance.bastion.public_ip}' ubuntu@${aws_instance.validator[0].private_ip}"
}
