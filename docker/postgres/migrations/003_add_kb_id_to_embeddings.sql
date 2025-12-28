-- Migration: Add knowledge_base_id to embeddings
-- Description: Links embeddings to their knowledge base
-- Date: 2024-12-17

-- =============================================================================
-- Alter: knowledge_embeddings
-- =============================================================================
-- Add foreign key to knowledge_bases table
-- =============================================================================

ALTER TABLE app.knowledge_embeddings 
ADD COLUMN IF NOT EXISTS knowledge_base_id UUID REFERENCES app.knowledge_bases(id) ON DELETE CASCADE;

-- Index for KB lookup
CREATE INDEX IF NOT EXISTS idx_embeddings_kb_id ON app.knowledge_embeddings(knowledge_base_id);

-- Comment
COMMENT ON COLUMN app.knowledge_embeddings.knowledge_base_id IS 'Reference to the knowledge base this document belongs to';
