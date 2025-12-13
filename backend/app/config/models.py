"""
AI Model factory - creates the appropriate model based on configuration.
"""

from app.config.settings import settings


def get_model():
    """
    Get the AI model based on the configured provider.
    
    Returns the appropriate Agno model instance.
    """
    provider = settings.AI_PROVIDER.lower()

    if provider == "openai":
        from agno.models.openai import OpenAIChat
        return OpenAIChat(id="gpt-4o")

    elif provider == "anthropic":
        from agno.models.anthropic import AnthropicChat
        return AnthropicChat(id="claude-sonnet-4-20250514")

    elif provider == "gemini":
        from agno.models.google import GeminiChat
        return GeminiChat(id="gemini-2.0-flash")

    elif provider == "mistral":
        from agno.models.mistral import MistralChat
        return MistralChat(id="mistral-large-latest")

    elif provider == "ollama":
        from agno.models.ollama import Ollama
        base_url = settings.AI_URL or "http://localhost:11434"
        return Ollama(id="mistral:latest", host=base_url)

    elif provider == "lmstudio":
        from agno.models.lmstudio import LMStudio
        base_url = settings.AI_URL or "http://localhost:1234"
        return LMStudio(id="local-model", base_url=base_url)

    else:
        raise ValueError(f"Unknown AI provider: {provider}")
