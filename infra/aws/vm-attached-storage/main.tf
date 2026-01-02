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

module "storage" {
  source = "../../modules/aws/storage"

  project_name      = var.project_name
  environment       = var.environment
  availability_zone = var.availability_zone
  volume_size       = var.postgres_volume_size
}

module "security" {
  source = "../../modules/aws/security"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.networking.vpc_id
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  caddy_bucket_arn  = module.storage.caddy_bucket_arn
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
  user_data_script = templatefile("${path.module}/user-data.sh.tpl", {
    domain_name            = var.domain_name
    ai_provider            = var.ai_provider
    ai_api_key             = var.ai_api_key
    postgres_password      = var.postgres_password
    db_app_password        = var.db_app_password
    db_migration_password  = var.db_migration_password
    db_keycloak_password   = var.db_keycloak_password
    keystone_admin         = var.keystone_admin
    keystone_admin_password = var.keystone_admin_password
    keycloak_admin_password = var.keycloak_admin_password
    auth_secret            = var.auth_secret
    caddy_bucket_name      = module.storage.caddy_bucket_name
    aws_region             = var.aws_region
  })
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

variable "keystone_admin" {
  description = "Keystone admin username"
  type        = string
  default     = "adminuser"
}

variable "auth_secret" {
  description = "NextAuth secret (generate with: openssl rand -base64 32)"
  type        = string
  sensitive   = true
}

output "caddy_bucket_name" {
  description = "Caddy certificates S3 bucket name"
  value       = module.storage.caddy_bucket_name
}
