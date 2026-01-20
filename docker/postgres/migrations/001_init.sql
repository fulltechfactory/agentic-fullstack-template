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
    group_name VARCHAR(100),  -- NULL for personal KBs
    owner_user_id VARCHAR(100),  -- Set for personal KBs, NULL for group KBs
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    -- Either group_name or owner_user_id must be set
    CONSTRAINT kb_ownership CHECK (group_name IS NOT NULL OR owner_user_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_kb_group_name ON app.knowledge_bases(group_name);
CREATE INDEX IF NOT EXISTS idx_kb_owner_user_id ON app.knowledge_bases(owner_user_id);

COMMENT ON TABLE app.knowledge_bases IS 'Knowledge bases - group-based or personal';
COMMENT ON COLUMN app.knowledge_bases.group_name IS 'Keycloak group that owns this KB (NULL for personal KBs)';
COMMENT ON COLUMN app.knowledge_bases.owner_user_id IS 'User ID for personal KB (NULL for group KBs)';

-- -----------------------------------------------------------------------------
-- Knowledge Embeddings
-- Table structure compatible with Agno PgVector + custom knowledge_base_id
-- Note: Agno may create this table before migration runs, so we handle both cases
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.knowledge_embeddings (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255),
    content TEXT,
    embedding vector(1536),
    meta_data JSONB,
    filters JSONB,
    usage JSONB,
    content_hash VARCHAR(64),
    content_id VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    knowledge_base_id UUID REFERENCES app.knowledge_bases(id) ON DELETE CASCADE
);

-- Add columns if table was created by Agno without them
DO $$
BEGIN
    -- Add knowledge_base_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app'
        AND table_name = 'knowledge_embeddings'
        AND column_name = 'knowledge_base_id'
    ) THEN
        ALTER TABLE app.knowledge_embeddings
        ADD COLUMN knowledge_base_id UUID REFERENCES app.knowledge_bases(id) ON DELETE CASCADE;
    END IF;

    -- Add filters
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app'
        AND table_name = 'knowledge_embeddings'
        AND column_name = 'filters'
    ) THEN
        ALTER TABLE app.knowledge_embeddings ADD COLUMN filters JSONB;
    END IF;

    -- Add usage
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app'
        AND table_name = 'knowledge_embeddings'
        AND column_name = 'usage'
    ) THEN
        ALTER TABLE app.knowledge_embeddings ADD COLUMN usage JSONB;
    END IF;

    -- Add content_hash
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app'
        AND table_name = 'knowledge_embeddings'
        AND column_name = 'content_hash'
    ) THEN
        ALTER TABLE app.knowledge_embeddings ADD COLUMN content_hash VARCHAR(64);
    END IF;

    -- Add content_id
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'app'
        AND table_name = 'knowledge_embeddings'
        AND column_name = 'content_id'
    ) THEN
        ALTER TABLE app.knowledge_embeddings ADD COLUMN content_id VARCHAR(255);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ke_knowledge_base_id ON app.knowledge_embeddings(knowledge_base_id);
CREATE INDEX IF NOT EXISTS idx_ke_content_hash ON app.knowledge_embeddings(content_hash);
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
-- Conversations
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL DEFAULT 'New conversation',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON app.conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated_at ON app.conversations(updated_at DESC);

COMMENT ON TABLE app.conversations IS 'User conversations for chat history';
COMMENT ON COLUMN app.conversations.user_id IS 'Keycloak user ID';
COMMENT ON COLUMN app.conversations.title IS 'Conversation title (user-editable)';

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
