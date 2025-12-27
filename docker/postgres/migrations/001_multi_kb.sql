-- Migration: Multi Knowledge Base support
-- Description: Creates tables for multi-KB architecture with group-based permissions
-- Date: 2024-12-17

-- =============================================================================
-- Table: knowledge_bases
-- =============================================================================
-- Stores knowledge base metadata, each KB is linked to a Keycloak group
-- =============================================================================

CREATE TABLE IF NOT EXISTS app.knowledge_bases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    group_name VARCHAR(100) NOT NULL,  -- Keycloak group owner (e.g., /COMPANY, /RH)
    created_by VARCHAR(100),           -- User ID who created the KB
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- Index for group lookup
CREATE INDEX IF NOT EXISTS idx_kb_group_name ON app.knowledge_bases(group_name);

-- Comments
COMMENT ON TABLE app.knowledge_bases IS 'Knowledge bases linked to Keycloak groups';
COMMENT ON COLUMN app.knowledge_bases.group_name IS 'Keycloak group that owns this KB';
COMMENT ON COLUMN app.knowledge_bases.slug IS 'URL-friendly identifier';
