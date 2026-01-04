# =============================================================================
# Azure Compute Module
# Virtual Machine with Managed Identity
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

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key (optional)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID for the NIC"
  type        = string
}

variable "network_security_group_id" {
  description = "NSG ID to associate with NIC"
  type        = string
}

variable "public_ip_id" {
  description = "Public IP ID to associate"
  type        = string
}

variable "data_disk_id" {
  description = "Data disk ID to attach"
  type        = string
}

variable "storage_account_name" {
  description = "Storage Account name for Caddy certificates"
  type        = string
}

variable "storage_account_id" {
  description = "Storage Account ID for role assignment"
  type        = string
}

variable "user_data_vars" {
  description = "Variables for user data template"
  type        = map(string)
}

# =============================================================================
# Network Interface
# =============================================================================

resource "azurerm_network_interface" "main" {
  name                = "${var.project_name}-${var.environment}-nic"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-nic"
    Environment = var.environment
    ManagedBy   = "opentofu"
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = var.network_security_group_id
}

# =============================================================================
# Virtual Machine
# =============================================================================

resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.project_name}-${var.environment}-vm"
  location            = var.location
  resource_group_name = var.resource_group
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [azurerm_network_interface.main.id]

  # Use SSH key if provided, otherwise generate one
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  }

  os_disk {
    name                 = "${var.project_name}-${var.environment}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # System-assigned Managed Identity for Blob Storage access
  identity {
    type = "SystemAssigned"
  }

  # Custom data (cloud-init)
  custom_data = base64encode(templatefile("${path.module}/user-data.sh.tpl", var.user_data_vars))

  tags = {
    Name        = "${var.project_name}-${var.environment}-vm"
    Environment = var.environment
    ManagedBy   = "opentofu"
  }
}

# =============================================================================
# SSH Key (generated if not provided)
# =============================================================================

resource "tls_private_key" "ssh" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# =============================================================================
# Attach Data Disk
# =============================================================================

resource "azurerm_virtual_machine_data_disk_attachment" "postgres" {
  managed_disk_id    = var.data_disk_id
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  lun                = 0
  caching            = "ReadWrite"
}

# =============================================================================
# Role Assignment - Allow VM to access Blob Storage
# =============================================================================

resource "azurerm_role_assignment" "blob_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

# =============================================================================
# Outputs
# =============================================================================

output "vm_id" {
  description = "Virtual Machine ID"
  value       = azurerm_linux_virtual_machine.main.id
}

output "vm_name" {
  description = "Virtual Machine name"
  value       = azurerm_linux_virtual_machine.main.name
}

output "vm_private_ip" {
  description = "Private IP address"
  value       = azurerm_network_interface.main.private_ip_address
}

output "vm_identity_principal_id" {
  description = "Managed Identity Principal ID"
  value       = azurerm_linux_virtual_machine.main.identity[0].principal_id
}

output "generated_ssh_private_key" {
  description = "Generated SSH private key (only if no key was provided)"
  value       = var.ssh_public_key == "" ? tls_private_key.ssh[0].private_key_pem : ""
  sensitive   = true
}
