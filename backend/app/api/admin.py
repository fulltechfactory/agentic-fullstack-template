"""
API endpoints for administration.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlalchemy import create_engine, text
from typing import Optional
from app.config.settings import settings
from app.config.embedders import get_embedder, EMBEDDING_DIMENSIONS, DEFAULT_EMBEDDING_MODELS

router = APIRouter(prefix="/api/admin", tags=["admin"])


class EmbeddingConfigResponse(BaseModel):
    """Response model for embedding configuration."""
    provider: str
    model: str
    dimensions: int
    status: str
    needs_reindex: bool
    message: Optional[str] = None


class ReindexResponse(BaseModel):
    """Response model for reindex operation."""
    status: str
    documents_reindexed: int
    new_config: dict
    message: str


@router.get("/stats")
async def get_stats():
    """Get system statistics."""
    try:
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            # Count sessions
            sessions_result = conn.execute(
                text(f"SELECT COUNT(*) FROM {settings.DB_APP_SCHEMA}.agent_sessions")
            )
            sessions_count = sessions_result.scalar() or 0
            
            # Count knowledge documents
            knowledge_result = conn.execute(
                text(f"SELECT COUNT(*) FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings")
            )
            knowledge_count = knowledge_result.scalar() or 0
            
            # Get recent sessions with message counts
            recent_sessions = conn.execute(
                text(f"""
                    SELECT 
                        session_id,
                        created_at,
                        jsonb_array_length(COALESCE(runs, '[]'::jsonb)) as message_count
                    FROM {settings.DB_APP_SCHEMA}.agent_sessions
                    ORDER BY created_at DESC NULLS LAST
                    LIMIT 10
                """)
            )
            sessions_list = []
            for row in recent_sessions:
                created_at = row[1]
                if created_at is not None:
                    if hasattr(created_at, 'isoformat'):
                        created_at_str = created_at.isoformat()
                    else:
                        created_at_str = str(created_at)
                else:
                    created_at_str = None
                    
                sessions_list.append({
                    "session_id": str(row[0]),
                    "created_at": created_at_str,
                    "message_count": row[2] or 0
                })
            
        return {
            "status": "success",
            "stats": {
                "total_sessions": sessions_count,
                "total_knowledge_documents": knowledge_count,
                "ai_provider": settings.AI_PROVIDER,
                "environment": settings.ENVIRONMENT,
            },
            "recent_sessions": sessions_list,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health")
async def get_system_health():
    """Get system health status."""
    health = {
        "database": "unknown",
        "ai_provider": "unknown",
    }
    
    # Check database
    try:
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        health["database"] = "healthy"
    except Exception as e:
        health["database"] = f"unhealthy: {str(e)}"
    
    # Check AI provider config
    if settings.AI_PROVIDER:
        health["ai_provider"] = f"configured ({settings.AI_PROVIDER})"
    else:
        health["ai_provider"] = "not configured"

    return {
        "status": "success",
        "health": health,
    }


@router.get("/embedding-config", response_model=EmbeddingConfigResponse)
async def get_embedding_config():
    """
    Get current embedding configuration and check if reindex is needed.

    Compares the stored embedding config with the current AI provider settings.
    """
    provider = settings.AI_PROVIDER.lower()
    current_model = settings.EMBEDDING_MODEL or DEFAULT_EMBEDDING_MODELS.get(provider, "")
    current_dimensions = EMBEDDING_DIMENSIONS.get(provider, 1536)

    # For Anthropic, we use OpenAI as fallback
    if provider == "anthropic":
        current_model = "text-embedding-3-small"
        current_dimensions = EMBEDDING_DIMENSIONS["openai"]

    try:
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            # Get stored embedding config
            result = conn.execute(
                text(f"""
                    SELECT provider, model, dimensions
                    FROM {settings.DB_APP_SCHEMA}.embedding_config
                    WHERE id = 1
                """)
            ).fetchone()

            if result:
                stored_provider = result[0]
                stored_model = result[1]
                stored_dimensions = result[2]

                # Check if config has changed
                needs_reindex = (
                    stored_provider != provider or
                    stored_model != current_model or
                    stored_dimensions != current_dimensions
                )

                message = None
                if needs_reindex:
                    message = f"Embedding config changed from {stored_provider}/{stored_model} ({stored_dimensions}d) to {provider}/{current_model} ({current_dimensions}d). Reindex required."

                return EmbeddingConfigResponse(
                    provider=provider,
                    model=current_model,
                    dimensions=current_dimensions,
                    status="configured",
                    needs_reindex=needs_reindex,
                    message=message,
                )
            else:
                # No stored config - check if we have documents
                doc_count = conn.execute(
                    text(f"SELECT COUNT(*) FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings")
                ).scalar() or 0

                return EmbeddingConfigResponse(
                    provider=provider,
                    model=current_model,
                    dimensions=current_dimensions,
                    status="not_initialized",
                    needs_reindex=doc_count > 0,
                    message="Embedding config not initialized. Will be set on first document upload or reindex." if doc_count == 0 else "Documents exist but embedding config not set. Reindex recommended.",
                )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error checking embedding config: {str(e)}")


@router.post("/reindex", response_model=ReindexResponse)
async def reindex_documents():
    """
    Reindex all documents with the current embedding configuration.

    This will:
    1. Get all existing documents from the knowledge base
    2. Update the embedding dimensions if changed
    3. Re-embed all documents with the current embedder
    4. Update the embedding config in the database

    WARNING: This operation will clear and rebuild all embeddings.
    """
    provider = settings.AI_PROVIDER.lower()
    current_model = settings.EMBEDDING_MODEL or DEFAULT_EMBEDDING_MODELS.get(provider, "")
    current_dimensions = EMBEDDING_DIMENSIONS.get(provider, 1536)

    # For Anthropic, we use OpenAI as fallback
    embedding_provider = provider
    if provider == "anthropic":
        embedding_provider = "openai (fallback)"
        current_model = "text-embedding-3-small"
        current_dimensions = EMBEDDING_DIMENSIONS["openai"]

    # Get the embedder
    embedder, embedder_name, dimensions = get_embedder()
    if embedder is None:
        raise HTTPException(
            status_code=500,
            detail=f"Cannot create embedder: {embedder_name}"
        )

    try:
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            # Get all existing documents with their content and metadata
            documents = conn.execute(
                text(f"""
                    SELECT id, name, content, meta_data, knowledge_base_id
                    FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings
                    WHERE content IS NOT NULL AND content != ''
                """)
            ).fetchall()

            doc_count = len(documents)

            if doc_count == 0:
                # No documents to reindex - just update config
                conn.execute(
                    text(f"""
                        INSERT INTO {settings.DB_APP_SCHEMA}.embedding_config (id, provider, model, dimensions)
                        VALUES (1, :provider, :model, :dimensions)
                        ON CONFLICT (id) DO UPDATE SET
                            provider = :provider,
                            model = :model,
                            dimensions = :dimensions,
                            updated_at = NOW()
                    """),
                    {"provider": provider, "model": current_model, "dimensions": current_dimensions}
                )
                conn.commit()

                return ReindexResponse(
                    status="success",
                    documents_reindexed=0,
                    new_config={"provider": provider, "model": current_model, "dimensions": current_dimensions},
                    message="No documents to reindex. Embedding config updated.",
                )

            # Collect document data before truncating
            docs_to_reindex = []
            for row in documents:
                docs_to_reindex.append({
                    "name": row[1],
                    "content": row[2],
                    "meta_data": row[3],
                    "knowledge_base_id": str(row[4]) if row[4] else None,
                })

            # Update dimensions and truncate table
            conn.execute(
                text(f"SELECT {settings.DB_APP_SCHEMA}.update_embedding_dimension(:dimensions)"),
                {"dimensions": current_dimensions}
            )
            conn.commit()

            # Update embedding config
            conn.execute(
                text(f"""
                    INSERT INTO {settings.DB_APP_SCHEMA}.embedding_config (id, provider, model, dimensions)
                    VALUES (1, :provider, :model, :dimensions)
                    ON CONFLICT (id) DO UPDATE SET
                        provider = :provider,
                        model = :model,
                        dimensions = :dimensions,
                        updated_at = NOW()
                """),
                {"provider": provider, "model": current_model, "dimensions": current_dimensions}
            )
            conn.commit()

        # Re-embed all documents using the knowledge base
        from app.knowledge.base import get_knowledge_base
        knowledge = get_knowledge_base(embedder=embedder)

        for doc in docs_to_reindex:
            knowledge.add_content(
                text_content=doc["content"],
                name=doc["name"],
                metadata=doc["meta_data"] or {},
            )

            # Update knowledge_base_id if present
            if doc["knowledge_base_id"]:
                engine = create_engine(settings.DATABASE_URL)
                with engine.connect() as conn:
                    conn.execute(
                        text(f"""
                            UPDATE {settings.DB_APP_SCHEMA}.knowledge_embeddings
                            SET knowledge_base_id = :kb_id
                            WHERE knowledge_base_id IS NULL
                        """),
                        {"kb_id": doc["knowledge_base_id"]}
                    )
                    conn.commit()

        return ReindexResponse(
            status="success",
            documents_reindexed=len(docs_to_reindex),
            new_config={"provider": provider, "model": current_model, "dimensions": current_dimensions},
            message=f"Successfully reindexed {len(docs_to_reindex)} documents with {embedder_name}.",
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during reindex: {str(e)}")
