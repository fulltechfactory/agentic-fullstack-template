# =============================================================================
# Keystone - AWS VM with Attached Storage
# Single EC2 instance with PostgreSQL, Backend, Keycloak, Frontend
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to use S3 backend for state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "keystone/prod/terraform.tfstate"
  #   region         = "eu-west-3"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "opentofu"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "keystone"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "availability_zone" {
  description = "AWS availability zone"
  type        = string
  default     = "eu-west-3a"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name (optional, use SSM instead)"
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH (empty = no SSH, use SSM)"
  type        = list(string)
  default     = []
}

variable "postgres_volume_size" {
  description = "PostgreSQL data volume size in GB"
  type        = number
  default     = 20
}

variable "elastic_ip_allocation_id" {
  description = "Existing Elastic IP allocation ID (optional)"
  type        = string
  default     = null
}

# Database credentials
variable "postgres_password" {
  description = "PostgreSQL superuser password"
  type        = string
  sensitive   = true
}

variable "db_app_password" {
  description = "Application database user password"
  type        = string
  sensitive   = true
}

variable "db_migration_password" {
  description = "Migration user password"
  type        = string
  sensitive   = true
}

variable "db_keycloak_password" {
  description = "Keycloak database user password"
  type        = string
  sensitive   = true
}

# Application credentials
variable "keystone_admin_password" {
  description = "Keystone admin user password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

# AI Provider
variable "ai_provider" {
  description = "AI provider (openai, anthropic, gemini, mistral)"
  type        = string
  default     = "openai"
}

variable "ai_api_key" {
  description = "AI provider API key"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Modules
# =============================================================================

module "networking" {
  source = "../../modules/aws/networking"

  project_name      = var.project_name
  environment       = var.environment
  availability_zone = var.availability_zone
}

module "security" {
  source = "../../modules/aws/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "storage" {
  source = "../../modules/aws/storage"

  project_name      = var.project_name
  environment       = var.environment
  availability_zone = var.availability_zone
  volume_size       = var.postgres_volume_size
}

module "compute" {
  source = "../../modules/aws/compute"

  project_name             = var.project_name
  environment              = var.environment
  subnet_id                = module.networking.public_subnet_id
  security_group_ids       = [module.security.app_security_group_id]
  instance_profile_name    = module.security.ec2_instance_profile_name
  instance_type            = var.instance_type
  key_name                 = var.key_name
  postgres_volume_id       = module.storage.postgres_volume_id
  elastic_ip_allocation_id = var.elastic_ip_allocation_id
  user_data                = base64encode(local.user_data_script)
}

# =============================================================================
# User Data Script
# =============================================================================

locals {
  user_data_script = <<-USERDATA
#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting Keystone setup ==="

# Wait for cloud-init to finish
cloud-init status --wait

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

# Install additional tools
apt-get install -y git make jq nvme-cli

# Format and mount PostgreSQL data volume
echo "=== Setting up PostgreSQL data volume ==="
DATA_DEVICE="/dev/nvme1n1"

# Wait for volume to attach
while [ ! -e $DATA_DEVICE ]; do
  echo "Waiting for data volume..."
  sleep 5
done

# Check if already formatted
if ! blkid $DATA_DEVICE; then
  echo "Formatting data volume..."
  mkfs.ext4 $DATA_DEVICE
fi

# Create mount point and mount
mkdir -p /data/postgres
mount $DATA_DEVICE /data/postgres

# Add to fstab for persistence
if ! grep -q "$DATA_DEVICE" /etc/fstab; then
  echo "$DATA_DEVICE /data/postgres ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# Set permissions
chown -R 999:999 /data/postgres

# Clone Keystone
echo "=== Cloning Keystone ==="
cd /opt
git clone https://github.com/fulltechfactory/keystone.git
cd keystone

# Create production config
cat > .deploy-config << 'DEPLOYCONFIG'
ENVIRONMENT=prod
CLOUD_PROVIDER=aws
DOMAIN_NAME=${var.domain_name}

AI_PROVIDER=${var.ai_provider}
${var.ai_provider == "openai" ? "OPENAI_API_KEY=${var.ai_api_key}" : ""}
${var.ai_provider == "anthropic" ? "ANTHROPIC_API_KEY=${var.ai_api_key}" : ""}
${var.ai_provider == "gemini" ? "GOOGLE_API_KEY=${var.ai_api_key}" : ""}
${var.ai_provider == "mistral" ? "MISTRAL_API_KEY=${var.ai_api_key}" : ""}

POSTGRES_PASSWORD=${var.postgres_password}
DB_APP_HOST=postgres
DB_APP_PORT=5432
DB_APP_NAME=keystone_db
DB_APP_SCHEMA=app
DB_APP_USER=appuser
DB_APP_PASSWORD=${var.db_app_password}

DB_MIGRATION_USER=migration
DB_MIGRATION_PASSWORD=${var.db_migration_password}

DB_KEYCLOAK_HOST=postgres
DB_KEYCLOAK_PORT=5432
DB_KEYCLOAK_NAME=keystone_db
DB_KEYCLOAK_SCHEMA=keycloak
DB_KEYCLOAK_USER=keycloak
DB_KEYCLOAK_PASSWORD=${var.db_keycloak_password}

KEYSTONE_ADMIN=adminuser
KEYSTONE_ADMIN_PASSWORD=${var.keystone_admin_password}

KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=${var.keycloak_admin_password}
DEPLOYCONFIG

echo "=== Keystone setup complete ==="
echo "Run 'cd /opt/keystone && docker compose up -d' to start the application"
USERDATA
}

# =============================================================================
# Outputs
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = module.compute.instance_id
}

output "public_ip" {
  description = "Public IP address (Elastic IP)"
  value       = module.compute.instance_public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = module.compute.instance_private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "security_group_id" {
  description = "Security group ID"
  value       = module.security.app_security_group_id
}

output "postgres_volume_id" {
  description = "PostgreSQL data volume ID"
  value       = module.storage.postgres_volume_id
}

output "ssh_command" {
  description = "SSH command (if key_name provided)"
  value       = var.key_name != null ? "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.compute.instance_public_ip}" : "Use AWS SSM Session Manager"
}

output "ssm_command" {
  description = "AWS SSM Session Manager command"
  value       = "aws ssm start-session --target ${module.compute.instance_id} --region ${var.aws_region}"
}

output "application_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}
