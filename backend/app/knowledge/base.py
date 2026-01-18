"""
Knowledge base configuration for RAG.
"""

from typing import Optional
from agno.knowledge.knowledge import Knowledge
from agno.knowledge.embedder.base import Embedder
from agno.vectordb.pgvector import PgVector, SearchType
from app.config.settings import settings


def get_knowledge_base(embedder: Optional[Embedder] = None) -> Knowledge:
    """
    Create and return the knowledge base for RAG.

    Args:
        embedder: Optional embedder to use. If None, uses PgVector default (OpenAI).

    Returns:
        Knowledge: Configured knowledge base with PgVector.
    """
    vector_db = PgVector(
        table_name="knowledge_embeddings",
        db_url=settings.DATABASE_URL_BASE,
        schema=settings.DB_APP_SCHEMA,
        search_type=SearchType.hybrid,
        create_schema=False,  # Table created by migration with custom columns
        embedder=embedder,
    )

    return Knowledge(
        vector_db=vector_db,
    )
