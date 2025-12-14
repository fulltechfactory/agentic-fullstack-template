#!/bin/bash
set -e

echo "=== PostgreSQL Initialization ==="

# Create schemas and enable extensions
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable pgvector extension
    CREATE EXTENSION IF NOT EXISTS vector;
    
    -- Create schemas
    CREATE SCHEMA IF NOT EXISTS app;
    CREATE SCHEMA IF NOT EXISTS keycloak;
    
    -- Create users if they don't exist
    DO \$\$
    BEGIN
        -- Migration user (DDL operations)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_MIGRATION_USER}') THEN
            CREATE USER ${DB_MIGRATION_USER} WITH PASSWORD '${DB_MIGRATION_PASSWORD}';
        END IF;
        
        -- Application user (DML operations + DDL for dev)
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_APP_USER}') THEN
            CREATE USER ${DB_APP_USER} WITH PASSWORD '${DB_APP_PASSWORD}';
        END IF;
        
        -- Keycloak user
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_KEYCLOAK_USER}') THEN
            CREATE USER ${DB_KEYCLOAK_USER} WITH PASSWORD '${DB_KEYCLOAK_PASSWORD}';
        END IF;
    END
    \$\$;
    
    -- Grant schema permissions
    -- Migration user: full DDL on app schema
    GRANT ALL PRIVILEGES ON SCHEMA app TO ${DB_MIGRATION_USER};
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO ${DB_MIGRATION_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL PRIVILEGES ON TABLES TO ${DB_MIGRATION_USER};
    
    -- App user: DML + CREATE for dev (Agno auto-creates tables)
    GRANT ALL PRIVILEGES ON SCHEMA app TO ${DB_APP_USER};
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO ${DB_APP_USER};
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO ${DB_APP_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL PRIVILEGES ON TABLES TO ${DB_APP_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL PRIVILEGES ON SEQUENCES TO ${DB_APP_USER};
    
    -- Keycloak user: full access to keycloak schema
    GRANT ALL PRIVILEGES ON SCHEMA keycloak TO ${DB_KEYCLOAK_USER};
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA keycloak TO ${DB_KEYCLOAK_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA keycloak GRANT ALL PRIVILEGES ON TABLES TO ${DB_KEYCLOAK_USER};
EOSQL

echo "=== PostgreSQL Initialization Complete ==="
