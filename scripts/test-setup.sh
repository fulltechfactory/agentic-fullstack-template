#!/bin/bash

# ==============================================================================
# Test script for Makefile setup commands
# ==============================================================================

set -e

PASS=0
FAIL=0
TOTAL=0

# Colors for output (works in most terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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

check_config_exists() {
    local file=$1
    local key=$2
    
    if grep -q "^$key=" "$file" 2>/dev/null; then
        log_pass "$key exists in $file"
        return 0
    else
        log_fail "$key not found in $file"
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
check_config_value .dev-config "KEYCLOAK_ADMIN" "admin"
check_config_value .dev-config "KEYCLOAK_TEST_USER" "testuser"

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

log_test "setup-dev with Ollama (local)"
cleanup
make setup-dev AI_PROVIDER=ollama > /dev/null 2>&1
check_config_value .dev-config "AI_PROVIDER" "ollama"
check_config_value .dev-config "AI_URL" "http://localhost:11434"

log_test "setup-dev with LM Studio (local)"
cleanup
make setup-dev AI_PROVIDER=lmstudio > /dev/null 2>&1
check_config_value .dev-config "AI_PROVIDER" "lmstudio"
check_config_value .dev-config "AI_URL" "http://localhost:1234"

log_test "setup-dev with Ollama custom URL"
cleanup
make setup-dev AI_PROVIDER=ollama AI_URL=http://gpu-server:11434 > /dev/null 2>&1
check_config_value .dev-config "AI_URL" "http://gpu-server:11434"

# ==============================================================================
# STAGING TESTS
# ==============================================================================

log_test "setup-staging with AWS + OpenAI"
cleanup
make setup-staging CLOUD_PROVIDER=aws AI_PROVIDER=openai AI_API_KEY=sk-staging > /dev/null 2>&1
check_config_value .staging-config "ENVIRONMENT" "staging"
check_config_value .staging-config "CLOUD_PROVIDER" "aws"
check_config_value .staging-config "AI_PROVIDER" "openai"
check_config_value .staging-config "KEYCLOAK_ADMIN" "admin"
check_config_value .staging-config "KEYCLOAK_TEST_USER" "testuser"

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

log_test "setup-deploy with full config"
cleanup
make setup-deploy \
    CLOUD_PROVIDER=aws \
    AI_PROVIDER=openai \
    AI_API_KEY=sk-prod-key \
    POSTGRES_PASSWORD=super-secret-pg \
    DB_MIGRATION_USER=mig_prod \
    DB_MIGRATION_PASSWORD=mig-secret \
    DB_APP_USER=app_prod \
    DB_APP_PASSWORD=app-secret \
    DB_KEYCLOAK_USER=kc_prod \
    DB_KEYCLOAK_PASSWORD=kc-secret \
    KEYCLOAK_ADMIN=admin_prod \
    KEYCLOAK_ADMIN_PASSWORD=admin-secret \
    > /dev/null 2>&1
check_config_value .deploy-config "ENVIRONMENT" "prod"
check_config_value .deploy-config "CLOUD_PROVIDER" "aws"
check_config_value .deploy-config "AI_PROVIDER" "openai"
check_config_value .deploy-config "OPENAI_API_KEY" "sk-prod-key"
check_config_value .deploy-config "POSTGRES_PASSWORD" "super-secret-pg"
check_config_value .deploy-config "DB_MIGRATION_USER" "mig_prod"
check_config_value .deploy-config "DB_APP_USER" "app_prod"
check_config_value .deploy-config "DB_KEYCLOAK_USER" "kc_prod"
check_config_value .deploy-config "KEYCLOAK_ADMIN" "admin_prod"

log_test "setup-deploy with GCP + Gemini"
cleanup
make setup-deploy \
    CLOUD_PROVIDER=gcp \
    AI_PROVIDER=gemini \
    AI_API_KEY=gemini-prod \
    POSTGRES_PASSWORD=pg123 \
    DB_MIGRATION_PASSWORD=mig123 \
    DB_APP_PASSWORD=app123 \
    DB_KEYCLOAK_PASSWORD=kc123 \
    KEYCLOAK_ADMIN=kcadmin \
    KEYCLOAK_ADMIN_PASSWORD=kcpass \
    > /dev/null 2>&1
check_config_value .deploy-config "CLOUD_PROVIDER" "gcp"
check_config_value .deploy-config "AI_PROVIDER" "gemini"
check_config_value .deploy-config "GOOGLE_API_KEY" "gemini-prod"

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

# ==============================================================================
# SUMMARY
# ==============================================================================

cleanup

echo ""
echo "============================================================"
echo "                    TEST SUMMARY"
echo "============================================================"
echo "  Total:  $TOTAL"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
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
