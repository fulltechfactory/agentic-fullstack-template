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
    AI_URL: str = os.getenv("AI_URL", "")
    
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


settings = Settings()
