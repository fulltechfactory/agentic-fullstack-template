"""
Main Assistant Agent - A helpful AI assistant with session memory and RAG.
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


def create_assistant_agent(use_knowledge_tool: bool = False) -> Agent:
    """
    Create the main assistant agent with session memory and optional RAG.
    
    Args:
        use_knowledge_tool: Whether to add the knowledge search tool.
    
    Returns:
        Agent: Configured Agno agent instance.
    """
    instructions = [
        "You are a helpful AI assistant.",
        "Be concise and clear in your responses.",
        "If you don't know something, say so honestly.",
        "Respond in plain text, do not wrap your response in markdown code blocks.",
        "Always respond in the same language as the user.",
    ]
    
    tools = []
    
    # Add RAG tool if enabled
    if use_knowledge_tool:
        from app.tools.knowledge_search import search_knowledge_base
        tools.append(search_knowledge_base)
        
        instructions.extend([
            "",
            "## Knowledge Base Instructions",
            "You have access to a knowledge base containing company documents.",
            "Use the search_knowledge_base tool to find relevant information when the user asks questions.",
            "ALWAYS cite your sources by mentioning the document name in your response.",
            "Format citations like this: 'According to [Document Name], ...' or 'Source: [Document Name]'",
            "If the knowledge base doesn't contain relevant information, say so clearly.",
            "Do not make up information that is not in the knowledge base.",
        ])
    
    return Agent(
        name="Assistant",
        model=get_model(),
        db=get_db(),
        # Enable session memory
        add_history_to_context=True,
        num_history_runs=10,
        # Use custom tool instead of built-in search_knowledge
        tools=tools if tools else None,
        search_knowledge=False,  # Disabled - we use custom tool
        instructions=instructions,
        markdown=False,
    )
