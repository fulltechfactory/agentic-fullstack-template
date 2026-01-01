#!/bin/bash

# Use correct environment variable names from docker-compose
KEYCLOAK_REALM=${REALM_NAME:-keystone}
KEYCLOAK_CLIENT_ID=${CLIENT_ID:-keystone-app}
KEYCLOAK_CLIENT_SECRET=${CLIENT_SECRET:-keystone-secret}

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
        -s displayName="Keystone" \
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
# GROUPS SETUP - Only COMPANY group
# =============================================================================
echo ""
echo "Setting up groups..."

GROUP_EXISTS=$(/opt/keycloak/bin/kcadm.sh get groups -r ${KEYCLOAK_REALM} 2>/dev/null | grep "\"name\" : \"COMPANY\"")
if [ -z "$GROUP_EXISTS" ]; then
    /opt/keycloak/bin/kcadm.sh create groups -r ${KEYCLOAK_REALM} -s name=COMPANY
    echo "  Group /COMPANY created"
else
    echo "  Group /COMPANY already exists"
fi

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
# ADMIN USER SETUP
# =============================================================================
echo ""
echo "Setting up admin user..."

USER_ID=$(/opt/keycloak/bin/kcadm.sh get users -r ${KEYCLOAK_REALM} -q username=${KEYSTONE_ADMIN} --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4)

if [ -z "$USER_ID" ]; then
    /opt/keycloak/bin/kcadm.sh create users -r ${KEYCLOAK_REALM} \
        -s username=${KEYSTONE_ADMIN} \
        -s email=${KEYSTONE_ADMIN}@example.com \
        -s emailVerified=true \
        -s enabled=true \
        -s firstName=Admin \
        -s lastName=User
    
    /opt/keycloak/bin/kcadm.sh set-password -r ${KEYCLOAK_REALM} \
        --username ${KEYSTONE_ADMIN} \
        --new-password ${KEYSTONE_ADMIN_PASSWORD}
    
    echo "  User ${KEYSTONE_ADMIN} created"
else
    echo "  User ${KEYSTONE_ADMIN} already exists"
fi

# Assign ADMIN role
/opt/keycloak/bin/kcadm.sh add-roles -r ${KEYCLOAK_REALM} \
    --uusername ${KEYSTONE_ADMIN} \
    --cclientid ${KEYCLOAK_CLIENT_ID} \
    --rolename ADMIN 2>/dev/null && echo "  Role ADMIN assigned" || echo "  Role ADMIN already assigned"

# Add ${KEYSTONE_ADMIN} to COMPANY group
USER_ID=$(/opt/keycloak/bin/kcadm.sh get users -r ${KEYCLOAK_REALM} -q username=${KEYSTONE_ADMIN} --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4)
GROUP_ID=$(/opt/keycloak/bin/kcadm.sh get groups -r ${KEYCLOAK_REALM} -q search=COMPANY --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4 | head -1)

if [ -n "$USER_ID" ] && [ -n "$GROUP_ID" ]; then
    /opt/keycloak/bin/kcadm.sh update users/${USER_ID}/groups/${GROUP_ID} -r ${KEYCLOAK_REALM} -s realm=${KEYCLOAK_REALM} -s userId=${USER_ID} -s groupId=${GROUP_ID} -n 2>/dev/null
    echo "  Added ${KEYSTONE_ADMIN} to /COMPANY"
fi

echo ""
echo "========================================"
echo "Keycloak setup completed!"
echo "========================================"
echo ""
echo "Roles:"
echo "  - ADMIN: Manage users, groups, KBs"
echo "  - USER: (for regular users created via admin UI)"
echo ""
echo "Groups:"
echo "  - /COMPANY: Default group for all users"
echo ""
echo "Default Admin:"
echo "  - ${KEYSTONE_ADMIN} / *** (ADMIN)"
echo ""
echo "Use the admin UI to create additional users and groups."
echo ""
