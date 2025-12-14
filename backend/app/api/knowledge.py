"""
API endpoints for knowledge base management.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from app.knowledge.base import get_knowledge_base

router = APIRouter(prefix="/api/knowledge", tags=["knowledge"])


class AddTextRequest(BaseModel):
    """Request to add text to knowledge base."""
    content: str
    name: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class SearchRequest(BaseModel):
    """Request to search knowledge base."""
    query: str
    limit: int = 5


@router.post("/add")
async def add_text(request: AddTextRequest):
    """Add text content to the knowledge base."""
    try:
        knowledge = get_knowledge_base()
        knowledge.add_content(
            text_content=request.content,
            name=request.name,
            metadata=request.metadata,
        )
        return {"status": "success", "message": "Text added to knowledge base"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search")
async def search_knowledge(request: SearchRequest):
    """Search the knowledge base."""
    try:
        knowledge = get_knowledge_base()
        results = knowledge.search(query=request.query, max_results=request.limit)
        return {
            "status": "success",
            "results": [
                {
                    "content": doc.content if hasattr(doc, 'content') else str(doc),
                    "metadata": doc.metadata if hasattr(doc, 'metadata') else {},
                }
                for doc in results
            ],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_stats():
    """Get knowledge base statistics."""
    try:
        knowledge = get_knowledge_base()
        return {
            "status": "success",
            "table_name": "knowledge_embeddings",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
