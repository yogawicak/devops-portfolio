# AWS Provider Configuration
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "xrpl-terraform-state"
    key            = "validator/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "XRPL-Validator"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH Key Pair
resource "aws_key_pair" "validator" {
  key_name   = "${var.project_name}-${var.environment}-key"
  public_key = var.ssh_public_key
}

# Secrets Manager for validator keys
resource "aws_secretsmanager_secret" "validator_keys" {
  name        = "${var.project_name}-${var.environment}-validator-keys"
  description = "XRPL/Xahau validator keys"

  tags = {
    Name = "${var.project_name}-validator-keys"
  }
}

# CloudWatch Log Group for validator logs
resource "aws_cloudwatch_log_group" "validator" {
  name              = "/xrpl/${var.environment}/validator"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-logs"
  }
}
