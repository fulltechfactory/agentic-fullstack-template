"""
Main FastAPI application with AG-UI integration.
"""

from agno.os import AgentOS
from agno.os.interfaces.agui import AGUI

from app.agents.assistant import create_assistant_agent
from app.config.settings import settings


# Create the assistant agent
assistant = create_assistant_agent()

# Create AgentOS with AG-UI interface
agent_os = AgentOS(
    agents=[assistant],
    interfaces=[AGUI(agent=assistant)],
)

# Get the FastAPI app
app = agent_os.get_app()


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "environment": settings.ENVIRONMENT,
        "ai_provider": settings.AI_PROVIDER,
    }


if __name__ == "__main__":
    agent_os.serve(
        app="app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.ENVIRONMENT == "dev",
    )
