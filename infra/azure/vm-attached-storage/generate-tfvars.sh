#!/bin/bash
# =============================================================================
# Generate terraform.tfvars from .deploy-config for Azure
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

# Format SSH CIDRs for Terraform
if [ -n "$SSH_ALLOWED_CIDRS" ]; then
    SSH_CIDRS_TF="[\"$SSH_ALLOWED_CIDRS\"]"
else
    SSH_CIDRS_TF="[]"
fi

# Generate tfvars
cat > "$TFVARS" << TFVARSEOF
# =============================================================================
# Auto-generated from .deploy-config
# Generated on: $(date)
# =============================================================================

# Azure Subscription
subscription_id = "$AZURE_SUBSCRIPTION_ID"

# Project
project_name = "keystone"
environment  = "$ENVIRONMENT"

# Azure Region
location = "$CLOUD_REGION"

# Domain
domain_name = "$DOMAIN_NAME"

# VM Size
vm_size = "Standard_D2s_v3"

# Admin
admin_username = "azureuser"

# PostgreSQL data volume size (GB)
postgres_volume_size = 20

# Permanent resources (created manually)
permanent_resource_group = "$AZURE_PERMANENT_RG"
public_ip_name           = "$AZURE_PUBLIC_IP_NAME"
storage_account_name     = "$AZURE_STORAGE_ACCOUNT"
storage_container_name   = "$AZURE_STORAGE_CONTAINER"

# SSH access (optional - leave empty to disable)
TFVARSEOF

# Add SSH key if provided
if [ -n "$SSH_PUBLIC_KEY" ]; then
    echo "ssh_public_key = \"$SSH_PUBLIC_KEY\"" >> "$TFVARS"
else
    echo "ssh_public_key = \"\"" >> "$TFVARS"
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
allowed_ssh_cidrs = $SSH_CIDRS_TF
TFVARSEOF

echo "[OK] Generated $TFVARS"
