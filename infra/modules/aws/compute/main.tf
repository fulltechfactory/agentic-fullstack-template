# =============================================================================
# AWS Compute Module
# EC2 Instance for Keystone application
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the instance"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair name (optional if using SSM)"
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 30
}

variable "postgres_volume_id" {
  description = "EBS volume ID for PostgreSQL data"
  type        = string
}

variable "elastic_ip_allocation_id" {
  description = "Existing Elastic IP allocation ID (optional)"
  type        = string
  default     = null
}

variable "user_data" {
  description = "User data script for instance initialization"
  type        = string
  default     = ""
}

# Get latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = var.user_data != "" ? var.user_data : null

  tags = {
    Name        = "${var.project_name}-app"
    Environment = var.environment
    ManagedBy   = "opentofu"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# Attach PostgreSQL data volume
resource "aws_volume_attachment" "postgres_data" {
  device_name = "/dev/sdf"
  volume_id   = var.postgres_volume_id
  instance_id = aws_instance.app.id

  # Prevent destruction while attached
  skip_destroy = true
}

# Elastic IP - create new if not provided
resource "aws_eip" "app" {
  count  = var.elastic_ip_allocation_id == null ? 1 : 0
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-eip"
    Environment = var.environment
    ManagedBy   = "opentofu"
  }
}

# Associate Elastic IP (new or existing)
resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = var.elastic_ip_allocation_id != null ? var.elastic_ip_allocation_id : aws_eip.app[0].id
}

# Outputs
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "instance_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.app.private_ip
}

output "instance_public_ip" {
  description = "EC2 instance public IP (Elastic IP)"
  value       = var.elastic_ip_allocation_id != null ? aws_eip_association.app.public_ip : aws_eip.app[0].public_ip
}

output "elastic_ip_allocation_id" {
  description = "Elastic IP allocation ID"
  value       = var.elastic_ip_allocation_id != null ? var.elastic_ip_allocation_id : aws_eip.app[0].id
}
