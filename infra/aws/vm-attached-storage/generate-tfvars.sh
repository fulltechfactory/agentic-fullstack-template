#!/bin/bash
# =============================================================================
# Generate terraform.tfvars from .deploy-config
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEPLOY_CONFIG="$PROJECT_ROOT/.deploy-config"
TFVARS="$SCRIPT_DIR/terraform.tfvars"

if [ ! -f "$DEPLOY_CONFIG" ]; then
    echo "[ERROR] .deploy-config not found. Run 'make setup-deploy' first."
    exit 1
fi

# Source the config
source "$DEPLOY_CONFIG"

# Determine AI key variable name
case $AI_PROVIDER in
    openai)    AI_KEY_VAR="OPENAI_API_KEY" ;;
    anthropic) AI_KEY_VAR="ANTHROPIC_API_KEY" ;;
    gemini)    AI_KEY_VAR="GOOGLE_API_KEY" ;;
    mistral)   AI_KEY_VAR="MISTRAL_API_KEY" ;;
    *)         AI_KEY_VAR="" ;;
esac

# Get AI API key
AI_API_KEY_VALUE=""
if [ -n "$AI_KEY_VAR" ]; then
    AI_API_KEY_VALUE="${!AI_KEY_VAR}"
fi

# Generate auth secret if not present
AUTH_SECRET=$(openssl rand -base64 32)

# Generate tfvars
cat > "$TFVARS" << TFVARSEOF
# =============================================================================
# Auto-generated from .deploy-config
# Generated on: $(date)
# =============================================================================

# Project
project_name = "keystone"
environment  = "$ENVIRONMENT"

# AWS Region
aws_region        = "$CLOUD_REGION"
availability_zone = "${CLOUD_REGION}a"

# Domain
domain_name = "$DOMAIN_NAME"

# Instance
instance_type = "t3.large"

# SSH (using SSM by default)
key_name          = null
allowed_ssh_cidrs = []

# PostgreSQL data volume size (GB)
postgres_volume_size = 20

# Elastic IP
TFVARSEOF

if [ -n "$ELASTIC_IP_ALLOC_ID" ]; then
    echo "elastic_ip_allocation_id = \"$ELASTIC_IP_ALLOC_ID\"" >> "$TFVARS"
else
    echo "elastic_ip_allocation_id = null" >> "$TFVARS"
fi

cat >> "$TFVARS" << TFVARSEOF

# Database Credentials
postgres_password     = "$POSTGRES_PASSWORD"
db_app_password       = "$DB_APP_PASSWORD"
db_migration_password = "$DB_MIGRATION_PASSWORD"
db_keycloak_password  = "$DB_KEYCLOAK_PASSWORD"

# Application Credentials
keystone_admin          = "$KEYSTONE_ADMIN"
keystone_admin_password = "$KEYSTONE_ADMIN_PASSWORD"
keycloak_admin_password = "$KEYCLOAK_ADMIN_PASSWORD"

# AI Provider
ai_provider = "$AI_PROVIDER"
ai_api_key  = "$AI_API_KEY_VALUE"

# Auth
auth_secret = "$AUTH_SECRET"

# Caddy S3 bucket (created manually)
caddy_bucket_name = "$CADDY_BUCKET_NAME"
TFVARSEOF

echo "[OK] Generated $TFVARS"
