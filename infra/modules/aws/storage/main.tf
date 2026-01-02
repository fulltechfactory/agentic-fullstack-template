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

# =============================================================================
# S3 Bucket for Caddy certificates
# =============================================================================

variable "create_caddy_bucket" {
  description = "Create S3 bucket for Caddy certificates"
  type        = bool
  default     = true
}

resource "aws_s3_bucket" "caddy_certs" {
  count  = var.create_caddy_bucket ? 1 : 0
  bucket = "${var.project_name}-caddy-certs-${random_id.bucket_suffix[0].hex}"

  tags = {
    Name        = "${var.project_name}-caddy-certs"
    Environment = var.environment
    ManagedBy   = "opentofu"
    Purpose     = "Caddy SSL certificates storage"
  }
}

resource "random_id" "bucket_suffix" {
  count       = var.create_caddy_bucket ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "caddy_certs" {
  count  = var.create_caddy_bucket ? 1 : 0
  bucket = aws_s3_bucket.caddy_certs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "caddy_certs" {
  count  = var.create_caddy_bucket ? 1 : 0
  bucket = aws_s3_bucket.caddy_certs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "caddy_certs" {
  count  = var.create_caddy_bucket ? 1 : 0
  bucket = aws_s3_bucket.caddy_certs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "caddy_bucket_name" {
  description = "Caddy certificates S3 bucket name"
  value       = var.create_caddy_bucket ? aws_s3_bucket.caddy_certs[0].id : ""
}

output "caddy_bucket_arn" {
  description = "Caddy certificates S3 bucket ARN"
  value       = var.create_caddy_bucket ? aws_s3_bucket.caddy_certs[0].arn : ""
}
