# =============================================================================
# Azure VM with Attached Storage - Main Configuration
# Equivalent to AWS vm-attached-storage deployment
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
  subscription_id = var.subscription_id
}

# =============================================================================
# Variables
# =============================================================================

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

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

variable "location" {
  description = "Azure region"
  type        = string
  default     = "francecentral"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "postgres_volume_size" {
  description = "PostgreSQL data disk size in GB"
  type        = number
  default     = 20
}

# Permanent resources (created manually)
variable "permanent_resource_group" {
  description = "Resource group for permanent resources (Public IP, Storage Account)"
  type        = string
}

variable "public_ip_name" {
  description = "Name of the pre-created Public IP"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the pre-created Storage Account for Caddy certificates"
  type        = string
}

variable "storage_container_name" {
  description = "Name of the container in the Storage Account"
  type        = string
  default     = "caddy"
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
variable "keystone_admin" {
  description = "Keystone admin username"
  type        = string
  default     = "adminuser"
}

variable "keystone_admin_password" {
  description = "Keystone admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_admin_password" {
  description = "Keycloak admin console password"
  type        = string
  sensitive   = true
}

# AI Provider
variable "ai_provider" {
  description = "AI provider (openai, anthropic, gemini, mistral)"
  type        = string
}

variable "ai_api_key" {
  description = "AI provider API key"
  type        = string
  sensitive   = true
}

# Auth
variable "auth_secret" {
  description = "NextAuth secret"
  type        = string
  sensitive   = true
}

# SSH access (optional)
variable "allowed_ssh_cidrs" {
  description = "List of CIDRs allowed to SSH (empty = no SSH access)"
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "SSH public key for VM access (optional)"
  type        = string
  default     = ""
}

# =============================================================================
# Data Sources - Reference permanent resources
# =============================================================================

data "azurerm_public_ip" "permanent" {
  name                = var.public_ip_name
  resource_group_name = var.permanent_resource_group
}

data "azurerm_storage_account" "caddy" {
  name                = var.storage_account_name
  resource_group_name = var.permanent_resource_group
}

# =============================================================================
# Resource Group for infrastructure (can be destroyed/recreated)
# =============================================================================

resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "opentofu"
  }
}

# =============================================================================
# Networking Module
# =============================================================================

module "networking" {
  source = "../../modules/azure/networking"

  project_name   = var.project_name
  environment    = var.environment
  location       = var.location
  resource_group = azurerm_resource_group.main.name
}

# =============================================================================
# Security Module
# =============================================================================

module "security" {
  source = "../../modules/azure/security"

  project_name      = var.project_name
  environment       = var.environment
  location          = var.location
  resource_group    = azurerm_resource_group.main.name
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

# =============================================================================
# Storage Module
# =============================================================================

module "storage" {
  source = "../../modules/azure/storage"

  project_name   = var.project_name
  environment    = var.environment
  location       = var.location
  resource_group = azurerm_resource_group.main.name
  volume_size    = var.postgres_volume_size
}

# =============================================================================
# Compute Module
# =============================================================================

module "compute" {
  source = "../../modules/azure/compute"

  project_name   = var.project_name
  environment    = var.environment
  location       = var.location
  resource_group = azurerm_resource_group.main.name

  vm_size        = var.vm_size
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key

  subnet_id                = module.networking.subnet_id
  network_security_group_id = module.security.nsg_id
  public_ip_id             = data.azurerm_public_ip.permanent.id
  data_disk_id             = module.storage.data_disk_id

  # Storage account access for Caddy certificates
  storage_account_name = var.storage_account_name
  storage_account_id   = data.azurerm_storage_account.caddy.id

  # User data template variables
  user_data_vars = {
    domain_name            = var.domain_name
    postgres_password      = var.postgres_password
    db_app_password        = var.db_app_password
    db_migration_password  = var.db_migration_password
    db_keycloak_password   = var.db_keycloak_password
    keystone_admin         = var.keystone_admin
    keystone_admin_password = var.keystone_admin_password
    keycloak_admin_password = var.keycloak_admin_password
    ai_provider            = var.ai_provider
    ai_api_key             = var.ai_api_key
    auth_secret            = var.auth_secret
    storage_account_name   = var.storage_account_name
    storage_container_name = var.storage_container_name
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "vm_id" {
  description = "Virtual Machine ID"
  value       = module.compute.vm_id
}

output "vm_name" {
  description = "Virtual Machine name"
  value       = module.compute.vm_name
}

output "public_ip" {
  description = "Public IP address"
  value       = data.azurerm_public_ip.permanent.ip_address
}

output "domain_name" {
  description = "Application domain"
  value       = var.domain_name
}

output "application_url" {
  description = "Application URL"
  value       = "https://${var.domain_name}"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = var.ssh_public_key != "" ? "ssh ${var.admin_username}@${data.azurerm_public_ip.permanent.ip_address}" : "SSH disabled - use Azure Serial Console"
}

output "generated_ssh_private_key" {
  description = "Generated SSH private key"
  value       = module.compute.generated_ssh_private_key
  sensitive   = true
}

output "generated_ssh_private_key" {
  description = "Generated SSH private key (only if no key was provided)"
  value       = module.compute.generated_ssh_private_key
  sensitive   = true
}
