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


def create_assistant_agent(
    use_knowledge_tool: bool = False,
    use_web_search: bool = False,
) -> Agent:
    """
    Create the main assistant agent with session memory, optional RAG, and web search.

    Args:
        use_knowledge_tool: Whether to add the knowledge search tool.
        use_web_search: Whether to add the web search tool (DuckDuckGo fallback).

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

    # Add web search tool if enabled (DuckDuckGo fallback for Ollama/LM Studio)
    if use_web_search:
        from app.tools.web_search import search_web
        tools.append(search_web)

        instructions.extend([
            "",
            "## Web Search Instructions",
            "You have access to web search to find current information from the internet.",
            "IMPORTANT: You MUST use the search_web tool for ANY question about:",
            "- Current time in any location",
            "- Current weather in any location",
            "- Recent news or events",
            "- Real-time information (prices, sports scores, etc.)",
            "- Anything that may have changed since your knowledge cutoff",
            "Do NOT try to answer these questions from memory - ALWAYS use the tool first.",
            "ALWAYS cite your sources by including the URL in your response.",
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
