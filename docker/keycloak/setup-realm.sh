#!/bin/bash
# ==============================================================================
# Keycloak Realm Setup Script
# Uses kcadm.sh for reliable configuration
# ==============================================================================

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM_NAME="${REALM_NAME:-agentic}"
CLIENT_ID="${CLIENT_ID:-agentic-app}"
CLIENT_SECRET="${CLIENT_SECRET:-agentic-secret}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}"

KCADM="/opt/keycloak/bin/kcadm.sh"

echo "=========================================="
echo "Keycloak Realm Setup"
echo "=========================================="

# Wait for Keycloak to be ready by trying to authenticate
echo "[1/6] Waiting for Keycloak to be ready..."
until $KCADM config credentials --server "$KEYCLOAK_URL" --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD" 2>/dev/null; do
    echo "  Keycloak not ready, waiting 5s..."
    sleep 5
done
echo "  OK"

# Already authenticated in step 1
echo "[2/6] Authentication verified"
echo "  OK"

# Create realm if not exists
echo "[3/6] Checking realm '$REALM_NAME'..."
if $KCADM get realms/$REALM_NAME > /dev/null 2>&1; then
    echo "  Realm exists, updating SSL settings..."
    $KCADM update realms/$REALM_NAME -s sslRequired=none
else
    echo "  Creating realm..."
    $KCADM create realms -s realm="$REALM_NAME" -s enabled=true -s sslRequired=none
fi
echo "  OK"

# Create client if not exists
echo "[4/6] Checking client '$CLIENT_ID'..."
EXISTING_CLIENT=$($KCADM get clients -r "$REALM_NAME" -q clientId="$CLIENT_ID" --fields id 2>/dev/null | grep -o '"id" *: *"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$EXISTING_CLIENT" ]; then
    echo "  Client exists, skipping"
else
    echo "  Creating client..."
    $KCADM create clients -r "$REALM_NAME" \
        -s clientId="$CLIENT_ID" \
        -s name="Agentic App" \
        -s enabled=true \
        -s publicClient=false \
        -s secret="$CLIENT_SECRET" \
        -s 'redirectUris=["'"$FRONTEND_URL"'/*"]' \
        -s 'webOrigins=["'"$FRONTEND_URL"'"]' \
        -s standardFlowEnabled=true \
        -s directAccessGrantsEnabled=true \
        -s protocol=openid-connect
fi
echo "  OK"

# Create test user if not exists
echo "[5/6] Checking test user..."
EXISTING_USER=$($KCADM get users -r "$REALM_NAME" -q username=testuser --fields id 2>/dev/null | grep -o '"id" *: *"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$EXISTING_USER" ]; then
    echo "  User exists, skipping"
else
    echo "  Creating user..."
    $KCADM create users -r "$REALM_NAME" \
        -s username=testuser \
        -s email=testuser@example.com \
        -s firstName=Test \
        -s lastName=User \
        -s enabled=true \
        -s emailVerified=true
    
    # Set password
    $KCADM set-password -r "$REALM_NAME" --username testuser --new-password testuser
fi
echo "  OK"

# Disable SSL for master realm
echo "[6/6] Configuring master realm..."
$KCADM update realms/master -s sslRequired=none
echo "  OK"

echo "=========================================="
echo "Setup complete!"
echo "  Realm: $REALM_NAME"
echo "  Client: $CLIENT_ID / $CLIENT_SECRET"
echo "  User: testuser / testuser"
echo "=========================================="
