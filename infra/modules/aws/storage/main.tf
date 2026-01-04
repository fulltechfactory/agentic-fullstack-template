# =============================================================================
# AWS Storage Module
# EBS Volume for PostgreSQL data
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "availability_zone" {
  description = "AWS availability zone"
  type        = string
}

variable "volume_size" {
  description = "EBS volume size in GB"
  type        = number
  default     = 20
}

variable "volume_type" {
  description = "EBS volume type"
  type        = string
  default     = "gp3"
}

variable "volume_iops" {
  description = "EBS volume IOPS (for gp3/io1/io2)"
  type        = number
  default     = 3000
}

variable "volume_throughput" {
  description = "EBS volume throughput in MB/s (for gp3)"
  type        = number
  default     = 125
}

variable "encrypted" {
  description = "Enable EBS encryption"
  type        = bool
  default     = true
}

# EBS Volume for PostgreSQL data
resource "aws_ebs_volume" "postgres_data" {
  availability_zone = var.availability_zone
  size              = var.volume_size
  type              = var.volume_type
  iops              = var.volume_type == "gp3" || var.volume_type == "io1" || var.volume_type == "io2" ? var.volume_iops : null
  throughput        = var.volume_type == "gp3" ? var.volume_throughput : null
  encrypted         = var.encrypted

  tags = {
    Name        = "${var.project_name}-postgres-data"
    Environment = var.environment
    ManagedBy   = "opentofu"
    Purpose     = "PostgreSQL data storage"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Outputs
output "postgres_volume_id" {
  description = "PostgreSQL data volume ID"
  value       = aws_ebs_volume.postgres_data.id
}

output "postgres_volume_arn" {
  description = "PostgreSQL data volume ARN"
  value       = aws_ebs_volume.postgres_data.arn
}

