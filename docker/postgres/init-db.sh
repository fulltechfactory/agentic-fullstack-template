#!/bin/bash
set -e

# ==============================================================================
# PostgreSQL Initialization Script
# Creates schemas and users for the agentic application
# ==============================================================================

echo "[INFO] Starting database initialization..."

# ------------------------------------------------------------------------------
# Create schemas
# ------------------------------------------------------------------------------
echo "[INFO] Creating schemas..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create schemas
    CREATE SCHEMA IF NOT EXISTS app;
    CREATE SCHEMA IF NOT EXISTS keycloak;
    
    -- Confirm creation
    SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('app', 'keycloak');
EOSQL

# ------------------------------------------------------------------------------
# Create users and grant permissions
# ------------------------------------------------------------------------------
echo "[INFO] Creating users..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Migration user (DDL permissions on app schema)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_MIGRATION_USER}') THEN
            CREATE USER ${DB_MIGRATION_USER} WITH PASSWORD '${DB_MIGRATION_PASSWORD}';
        END IF;
    END
    \$\$;
    
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${DB_MIGRATION_USER};
    GRANT USAGE ON SCHEMA app TO ${DB_MIGRATION_USER};
    GRANT CREATE ON SCHEMA app TO ${DB_MIGRATION_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON TABLES TO ${DB_MIGRATION_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON SEQUENCES TO ${DB_MIGRATION_USER};
    
    -- Application user (DML permissions on app schema)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_APP_USER}') THEN
            CREATE USER ${DB_APP_USER} WITH PASSWORD '${DB_APP_PASSWORD}';
        END IF;
    END
    \$\$;
    
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${DB_APP_USER};
    GRANT USAGE ON SCHEMA app TO ${DB_APP_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${DB_APP_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT USAGE, SELECT ON SEQUENCES TO ${DB_APP_USER};
    
    -- Keycloak user (full permissions on keycloak schema)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_KEYCLOAK_USER}') THEN
            CREATE USER ${DB_KEYCLOAK_USER} WITH PASSWORD '${DB_KEYCLOAK_PASSWORD}';
        END IF;
    END
    \$\$;
    
    GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ${DB_KEYCLOAK_USER};
    GRANT USAGE, CREATE ON SCHEMA keycloak TO ${DB_KEYCLOAK_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA keycloak GRANT ALL ON TABLES TO ${DB_KEYCLOAK_USER};
    ALTER DEFAULT PRIVILEGES IN SCHEMA keycloak GRANT ALL ON SEQUENCES TO ${DB_KEYCLOAK_USER};
EOSQL

echo "[OK] Database initialization completed successfully!"
