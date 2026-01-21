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

    elif provider == "azure-openai":
        # Azure OpenAI for GPT models (GPT-4o, GPT-5.2, etc.)
        from agno.models.azure import AzureOpenAI
        if not settings.AZURE_OPENAI_ENDPOINT:
            raise ValueError("AZURE_OPENAI_ENDPOINT is required for Azure OpenAI")
        if not settings.AZURE_OPENAI_API_KEY:
            raise ValueError("AZURE_OPENAI_API_KEY is required for Azure OpenAI")
        if not settings.AZURE_OPENAI_DEPLOYMENT:
            raise ValueError("AZURE_OPENAI_DEPLOYMENT is required for Azure OpenAI")
        return AzureOpenAI(
            id=model_id or "gpt-4o",
            api_key=settings.AZURE_OPENAI_API_KEY,
            azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
            azure_deployment=settings.AZURE_OPENAI_DEPLOYMENT,
            api_version=settings.AZURE_OPENAI_API_VERSION,
        )

    elif provider == "azure-ai-foundry":
        # Azure AI Foundry for serverless models (Phi, Llama, Mistral)
        from agno.models.azure import AzureAIFoundry
        if not settings.AZURE_ENDPOINT:
            raise ValueError("AZURE_ENDPOINT is required for Azure AI Foundry")
        if not settings.AZURE_API_KEY:
            raise ValueError("AZURE_API_KEY is required for Azure AI Foundry")
        return AzureAIFoundry(
            id=model_id or "Phi-4",
            api_key=settings.AZURE_API_KEY,
            azure_endpoint=settings.AZURE_ENDPOINT,
        )

    else:
        raise ValueError(f"Unknown AI provider: {provider}")
