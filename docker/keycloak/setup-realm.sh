#!/bin/bash

# Use correct environment variable names from docker-compose
KEYCLOAK_REALM=${REALM_NAME:-agentic}
KEYCLOAK_CLIENT_ID=${CLIENT_ID:-agentic-app}
KEYCLOAK_CLIENT_SECRET=${CLIENT_SECRET:-agentic-secret}

# Wait for Keycloak to be ready (using kcadm instead of curl)
echo "Waiting for Keycloak to be ready..."
until /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://keycloak:8080 \
    --realm master \
    --user ${KEYCLOAK_ADMIN} \
    --password ${KEYCLOAK_ADMIN_PASSWORD} 2>/dev/null; do
    echo "  Keycloak not ready yet, retrying in 5s..."
    sleep 5
done
echo "Keycloak is ready!"

# Check if realm exists
REALM_EXISTS=$(/opt/keycloak/bin/kcadm.sh get realms/${KEYCLOAK_REALM} 2>/dev/null)

if [ -z "$REALM_EXISTS" ]; then
    echo "Creating realm ${KEYCLOAK_REALM}..."
    /opt/keycloak/bin/kcadm.sh create realms \
        -s realm=${KEYCLOAK_REALM} \
        -s enabled=true \
        -s displayName="Agentic Application"
else
    echo "Realm ${KEYCLOAK_REALM} already exists"
fi

# Get or create client
echo "Setting up client ${KEYCLOAK_CLIENT_ID}..."
CLIENT_UUID=$(/opt/keycloak/bin/kcadm.sh get clients -r ${KEYCLOAK_REALM} -q clientId=${KEYCLOAK_CLIENT_ID} --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4)

if [ -z "$CLIENT_UUID" ]; then
    /opt/keycloak/bin/kcadm.sh create clients -r ${KEYCLOAK_REALM} \
        -s clientId=${KEYCLOAK_CLIENT_ID} \
        -s enabled=true \
        -s publicClient=false \
        -s secret=${KEYCLOAK_CLIENT_SECRET} \
        -s "redirectUris=[\"http://localhost:3000/*\", \"http://127.0.0.1:3000/*\"]" \
        -s "webOrigins=[\"http://localhost:3000\", \"http://127.0.0.1:3000\"]" \
        -s directAccessGrantsEnabled=true \
        -s standardFlowEnabled=true
    
    CLIENT_UUID=$(/opt/keycloak/bin/kcadm.sh get clients -r ${KEYCLOAK_REALM} -q clientId=${KEYCLOAK_CLIENT_ID} --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4)
    echo "Client created with UUID: $CLIENT_UUID"
else
    echo "Client ${KEYCLOAK_CLIENT_ID} already exists with UUID: $CLIENT_UUID"
fi

# Create client roles
echo "Creating client roles..."
for ROLE in "RAG_SUPERVISOR" "ADMIN" "USER"; do
    ROLE_EXISTS=$(/opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/roles -r ${KEYCLOAK_REALM} 2>/dev/null | grep "\"name\" : \"$ROLE\"")
    if [ -z "$ROLE_EXISTS" ]; then
        /opt/keycloak/bin/kcadm.sh create clients/$CLIENT_UUID/roles -r ${KEYCLOAK_REALM} \
            -s name=$ROLE \
            -s description="$ROLE role"
        echo "  Role $ROLE created"
    else
        echo "  Role $ROLE already exists"
    fi
done

# Configure client to include roles in token
echo "Configuring client mappers for roles..."
MAPPER_EXISTS=$(/opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/protocol-mappers/models -r ${KEYCLOAK_REALM} 2>/dev/null | grep '"name" : "client roles"')
if [ -z "$MAPPER_EXISTS" ]; then
    /opt/keycloak/bin/kcadm.sh create clients/$CLIENT_UUID/protocol-mappers/models -r ${KEYCLOAK_REALM} \
        -s name="client roles" \
        -s protocol=openid-connect \
        -s protocolMapper=oidc-usermodel-client-role-mapper \
        -s 'config."claim.name"=resource_access.${client_id}.roles' \
        -s 'config."jsonType.label"=String' \
        -s 'config."multivalued"=true' \
        -s 'config."usermodel.clientRoleMapping.clientId"='${KEYCLOAK_CLIENT_ID} \
        -s 'config."id.token.claim"=true' \
        -s 'config."access.token.claim"=true' \
        -s 'config."userinfo.token.claim"=true'
    echo "  Client roles mapper created"
else
    echo "  Client roles mapper already exists"
fi

# Function to create user with roles
create_user() {
    local USERNAME=$1
    local PASSWORD=$2
    local EMAIL=$3
    local FIRSTNAME=$4
    local LASTNAME=$5
    shift 5
    local ROLES=("$@")
    
    echo "Setting up user ${USERNAME}..."
    USER_EXISTS=$(/opt/keycloak/bin/kcadm.sh get users -r ${KEYCLOAK_REALM} -q username=${USERNAME} --fields id | grep '"id"')
    
    if [ -z "$USER_EXISTS" ]; then
        /opt/keycloak/bin/kcadm.sh create users -r ${KEYCLOAK_REALM} \
            -s username=${USERNAME} \
            -s email=${EMAIL} \
            -s emailVerified=true \
            -s enabled=true \
            -s firstName=${FIRSTNAME} \
            -s lastName=${LASTNAME}
        
        /opt/keycloak/bin/kcadm.sh set-password -r ${KEYCLOAK_REALM} \
            --username ${USERNAME} \
            --new-password ${PASSWORD}
        
        echo "  User ${USERNAME} created"
    else
        echo "  User ${USERNAME} already exists"
    fi
    
    # Assign roles
    for ROLE in "${ROLES[@]}"; do
        /opt/keycloak/bin/kcadm.sh add-roles -r ${KEYCLOAK_REALM} \
            --uusername ${USERNAME} \
            --cclientid ${KEYCLOAK_CLIENT_ID} \
            --rolename ${ROLE} 2>/dev/null && echo "  Role ${ROLE} assigned to ${USERNAME}" || echo "  Role ${ROLE} already assigned to ${USERNAME}"
    done
}

# Create users
create_user "testuser" "testuser" "testuser@example.com" "Test" "User" "USER"
create_user "ragmanager" "ragmanager" "ragmanager@example.com" "RAG" "Manager" "USER" "RAG_SUPERVISOR"
create_user "adminuser" "adminuser" "adminuser@example.com" "Admin" "User" "USER" "ADMIN"

echo ""
echo "========================================"
echo "Keycloak setup completed!"
echo "========================================"
echo ""
echo "Users available:"
echo "  - testuser / testuser (USER role)"
echo "  - ragmanager / ragmanager (USER + RAG_SUPERVISOR roles)"
echo "  - adminuser / adminuser (USER + ADMIN roles)"
echo ""
