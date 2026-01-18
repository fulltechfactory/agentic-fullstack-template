"""
AI Model factory - creates the appropriate model based on configuration.
"""

from app.config.settings import settings


def get_model():
    """
    Get the AI model based on the configured provider.

    Returns the appropriate Agno model instance.
    Uses AI_MODEL env var if set, otherwise falls back to provider defaults.
    """
    provider = settings.AI_PROVIDER.lower()
    model_id = settings.AI_MODEL  # Custom model ID (optional)

    if provider == "openai":
        from agno.models.openai import OpenAIChat
        return OpenAIChat(id=model_id or "gpt-4o")

    elif provider == "anthropic":
        from agno.models.anthropic import AnthropicChat
        return AnthropicChat(id=model_id or "claude-sonnet-4-20250514")

    elif provider == "gemini":
        from agno.models.google import GeminiChat
        return GeminiChat(id=model_id or "gemini-2.0-flash")

    elif provider == "mistral":
        from agno.models.mistral import MistralChat
        return MistralChat(id=model_id or "mistral-large-latest")

    elif provider == "ollama":
        from agno.models.ollama import Ollama
        base_url = settings.AI_URL or "http://host.docker.internal:11434"
        return Ollama(id=model_id or "llama3.2", host=base_url)

    elif provider == "lmstudio":
        # Use OpenAILike instead of native LMStudio connector (bug workaround)
        # LM Studio exposes an OpenAI-compatible API at /v1
        from agno.models.openai.like import OpenAILike
        base_url = settings.AI_URL or "http://host.docker.internal:1234"
        # Ensure URL ends with /v1 for OpenAI compatibility
        if not base_url.endswith("/v1"):
            base_url = f"{base_url}/v1"
        return OpenAILike(
            id=model_id or "local-model",
            base_url=base_url,
            api_key="not-needed"
        )

    else:
        raise ValueError(f"Unknown AI provider: {provider}")
