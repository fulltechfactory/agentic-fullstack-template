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
-- Knowledge Embeddings (RAG documents)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app.knowledge_embeddings (
    id VARCHAR(255) PRIMARY KEY,
    name TEXT,
    content TEXT,
    meta_data JSONB,
    embedding vector(1536),
    knowledge_base_id UUID REFERENCES app.knowledge_bases(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ke_knowledge_base_id ON app.knowledge_embeddings(knowledge_base_id);
CREATE INDEX IF NOT EXISTS idx_ke_embedding ON app.knowledge_embeddings USING ivfflat (embedding vector_cosine_ops);

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
