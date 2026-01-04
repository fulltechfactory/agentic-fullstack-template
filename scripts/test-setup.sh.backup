#!/bin/bash

# ==============================================================================
# Test script for Makefile setup commands
# ==============================================================================

set -e

PASS=0
FAIL=0
TOTAL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_test() {
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "============================================================"
    echo "TEST $TOTAL: $1"
    echo "============================================================"
}

log_pass() {
    PASS=$((PASS + 1))
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    FAIL=$((FAIL + 1))
    echo -e "${RED}[FAIL]${NC} $1"
}

check_config_value() {
    local file=$1
    local key=$2
    local expected=$3
    local actual=$(grep "^$key=" "$file" 2>/dev/null | cut -d'=' -f2)
    
    if [ "$actual" = "$expected" ]; then
        log_pass "$key=$expected"
        return 0
    else
        log_fail "$key expected '$expected' but got '$actual'"
        return 1
    fi
}

cleanup() {
    rm -f .dev-config .staging-config .deploy-config
}

# ==============================================================================
# DEV TESTS
# ==============================================================================

log_test "setup-dev with OpenAI"
cleanup
make setup-dev AI_PROVIDER=openai AI_API_KEY=sk-test-key-123 > /dev/null 2>&1
check_config_value .dev-config "ENVIRONMENT" "dev"
check_config_value .dev-config "AI_PROVIDER" "openai"
check_config_value .dev-config "OPENAI_API_KEY" "sk-test-key-123"
check_config_value .dev-config "POSTGRES_PASSWORD" "postgres"
check_config_value .dev-config "DB_APP_HOST" "postgres"
check_config_value .dev-config "DB_APP_PORT" "5432"
check_config_value .dev-config "DB_APP_NAME" "keystone_db"
check_config_value .dev-config "DB_APP_SCHEMA" "app"
check_config_value .dev-config "DB_APP_USER" "appuser"
check_config_value .dev-config "DB_KEYCLOAK_HOST" "postgres"
check_config_value .dev-config "DB_KEYCLOAK_SCHEMA" "keycloak"
check_config_value .dev-config "KEYCLOAK_ADMIN" "admin"

log_test "setup-dev with Ollama (local)"
cleanup
make setup-dev AI_PROVIDER=ollama > /dev/null 2>&1
check_config_value .dev-config "AI_PROVIDER" "ollama"
check_config_value .dev-config "AI_URL" "http://localhost:11434"
check_config_value .dev-config "DB_APP_NAME" "keystone_db"

log_test "setup-dev with LM Studio (local)"
cleanup
make setup-dev AI_PROVIDER=lmstudio > /dev/null 2>&1
check_config_value .dev-config "AI_PROVIDER" "lmstudio"
check_config_value .dev-config "AI_URL" "http://localhost:1234"

log_test "setup-dev with Anthropic"
cleanup
make setup-dev AI_PROVIDER=anthropic AI_API_KEY=sk-ant-test > /dev/null 2>&1
check_config_value .dev-config "AI_PROVIDER" "anthropic"
check_config_value .dev-config "ANTHROPIC_API_KEY" "sk-ant-test"

log_test "setup-dev with Gemini"
cleanup
make setup-dev AI_PROVIDER=gemini AI_API_KEY=gemini-key > /dev/null 2>&1
check_config_value .dev-config "AI_PROVIDER" "gemini"
check_config_value .dev-config "GOOGLE_API_KEY" "gemini-key"

log_test "setup-dev with Mistral"
cleanup
make setup-dev AI_PROVIDER=mistral AI_API_KEY=mistral-key > /dev/null 2>&1
check_config_value .dev-config "AI_PROVIDER" "mistral"
check_config_value .dev-config "MISTRAL_API_KEY" "mistral-key"

# ==============================================================================
# STAGING TESTS
# ==============================================================================

log_test "setup-staging with AWS + OpenAI"
cleanup
make setup-staging CLOUD_PROVIDER=aws AI_PROVIDER=openai AI_API_KEY=sk-staging > /dev/null 2>&1
check_config_value .staging-config "ENVIRONMENT" "staging"
check_config_value .staging-config "CLOUD_PROVIDER" "aws"
check_config_value .staging-config "AI_PROVIDER" "openai"
check_config_value .staging-config "DB_APP_HOST" "postgres"
check_config_value .staging-config "DB_APP_SCHEMA" "app"
check_config_value .staging-config "DB_KEYCLOAK_SCHEMA" "keycloak"
check_config_value .staging-config "KEYCLOAK_ADMIN" "admin"

log_test "setup-staging with GCP + Anthropic"
cleanup
make setup-staging CLOUD_PROVIDER=gcp AI_PROVIDER=anthropic AI_API_KEY=sk-ant > /dev/null 2>&1
check_config_value .staging-config "CLOUD_PROVIDER" "gcp"
check_config_value .staging-config "AI_PROVIDER" "anthropic"

log_test "setup-staging with Azure + Ollama"
cleanup
make setup-staging CLOUD_PROVIDER=azure AI_PROVIDER=ollama > /dev/null 2>&1
check_config_value .staging-config "CLOUD_PROVIDER" "azure"
check_config_value .staging-config "AI_PROVIDER" "ollama"

# ==============================================================================
# DEPLOY (PROD) TESTS
# ==============================================================================

log_test "setup-deploy with AWS VM + Attached Storage"
cleanup
make setup-deploy \
    CLOUD_PROVIDER=aws \
    CLOUD_REGION=eu-west-3 \
    INFRA_TYPE=vm-attached-storage \
    DOMAIN_NAME=app.example.com \
    ELASTIC_IP=1.2.3.4 \
    ELASTIC_IP_ALLOC_ID=eipalloc-123456 \
    AI_PROVIDER=openai \
    AI_API_KEY=sk-prod-key \
    POSTGRES_PASSWORD=super-secret-pg \
    DB_APP_PASSWORD=app-secret \
    DB_MIGRATION_PASSWORD=mig-secret \
    DB_KEYCLOAK_PASSWORD=kc-secret \
    KEYSTONE_ADMIN=adminuser \
    KEYSTONE_ADMIN_PASSWORD=ks-secret \
    KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin-secret \
    CADDY_BUCKET_NAME=test-caddy-bucket \
    > /dev/null 2>&1
check_config_value .deploy-config "ENVIRONMENT" "prod"
check_config_value .deploy-config "CLOUD_PROVIDER" "aws"
check_config_value .deploy-config "CLOUD_REGION" "eu-west-3"
check_config_value .deploy-config "INFRA_TYPE" "vm-attached-storage"
check_config_value .deploy-config "DOMAIN_NAME" "app.example.com"
check_config_value .deploy-config "ELASTIC_IP" "1.2.3.4"
check_config_value .deploy-config "ELASTIC_IP_ALLOC_ID" "eipalloc-123456"
check_config_value .deploy-config "AI_PROVIDER" "openai"
check_config_value .deploy-config "POSTGRES_PASSWORD" "super-secret-pg"
check_config_value .deploy-config "DB_APP_PASSWORD" "app-secret"
check_config_value .deploy-config "DB_MIGRATION_PASSWORD" "mig-secret"
check_config_value .deploy-config "DB_KEYCLOAK_PASSWORD" "kc-secret"
check_config_value .deploy-config "KEYSTONE_ADMIN" "adminuser"
check_config_value .deploy-config "KEYSTONE_ADMIN_PASSWORD" "ks-secret"
check_config_value .deploy-config "KEYCLOAK_ADMIN" "admin"
check_config_value .deploy-config "KEYCLOAK_ADMIN_PASSWORD" "admin-secret"

log_test "setup-deploy with GCP VM + Managed Postgres"
cleanup
make setup-deploy \
    CLOUD_PROVIDER=gcp \
    CLOUD_REGION=europe-west1 \
    INFRA_TYPE=vm-managed-postgres \
    DOMAIN_NAME=gcp.example.com \
    AI_PROVIDER=gemini \
    AI_API_KEY=gemini-prod \
    POSTGRES_PASSWORD=pg123 \
    DB_APP_PASSWORD=app123 \
    DB_MIGRATION_PASSWORD=mig123 \
    DB_KEYCLOAK_PASSWORD=kc123 \
    KEYSTONE_ADMIN=admin \
    KEYSTONE_ADMIN_PASSWORD=ks123 \
    KEYCLOAK_ADMIN=kcadmin \
    KEYCLOAK_ADMIN_PASSWORD=kcpass \
    CADDY_BUCKET_NAME=test-caddy-bucket \
    > /dev/null 2>&1
check_config_value .deploy-config "CLOUD_PROVIDER" "gcp"
check_config_value .deploy-config "CLOUD_REGION" "europe-west1"
check_config_value .deploy-config "INFRA_TYPE" "vm-managed-postgres"
check_config_value .deploy-config "DOMAIN_NAME" "gcp.example.com"
check_config_value .deploy-config "AI_PROVIDER" "gemini"
check_config_value .deploy-config "GOOGLE_API_KEY" "gemini-prod"

log_test "setup-deploy with Azure Kubernetes"
cleanup
make setup-deploy \
    CLOUD_PROVIDER=azure \
    CLOUD_REGION=westeurope \
    INFRA_TYPE=k8s-managed-postgres \
    DOMAIN_NAME=azure.example.com \
    AI_PROVIDER=anthropic \
    AI_API_KEY=sk-ant-prod \
    POSTGRES_PASSWORD=pg-k8s \
    DB_APP_PASSWORD=app-k8s \
    DB_MIGRATION_PASSWORD=mig-k8s \
    DB_KEYCLOAK_PASSWORD=kc-k8s \
    KEYSTONE_ADMIN=admin \
    KEYSTONE_ADMIN_PASSWORD=ks-k8s \
    KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin-k8s \
    CADDY_BUCKET_NAME=test-caddy-bucket \
    > /dev/null 2>&1
check_config_value .deploy-config "CLOUD_PROVIDER" "azure"
check_config_value .deploy-config "CLOUD_REGION" "westeurope"
check_config_value .deploy-config "INFRA_TYPE" "k8s-managed-postgres"
check_config_value .deploy-config "AI_PROVIDER" "anthropic"
check_config_value .deploy-config "ANTHROPIC_API_KEY" "sk-ant-prod"

log_test "setup-deploy with Scaleway"
cleanup
make setup-deploy \
    CLOUD_PROVIDER=scaleway \
    CLOUD_REGION=fr-par \
    INFRA_TYPE=vm-attached-storage \
    DOMAIN_NAME=scw.example.com \
    AI_PROVIDER=mistral \
    AI_API_KEY=mistral-prod \
    POSTGRES_PASSWORD=pg-scw \
    DB_APP_PASSWORD=app-scw \
    DB_MIGRATION_PASSWORD=mig-scw \
    DB_KEYCLOAK_PASSWORD=kc-scw \
    KEYSTONE_ADMIN=admin \
    KEYSTONE_ADMIN_PASSWORD=ks-scw \
    KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin-scw \
    CADDY_BUCKET_NAME=test-caddy-bucket \
    > /dev/null 2>&1
check_config_value .deploy-config "CLOUD_PROVIDER" "scaleway"
check_config_value .deploy-config "CLOUD_REGION" "fr-par"
check_config_value .deploy-config "DOMAIN_NAME" "scw.example.com"
check_config_value .deploy-config "AI_PROVIDER" "mistral"
check_config_value .deploy-config "MISTRAL_API_KEY" "mistral-prod"

# ==============================================================================
# ERROR CASE TESTS
# ==============================================================================

log_test "setup-dev with invalid AI_PROVIDER should fail"
cleanup
if make setup-dev AI_PROVIDER=invalid_provider > /dev/null 2>&1; then
    log_fail "Should have failed with invalid AI_PROVIDER"
else
    log_pass "Correctly rejected invalid AI_PROVIDER"
fi

log_test "setup-deploy with invalid CLOUD_PROVIDER should fail"
cleanup
if make setup-deploy CLOUD_PROVIDER=invalid INFRA_TYPE=vm-attached-storage AI_PROVIDER=openai AI_API_KEY=sk-test POSTGRES_PASSWORD=pg DB_APP_PASSWORD=app DB_MIGRATION_PASSWORD=mig DB_KEYCLOAK_PASSWORD=kc KEYSTONE_ADMIN=admin KEYSTONE_ADMIN_PASSWORD=ks KEYCLOAK_ADMIN=admin KEYCLOAK_ADMIN_PASSWORD=kc CADDY_BUCKET_NAME=test DOMAIN_NAME=test.com CLOUD_REGION=us-east-1 > /dev/null 2>&1; then
    log_fail "Should have failed with invalid CLOUD_PROVIDER"
else
    log_pass "Correctly rejected invalid CLOUD_PROVIDER"
fi

log_test "setup-deploy with invalid INFRA_TYPE should fail"
cleanup
if make setup-deploy CLOUD_PROVIDER=aws INFRA_TYPE=invalid AI_PROVIDER=openai AI_API_KEY=sk-test POSTGRES_PASSWORD=pg DB_APP_PASSWORD=app DB_MIGRATION_PASSWORD=mig DB_KEYCLOAK_PASSWORD=kc KEYSTONE_ADMIN=admin KEYSTONE_ADMIN_PASSWORD=ks KEYCLOAK_ADMIN=admin KEYCLOAK_ADMIN_PASSWORD=kc CADDY_BUCKET_NAME=test DOMAIN_NAME=test.com CLOUD_REGION=us-east-1 > /dev/null 2>&1; then
    log_fail "Should have failed with invalid INFRA_TYPE"
else
    log_pass "Correctly rejected invalid INFRA_TYPE"
fi

# ==============================================================================
# SUMMARY
# ==============================================================================

cleanup

echo ""
echo "============================================================"
echo "                    TEST SUMMARY"
echo "============================================================"
echo "  Total tests: $TOTAL"
echo "  Assertions passed: $PASS"
echo "  Assertions failed: $FAIL"
echo "============================================================"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "[FAIL] Some tests failed!"
    exit 1
else
    echo ""
    echo "[OK] All tests passed!"
    exit 0
fi
