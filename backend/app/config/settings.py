"""
Application settings loaded from environment variables.
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment config file if it exists
config_files = [".dev-config", ".staging-config", ".deploy-config"]
for config_file in config_files:
    config_path = Path(__file__).parent.parent.parent.parent / config_file
    if config_path.exists():
        load_dotenv(config_path)
        break


class Settings:
    """Application settings."""
    
    # Environment
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "dev")
    
    # AI Provider
    AI_PROVIDER: str = os.getenv("AI_PROVIDER", "openai")
    AI_MODEL: str = os.getenv("AI_MODEL", "")  # Chat model ID (optional, uses provider default)
    AI_URL: str = os.getenv("AI_URL", "")  # Custom URL for local providers (Ollama, LM Studio)

    # Embedding Model (for RAG)
    EMBEDDING_MODEL: str = os.getenv("EMBEDDING_MODEL", "")  # Embedding model ID (optional, uses provider default)
    
    # API Keys
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")
    GOOGLE_API_KEY: str = os.getenv("GOOGLE_API_KEY", "")
    MISTRAL_API_KEY: str = os.getenv("MISTRAL_API_KEY", "")
    
    # Database - Application
    DB_APP_HOST: str = os.getenv("DB_APP_HOST", "localhost")
    DB_APP_PORT: str = os.getenv("DB_APP_PORT", "5432")
    DB_APP_NAME: str = os.getenv("DB_APP_NAME", "agentic_db")
    DB_APP_SCHEMA: str = os.getenv("DB_APP_SCHEMA", "app")
    DB_APP_USER: str = os.getenv("DB_APP_USER", "appuser")
    DB_APP_PASSWORD: str = os.getenv("DB_APP_PASSWORD", "appuser")
    
    @property
    def DATABASE_URL_BASE(self) -> str:
        """Build base database URL for SQLAlchemy (used by Agno db)."""
        return (
            f"postgresql+psycopg://{self.DB_APP_USER}:{self.DB_APP_PASSWORD}"
            f"@{self.DB_APP_HOST}:{self.DB_APP_PORT}/{self.DB_APP_NAME}"
        )
    
    @property
    def DATABASE_URL(self) -> str:
        """Build database URL with schema for general use."""
        return f"{self.DATABASE_URL_BASE}?options=-c%20search_path%3D{self.DB_APP_SCHEMA}"
    
    # Server
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

    # Web Search Configuration (for DuckDuckGo fallback)
    WEB_SEARCH_ENABLED: bool = os.getenv("WEB_SEARCH_ENABLED", "true").lower() == "true"
    WEB_SEARCH_NUM_RESULTS: int = int(os.getenv("WEB_SEARCH_NUM_RESULTS", "5"))
    WEB_SEARCH_TIMEOUT: float = float(os.getenv("WEB_SEARCH_TIMEOUT", "10.0"))
    WEB_SEARCH_DELAY: float = float(os.getenv("WEB_SEARCH_DELAY", "0.5"))

    # RAG Chunking Configuration
    CHUNK_SIZE: int = int(os.getenv("CHUNK_SIZE", "1000"))  # Characters per chunk
    CHUNK_OVERLAP: int = int(os.getenv("CHUNK_OVERLAP", "200"))  # Overlap between chunks
    CHUNK_MIN_SIZE: int = int(os.getenv("CHUNK_MIN_SIZE", "100"))  # Minimum chunk size

    # Personal KB Limits
    PERSONAL_KB_MAX_DOCS: int = int(os.getenv("PERSONAL_KB_MAX_DOCS", "100"))  # Max documents per user
    PERSONAL_KB_MAX_SIZE_MB: int = int(os.getenv("PERSONAL_KB_MAX_SIZE_MB", "100"))  # Max total size in MB


settings = Settings()
