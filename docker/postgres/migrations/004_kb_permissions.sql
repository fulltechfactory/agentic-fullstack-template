-- Migration: Knowledge Base Permissions
-- Description: Stores WRITE permissions and cross-group READ permissions
-- Date: 2024-12-17
-- 
-- Note: READ access for group members is IMPLICIT (not stored)
-- This table only stores:
--   - WRITE permissions (user can add/modify/delete docs)
--   - READ cross-group permissions (user can read KB outside their groups)

-- =============================================================================
-- Table: knowledge_base_permissions
-- =============================================================================

CREATE TABLE IF NOT EXISTS app.knowledge_base_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_name VARCHAR(100) NOT NULL,      -- Target group (e.g., /RH)
    user_id VARCHAR(100) NOT NULL,         -- Keycloak user ID
    permission VARCHAR(20) NOT NULL,       -- WRITE or READ (cross-group only)
    granted_by VARCHAR(100),               -- Admin who granted the permission
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicate permissions
    CONSTRAINT unique_user_group_perm UNIQUE (group_name, user_id, permission)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_kb_perm_group ON app.knowledge_base_permissions(group_name);
CREATE INDEX IF NOT EXISTS idx_kb_perm_user ON app.knowledge_base_permissions(user_id);

-- Comments
COMMENT ON TABLE app.knowledge_base_permissions IS 'Explicit permissions: WRITE access or cross-group READ access';
COMMENT ON COLUMN app.knowledge_base_permissions.group_name IS 'Keycloak group this permission applies to';
COMMENT ON COLUMN app.knowledge_base_permissions.permission IS 'WRITE = full access, READ = cross-group read only';
