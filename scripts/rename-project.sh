#!/bin/bash

# =============================================================================
# Keystone Project Renaming Script
# =============================================================================
# Usage: ./scripts/rename-project.sh "New Name"
# Example: ./scripts/rename-project.sh "Acme Assistant"
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide a new name${NC}"
    echo "Usage: ./scripts/rename-project.sh \"New Name\""
    echo "Example: ./scripts/rename-project.sh \"Acme Assistant\""
    exit 1
fi

NEW_NAME="$1"
NEW_NAME_KEBAB=$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
NEW_NAME_SNAKE=$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

# Current names
OLD_NAME="Keystone"
OLD_NAME_KEBAB="keystone"
OLD_NAME_SNAKE="keystone"

echo -e "${YELLOW}==============================================================================${NC}"
echo -e "${YELLOW}Renaming project from '${OLD_NAME}' to '${NEW_NAME}'${NC}"
echo -e "${YELLOW}==============================================================================${NC}"
echo ""
echo "New name variants:"
echo "  - Display: ${NEW_NAME}"
echo "  - Kebab:   ${NEW_NAME_KEBAB}"
echo "  - Snake:   ${NEW_NAME_SNAKE}"
echo ""

read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${GREEN}Renaming files...${NC}"

# -----------------------------------------------------------------------------
# README.md
# -----------------------------------------------------------------------------
if [ -f "README.md" ]; then
    sed -i '' "s/# ${OLD_NAME}/# ${NEW_NAME}/g" README.md
    sed -i '' "s/${OLD_NAME}/${NEW_NAME}/g" README.md
    echo "  ✓ README.md"
fi

# -----------------------------------------------------------------------------
# Makefile
# -----------------------------------------------------------------------------
if [ -f "Makefile" ]; then
    sed -i '' "s/${OLD_NAME_SNAKE}_db/${NEW_NAME_SNAKE}_db/g" Makefile
    sed -i '' "s/${OLD_NAME_KEBAB}-app/${NEW_NAME_KEBAB}-app/g" Makefile
    sed -i '' "s/${OLD_NAME_KEBAB}-secret/${NEW_NAME_KEBAB}-secret/g" Makefile
    sed -i '' "s/realms\/${OLD_NAME_KEBAB}/realms\/${NEW_NAME_KEBAB}/g" Makefile
    echo "  ✓ Makefile"
fi

# -----------------------------------------------------------------------------
# docker-compose.yml
# -----------------------------------------------------------------------------
if [ -f "docker-compose.yml" ]; then
    sed -i '' "s/${OLD_NAME_KEBAB}-/${NEW_NAME_KEBAB}-/g" docker-compose.yml
    sed -i '' "s/${OLD_NAME_SNAKE}_db/${NEW_NAME_SNAKE}_db/g" docker-compose.yml
    sed -i '' "s/REALM_NAME=${OLD_NAME_KEBAB}/REALM_NAME=${NEW_NAME_KEBAB}/g" docker-compose.yml
    echo "  ✓ docker-compose.yml"
fi

# -----------------------------------------------------------------------------
# Keycloak setup
# -----------------------------------------------------------------------------
if [ -f "docker/keycloak/setup-realm.sh" ]; then
    sed -i '' "s/REALM_NAME:-${OLD_NAME_KEBAB}/REALM_NAME:-${NEW_NAME_KEBAB}/g" docker/keycloak/setup-realm.sh
    sed -i '' "s/CLIENT_ID:-${OLD_NAME_KEBAB}-app/CLIENT_ID:-${NEW_NAME_KEBAB}-app/g" docker/keycloak/setup-realm.sh
    sed -i '' "s/CLIENT_SECRET:-${OLD_NAME_KEBAB}-secret/CLIENT_SECRET:-${NEW_NAME_KEBAB}-secret/g" docker/keycloak/setup-realm.sh
    sed -i '' "s/${OLD_NAME} Application/${NEW_NAME}/g" docker/keycloak/setup-realm.sh
    echo "  ✓ docker/keycloak/setup-realm.sh"
fi

# -----------------------------------------------------------------------------
# Frontend
# -----------------------------------------------------------------------------
if [ -f "frontend/src/app/page.tsx" ]; then
    sed -i '' "s/${OLD_NAME}/${NEW_NAME}/g" frontend/src/app/page.tsx
    echo "  ✓ frontend/src/app/page.tsx"
fi

if [ -f "frontend/src/components/app-sidebar.tsx" ]; then
    sed -i '' "s/${OLD_NAME}/${NEW_NAME}/g" frontend/src/components/app-sidebar.tsx
    echo "  ✓ frontend/src/components/app-sidebar.tsx"
fi

if [ -f "frontend/src/app/layout.tsx" ]; then
    sed -i '' "s/${OLD_NAME}/${NEW_NAME}/g" frontend/src/app/layout.tsx
    echo "  ✓ frontend/src/app/layout.tsx"
fi

if [ -f "frontend/package.json" ]; then
    sed -i '' "s/\"name\": \".*\"/\"name\": \"${NEW_NAME_KEBAB}\"/g" frontend/package.json
    echo "  ✓ frontend/package.json"
fi

if [ -f "frontend/.env.local" ]; then
    sed -i '' "s/${OLD_NAME_KEBAB}-app/${NEW_NAME_KEBAB}-app/g" frontend/.env.local
    sed -i '' "s/${OLD_NAME_KEBAB}-secret/${NEW_NAME_KEBAB}-secret/g" frontend/.env.local
    sed -i '' "s/realms\/${OLD_NAME_KEBAB}/realms\/${NEW_NAME_KEBAB}/g" frontend/.env.local
    echo "  ✓ frontend/.env.local"
fi

# -----------------------------------------------------------------------------
# Backend
# -----------------------------------------------------------------------------
if [ -f "backend/app/agents/assistant.py" ]; then
    sed -i '' "s/name=\"${OLD_NAME}/name=\"${NEW_NAME}/g" backend/app/agents/assistant.py
    sed -i '' "s/name=\"Assistant\"/name=\"${NEW_NAME} Assistant\"/g" backend/app/agents/assistant.py
    echo "  ✓ backend/app/agents/assistant.py"
fi

# -----------------------------------------------------------------------------
# Test setup script
# -----------------------------------------------------------------------------
if [ -f "scripts/test-setup.sh" ]; then
    sed -i '' "s/${OLD_NAME_SNAKE}_db/${NEW_NAME_SNAKE}_db/g" scripts/test-setup.sh
    echo "  ✓ scripts/test-setup.sh"
fi

# -----------------------------------------------------------------------------
# Postgres migrations
# -----------------------------------------------------------------------------
for migration in docker/postgres/migrations/*.sql; do
    if [ -f "$migration" ]; then
        sed -i '' "s/${OLD_NAME_SNAKE}/${NEW_NAME_SNAKE}/g" "$migration"
        echo "  ✓ $migration"
    fi
done

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}Project renamed to '${NEW_NAME}' successfully!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review changes: git diff"
echo "  2. Clean and rebuild: make dev-clean && make dev-up"
echo "  3. Reinstall frontend: cd frontend && rm -rf node_modules && pnpm install"
echo "  4. Commit: git add -A && git commit -m 'chore: rename project to ${NEW_NAME}'"
echo ""
