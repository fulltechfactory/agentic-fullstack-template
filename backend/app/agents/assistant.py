"""
Main Assistant Agent - A helpful AI assistant with session memory.
"""

from agno.agent import Agent
from agno.db.postgres import PostgresDb
from app.config.models import get_model
from app.config.settings import settings


def get_db() -> PostgresDb:
    """
    Get PostgreSQL database for session persistence.
    
    Returns:
        PostgresDb: Configured database instance.
    """
    return PostgresDb(
        db_url=settings.DATABASE_URL_BASE,
        db_schema=settings.DB_APP_SCHEMA,
        session_table="agent_sessions",
        create_schema=False,
    )


def create_assistant_agent(knowledge=None) -> Agent:
    """
    Create the main assistant agent with session memory and optional RAG.
    
    Args:
        knowledge: Optional knowledge base for RAG.
    
    Returns:
        Agent: Configured Agno agent instance.
    """
    return Agent(
        name="Assistant",
        model=get_model(),
        db=get_db(),
        # Enable session memory
        add_history_to_context=True,
        num_history_runs=10,
        # RAG configuration
        knowledge=knowledge,
        search_knowledge=True if knowledge else False,
        instructions=[
            "You are a helpful AI assistant.",
            "Be concise and clear in your responses.",
            "If you don't know something, say so honestly.",
            "When using knowledge base, cite your sources.",
            "Respond in plain text, do not wrap your response in markdown code blocks.",
            "Always respond in the same language as the user.",
        ],
        markdown=False,
    )
