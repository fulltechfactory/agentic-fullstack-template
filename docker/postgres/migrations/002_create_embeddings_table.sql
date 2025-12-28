-- Migration 002: Create knowledge_embeddings table
-- This table is normally created by Agno, but we need it for KB references

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
