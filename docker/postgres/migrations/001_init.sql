-- =============================================================================
-- Keystone Database Initialization
-- =============================================================================
-- This script initializes the complete database schema for development.
-- For production migrations, use numbered files in /migrations folder.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Knowledge Bases
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.knowledge_bases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    group_name VARCHAR(100) NOT NULL,
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_kb_group_name ON app.knowledge_bases(group_name);

COMMENT ON TABLE app.knowledge_bases IS 'Knowledge bases linked to Keycloak groups';
COMMENT ON COLUMN app.knowledge_bases.group_name IS 'Keycloak group that owns this KB (e.g., /COMPANY, /RH)';

-- -----------------------------------------------------------------------------
-- Knowledge Embeddings
-- Table structure compatible with Agno PgVector + custom knowledge_base_id
-- Note: Agno may create this table before migration runs, so we handle both cases
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.knowledge_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    content TEXT,
    embedding vector(1536),
    meta_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    knowledge_base_id UUID REFERENCES app.knowledge_bases(id) ON DELETE CASCADE
);

-- Add knowledge_base_id column if table was created by Agno without it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app'
        AND table_name = 'knowledge_embeddings'
        AND column_name = 'knowledge_base_id'
    ) THEN
        ALTER TABLE app.knowledge_embeddings
        ADD COLUMN knowledge_base_id UUID REFERENCES app.knowledge_bases(id) ON DELETE CASCADE;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ke_knowledge_base_id ON app.knowledge_embeddings(knowledge_base_id);
CREATE INDEX IF NOT EXISTS idx_ke_embedding ON app.knowledge_embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

COMMENT ON TABLE app.knowledge_embeddings IS 'Document embeddings for RAG with group-based filtering';
COMMENT ON COLUMN app.knowledge_embeddings.knowledge_base_id IS 'Links embedding to a knowledge base for multi-tenancy';

-- -----------------------------------------------------------------------------
-- Knowledge Base Permissions
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.knowledge_base_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_name VARCHAR(100) NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    permission VARCHAR(20) NOT NULL CHECK (permission IN ('READ', 'WRITE')),
    granted_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (group_name, user_id, permission)
);

CREATE INDEX IF NOT EXISTS idx_kbp_group_name ON app.knowledge_base_permissions(group_name);
CREATE INDEX IF NOT EXISTS idx_kbp_user_id ON app.knowledge_base_permissions(user_id);

COMMENT ON TABLE app.knowledge_base_permissions IS 'Explicit permissions for KB access';
COMMENT ON COLUMN app.knowledge_base_permissions.permission IS 'WRITE: manage docs, READ: cross-group access';

-- -----------------------------------------------------------------------------
-- Embedding Configuration (singleton)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.embedding_config (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100) NOT NULL,
    dimensions INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE app.embedding_config IS 'Stores current embedding configuration (singleton)';
COMMENT ON COLUMN app.embedding_config.provider IS 'Embedding provider (openai, gemini, mistral, ollama, lmstudio)';
COMMENT ON COLUMN app.embedding_config.model IS 'Embedding model ID';
COMMENT ON COLUMN app.embedding_config.dimensions IS 'Vector dimensions for the embedding model';

-- -----------------------------------------------------------------------------
-- Function to update embedding column dimension
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.update_embedding_dimension(new_dimensions INTEGER)
RETURNS VOID AS $$
BEGIN
    DROP INDEX IF EXISTS app.idx_ke_embedding;
    TRUNCATE TABLE app.knowledge_embeddings;
    EXECUTE format('ALTER TABLE app.knowledge_embeddings ALTER COLUMN embedding TYPE vector(%s)', new_dimensions);
    CREATE INDEX idx_ke_embedding ON app.knowledge_embeddings
        USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- Initial Data: Company Knowledge Base
-- -----------------------------------------------------------------------------
INSERT INTO app.knowledge_bases (name, slug, description, group_name, created_by)
VALUES (
    'Company',
    'company',
    'Shared company-wide knowledge base',
    '/COMPANY',
    'system'
) ON CONFLICT (slug) DO NOTHING;
