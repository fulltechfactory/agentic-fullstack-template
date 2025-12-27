-- Migration: Initialize Company KB
-- Description: Create default Company KB and migrate existing documents
-- Date: 2024-12-17

-- =============================================================================
-- Create the default Company KB
-- =============================================================================

INSERT INTO app.knowledge_bases (name, slug, description, group_name, created_by)
VALUES (
    'Company',
    'company',
    'Base de connaissances commune à toute l''entreprise',
    '/COMPANY',
    'system'
) ON CONFLICT (slug) DO NOTHING;

-- =============================================================================
-- Migrate existing documents to Company KB
-- =============================================================================

UPDATE app.knowledge_embeddings
SET knowledge_base_id = (SELECT id FROM app.knowledge_bases WHERE slug = 'company')
WHERE knowledge_base_id IS NULL;
