"""
Main FastAPI application with AG-UI integration and RAG support.
"""

from agno.os import AgentOS
from agno.os.interfaces.agui import AGUI
from app.agents.assistant import create_assistant_agent
from app.config.settings import settings

# Initialize knowledge base if OpenAI is available (needed for embeddings)
knowledge = None
if settings.AI_PROVIDER == "openai" and settings.OPENAI_API_KEY:
    try:
        from app.knowledge.base import get_knowledge_base
        knowledge = get_knowledge_base()
        print("[INFO] Knowledge base initialized")
    except Exception as e:
        print(f"[WARNING] Could not initialize knowledge base: {e}")

# Create the assistant agent
assistant = create_assistant_agent(knowledge=knowledge)

# Create AgentOS with AG-UI interface
agent_os = AgentOS(
    agents=[assistant],
    interfaces=[AGUI(agent=assistant)],
)

# Get the FastAPI app
app = agent_os.get_app()

# Add knowledge API routes
from app.api.knowledge import router as knowledge_router
app.include_router(knowledge_router)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "environment": settings.ENVIRONMENT,
        "ai_provider": settings.AI_PROVIDER,
        "rag_enabled": knowledge is not None,
    }


if __name__ == "__main__":
    agent_os.serve(
        app="app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.ENVIRONMENT == "dev",
    )
