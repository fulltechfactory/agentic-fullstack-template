#!/bin/bash
# ==============================================================================
# Keycloak SSL Disable Script (Development Only)
# Waits for Keycloak to start, then disables SSL requirement on master realm
# ==============================================================================

set -e

KEYCLOAK_URL="http://keycloak:8080"
KCADM="/opt/keycloak/bin/kcadm.sh"

echo "[INFO] Waiting for Keycloak to be ready..."

# Wait and retry kcadm config (max 60 attempts, 2 sec apart = 2 minutes)
for i in $(seq 1 60); do
    if $KCADM config credentials \
        --server "$KEYCLOAK_URL" \
        --realm master \
        --user "$KEYCLOAK_ADMIN" \
        --password "$KEYCLOAK_ADMIN_PASSWORD" 2>/dev/null; then
        echo "[OK] Connected to Keycloak"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "[FAIL] Could not connect to Keycloak"
        exit 1
    fi
    echo "[INFO] Attempt $i/60 - Keycloak not ready yet, waiting..."
    sleep 2
done

# Disable SSL on master realm
echo "[INFO] Disabling SSL requirement on master realm..."
$KCADM update realms/master -s sslRequired=NONE

echo "[OK] SSL requirement disabled for development"
