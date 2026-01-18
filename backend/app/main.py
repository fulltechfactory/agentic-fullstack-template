"""
Main FastAPI application with AG-UI integration and RAG support.
"""
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from agno.os import AgentOS
from agno.os.interfaces.agui import AGUI
from app.agents.assistant import create_assistant_agent
from app.config.settings import settings


class UserContextMiddleware(BaseHTTPMiddleware):
    """Middleware to set user context for knowledge search filtering."""
    
    async def dispatch(self, request: Request, call_next):
        # Extract user info from headers
        user_id = request.headers.get("X-User-ID", "")
        user_groups_str = request.headers.get("X-User-Groups", "")
        user_groups = [g.strip() for g in user_groups_str.split(",") if g.strip()]
        
        # Set context for knowledge search tool
        if user_id:
            from app.tools.knowledge_search import set_user_context
            set_user_context(user_id, user_groups)
        
        response = await call_next(request)
        return response


# Check if knowledge/RAG should be enabled
use_knowledge = False
embedding_provider = None

try:
    from app.config.embedders import get_embedder
    from app.knowledge.base import get_knowledge_base

    embedder, embedding_provider, dimensions = get_embedder()

    if embedder is None:
        # embedding_provider contains error message when embedder is None
        print(f"[ERROR] RAG disabled: {embedding_provider}")
    else:
        knowledge = get_knowledge_base(embedder=embedder)
        use_knowledge = True
        print(f"[INFO] RAG enabled with {embedding_provider} embeddings ({dimensions} dimensions)")

except Exception as e:
    print(f"[WARNING] Could not initialize knowledge base: {e}")

# Check if web search should be enabled
use_web_search = False
if settings.WEB_SEARCH_ENABLED:
    use_web_search = True
    print(f"[INFO] Web search enabled (DuckDuckGo)")

# Create the assistant agent with available tools
assistant = create_assistant_agent(
    use_knowledge_tool=use_knowledge,
    use_web_search=use_web_search,
)

# Create AgentOS with AG-UI interface
agent_os = AgentOS(
    agents=[assistant],
    interfaces=[AGUI(agent=assistant)],
)

# Get the FastAPI app
app = agent_os.get_app()

# Add user context middleware
app.add_middleware(UserContextMiddleware)

# Add knowledge API routes
from app.api.knowledge import router as documents_router
from app.api.admin import router as admin_router
from app.api.kb import router as kb_router
from app.api.permissions import router as permissions_router
from app.api.users import router as users_router
from app.api.upload import router as upload_router
from app.api.groups import router as groups_router

app.include_router(documents_router)
app.include_router(admin_router)
app.include_router(kb_router)
app.include_router(permissions_router)
app.include_router(users_router)
app.include_router(upload_router)
app.include_router(groups_router)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "environment": settings.ENVIRONMENT,
        "ai_provider": settings.AI_PROVIDER,
        "embedding_provider": embedding_provider if use_knowledge else None,
        "rag_enabled": use_knowledge,
        "web_search_enabled": use_web_search,
    }


if __name__ == "__main__":
    agent_os.serve(
        app="app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.ENVIRONMENT == "dev",
    )
