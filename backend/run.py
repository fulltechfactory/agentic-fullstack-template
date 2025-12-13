"""
Entry point for running the backend server.
"""

from app.main import agent_os
from app.config.settings import settings

if __name__ == "__main__":
    print(f"[INFO] Starting server in {settings.ENVIRONMENT} mode")
    print(f"[INFO] AI Provider: {settings.AI_PROVIDER}")
    print(f"[INFO] Server: http://{settings.HOST}:{settings.PORT}")
    
    agent_os.serve(
        app="app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.ENVIRONMENT == "dev",
    )
