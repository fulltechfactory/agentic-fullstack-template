"""
Knowledge base configuration for RAG.
"""

from agno.knowledge.knowledge import Knowledge
from agno.vectordb.pgvector import PgVector, SearchType
from app.config.settings import settings


def get_knowledge_base() -> Knowledge:
    """
    Create and return the knowledge base for RAG.
    
    Returns:
        Knowledge: Configured knowledge base with PgVector.
    """
    vector_db = PgVector(
        table_name="knowledge_embeddings",
        db_url=settings.DATABASE_URL_BASE,
        schema=settings.DB_APP_SCHEMA,
        search_type=SearchType.hybrid,
        create_schema=False,  # Table created by migration with custom columns
    )
    
    return Knowledge(
        vector_db=vector_db,
    )
