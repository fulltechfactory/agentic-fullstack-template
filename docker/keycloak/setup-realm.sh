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
        -s displayName="Agentic Application" \
        -s sslRequired=NONE
else
    echo "Realm ${KEYCLOAK_REALM} already exists"
    /opt/keycloak/bin/kcadm.sh update realms/${KEYCLOAK_REALM} -s sslRequired=NONE
    echo "  SSL requirement disabled"
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
for ROLE in "ADMIN" "USER"; do
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

# =============================================================================
# GROUPS SETUP
# =============================================================================
echo ""
echo "Setting up groups..."

create_group() {
    local GROUP_NAME=$1
    
    GROUP_EXISTS=$(/opt/keycloak/bin/kcadm.sh get groups -r ${KEYCLOAK_REALM} 2>/dev/null | grep "\"name\" : \"$GROUP_NAME\"")
    if [ -z "$GROUP_EXISTS" ]; then
        /opt/keycloak/bin/kcadm.sh create groups -r ${KEYCLOAK_REALM} -s name=$GROUP_NAME
        echo "  Group /$GROUP_NAME created"
    else
        echo "  Group /$GROUP_NAME already exists"
    fi
}

create_group "COMPANY"
create_group "RH"
create_group "FINANCE"

# Configure client to include groups in token
echo "Configuring client mappers for groups..."
GROUP_MAPPER_EXISTS=$(/opt/keycloak/bin/kcadm.sh get clients/$CLIENT_UUID/protocol-mappers/models -r ${KEYCLOAK_REALM} 2>/dev/null | grep '"name" : "groups"')
if [ -z "$GROUP_MAPPER_EXISTS" ]; then
    /opt/keycloak/bin/kcadm.sh create clients/$CLIENT_UUID/protocol-mappers/models -r ${KEYCLOAK_REALM} \
        -s name="groups" \
        -s protocol=openid-connect \
        -s protocolMapper=oidc-group-membership-mapper \
        -s 'config."claim.name"=groups' \
        -s 'config."full.path"=true' \
        -s 'config."id.token.claim"=true' \
        -s 'config."access.token.claim"=true' \
        -s 'config."userinfo.token.claim"=true'
    echo "  Groups mapper created"
else
    echo "  Groups mapper already exists"
fi

# =============================================================================
# USERS SETUP
# =============================================================================
echo ""
echo "Setting up users..."

add_user_to_group() {
    local USERNAME=$1
    local GROUP_NAME=$2
    
    USER_ID=$(/opt/keycloak/bin/kcadm.sh get users -r ${KEYCLOAK_REALM} -q username=${USERNAME} --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4)
    GROUP_ID=$(/opt/keycloak/bin/kcadm.sh get groups -r ${KEYCLOAK_REALM} -q search=${GROUP_NAME} --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4 | head -1)
    
    if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
        /opt/keycloak/bin/kcadm.sh update users/${USER_ID}/groups/${GROUP_ID} -r ${KEYCLOAK_REALM} -s realm=${KEYCLOAK_REALM} -s userId=${USER_ID} -s groupId=${GROUP_ID} -n 2>/dev/null
        echo "    Added ${USERNAME} to /${GROUP_NAME}"
    fi
}

create_user() {
    local USERNAME=$1
    local PASSWORD=$2
    local EMAIL=$3
    local FIRSTNAME=$4
    local LASTNAME=$5
    local ROLE=$6
    
    echo "Setting up user ${USERNAME}..."
    USER_ID=$(/opt/keycloak/bin/kcadm.sh get users -r ${KEYCLOAK_REALM} -q username=${USERNAME} --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$USER_ID" ]; then
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
    
    # Assign role
    /opt/keycloak/bin/kcadm.sh add-roles -r ${KEYCLOAK_REALM} \
        --uusername ${USERNAME} \
        --cclientid ${KEYCLOAK_CLIENT_ID} \
        --rolename ${ROLE} 2>/dev/null && echo "  Role ${ROLE} assigned" || echo "  Role ${ROLE} already assigned"
}

# Create users
create_user "testuser" "testuser" "testuser@example.com" "Test" "User" "USER"
create_user "adminuser" "adminuser" "adminuser@example.com" "Admin" "User" "ADMIN"
create_user "rh_manager" "rh_manager" "rh_manager@example.com" "RH" "Manager" "USER"
create_user "finance_manager" "finance_manager" "finance_manager@example.com" "Finance" "Manager" "USER"

# Assign users to groups
echo ""
echo "Assigning users to groups..."
add_user_to_group "testuser" "COMPANY"
add_user_to_group "adminuser" "COMPANY"
add_user_to_group "rh_manager" "COMPANY"
add_user_to_group "rh_manager" "RH"
add_user_to_group "finance_manager" "COMPANY"
add_user_to_group "finance_manager" "FINANCE"

echo ""
echo "========================================"
echo "Keycloak setup completed!"
echo "========================================"
echo ""
echo "Roles:"
echo "  - USER: Access to chat and KBs based on group membership"
echo "  - ADMIN: Manage users, groups, KBs (no data access)"
echo ""
echo "Groups:"
echo "  - /COMPANY: All users (Company KB read access)"
echo "  - /RH: RH department"
echo "  - /FINANCE: Finance department"
echo ""
echo "Users:"
echo "  - testuser / testuser (USER, COMPANY)"
echo "  - adminuser / adminuser (ADMIN, COMPANY)"
echo "  - rh_manager / rh_manager (USER, COMPANY + RH)"
echo "  - finance_manager / finance_manager (USER, COMPANY + FINANCE)"
echo ""
