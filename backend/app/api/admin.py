"""
API endpoints for administration.
"""

from fastapi import APIRouter, HTTPException
from sqlalchemy import create_engine, text
from app.config.settings import settings

router = APIRouter(prefix="/api/admin", tags=["admin"])


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
