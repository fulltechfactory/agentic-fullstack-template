# =============================================================================
# Azure Networking Module
# Virtual Network and Subnet
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

variable "vnet_cidr" {
  description = "CIDR block for the Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# =============================================================================
# Virtual Network
# =============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${var.project_name}-${var.environment}-vnet"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = [var.vnet_cidr]

  tags = {
    Name        = "${var.project_name}-${var.environment}-vnet"
    Environment = var.environment
    ManagedBy   = "opentofu"
  }
}

# =============================================================================
# Subnet
# =============================================================================

resource "azurerm_subnet" "main" {
  name                 = "${var.project_name}-${var.environment}-subnet"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_cidr]
}

# =============================================================================
# Outputs
# =============================================================================

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.main.name
}

output "subnet_id" {
  description = "Subnet ID"
  value       = azurerm_subnet.main.id
}

output "subnet_name" {
  description = "Subnet name"
  value       = azurerm_subnet.main.name
}
