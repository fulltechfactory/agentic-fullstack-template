# =============================================================================
# Azure Storage Module
# Managed Disk for PostgreSQL data
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group" {
  description = "Resource group name"
  type        = string
}

variable "volume_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Storage account type"
  type        = string
  default     = "StandardSSD_LRS"
}

# =============================================================================
# Managed Disk for PostgreSQL data
# =============================================================================

resource "azurerm_managed_disk" "postgres_data" {
  name                = "${var.project_name}-${var.environment}-postgres-data"
  location            = var.location
  resource_group_name = var.resource_group

  storage_account_type = var.storage_type
  create_option        = "Empty"
  disk_size_gb         = var.volume_size

  tags = {
    Name        = "${var.project_name}-postgres-data"
    Environment = var.environment
    ManagedBy   = "opentofu"
    Purpose     = "PostgreSQL data storage"
  }

  lifecycle {
    prevent_destroy = false  # Set to true in production after initial setup
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "data_disk_id" {
  description = "PostgreSQL data disk ID"
  value       = azurerm_managed_disk.postgres_data.id
}

output "data_disk_name" {
  description = "PostgreSQL data disk name"
  value       = azurerm_managed_disk.postgres_data.name
}
