"""
Embedder factory - creates the appropriate embedder based on configuration.

Supports multiple embedding providers for RAG functionality.
"""

from typing import Optional, Tuple
from agno.knowledge.embedder.base import Embedder
from app.config.settings import settings


# Embedding dimensions for each provider (defaults)
EMBEDDING_DIMENSIONS = {
    "openai": 1536,      # text-embedding-3-small
    "gemini": 768,       # text-embedding-004
    "mistral": 1024,     # mistral-embed
    "ollama": 768,       # nomic-embed-text (default)
    "lmstudio": 768,     # nomic-embed-text (default for local)
    "anthropic": 1536,   # fallback to OpenAI
    "azure-openai": 1536,  # Azure OpenAI embeddings
    "azure-ai-foundry": 1536,  # Azure OpenAI embeddings (for serverless models)
}

# Default embedding models for each provider
DEFAULT_EMBEDDING_MODELS = {
    "openai": "text-embedding-3-small",
    "gemini": "text-embedding-004",
    "mistral": "mistral-embed",
    "ollama": "nomic-embed-text",
    "lmstudio": "text-embedding-nomic-embed-text-v1.5",
    "anthropic": "text-embedding-3-small",  # fallback to OpenAI
    "azure-openai": "text-embedding-3-small",  # Azure OpenAI embeddings
    "azure-ai-foundry": "text-embedding-3-small",  # Azure OpenAI embeddings (for serverless models)
}


def get_embedder() -> Tuple[Optional[Embedder], str, int]:
    """
    Get the appropriate embedder based on the configured AI provider.

    Returns:
        Tuple of (embedder, provider_name, dimensions)
        Returns (None, error_message, 0) if embedder cannot be created.
    """
    provider = settings.AI_PROVIDER.lower()
    embedding_model = settings.EMBEDDING_MODEL or DEFAULT_EMBEDDING_MODELS.get(provider, "")

    try:
        if provider == "openai":
            return _create_openai_embedder(embedding_model)

        elif provider == "gemini":
            return _create_gemini_embedder(embedding_model)

        elif provider == "mistral":
            return _create_mistral_embedder(embedding_model)

        elif provider == "ollama":
            return _create_ollama_embedder(embedding_model)

        elif provider == "lmstudio":
            return _create_lmstudio_embedder(embedding_model)

        elif provider == "anthropic":
            return _create_anthropic_fallback_embedder(embedding_model)

        elif provider == "azure-openai":
            return _create_azure_openai_embedder(embedding_model)

        elif provider == "azure-ai-foundry":
            return _create_azure_ai_foundry_embedder(embedding_model)

        else:
            return None, f"Unknown AI provider: {provider}", 0

    except ImportError as e:
        return None, f"Missing dependency for {provider} embedder: {e}", 0
    except Exception as e:
        return None, f"Failed to create {provider} embedder: {e}", 0


def _create_openai_embedder(model: str) -> Tuple[Embedder, str, int]:
    """Create OpenAI embedder."""
    if not settings.OPENAI_API_KEY:
        raise ValueError("OPENAI_API_KEY is required for OpenAI embeddings")

    from agno.knowledge.embedder.openai import OpenAIEmbedder

    embedder = OpenAIEmbedder(
        id=model,
        api_key=settings.OPENAI_API_KEY,
    )

    return embedder, f"OpenAI ({model})", EMBEDDING_DIMENSIONS["openai"]


def _create_gemini_embedder(model: str) -> Tuple[Embedder, str, int]:
    """Create Gemini embedder."""
    if not settings.GOOGLE_API_KEY:
        raise ValueError("GOOGLE_API_KEY is required for Gemini embeddings")

    from agno.knowledge.embedder.google import GeminiEmbedder

    embedder = GeminiEmbedder(
        id=model,
        api_key=settings.GOOGLE_API_KEY,
    )

    return embedder, f"Gemini ({model})", EMBEDDING_DIMENSIONS["gemini"]


def _create_mistral_embedder(model: str) -> Tuple[Embedder, str, int]:
    """Create Mistral embedder."""
    if not settings.MISTRAL_API_KEY:
        raise ValueError("MISTRAL_API_KEY is required for Mistral embeddings")

    from agno.knowledge.embedder.mistral import MistralEmbedder

    embedder = MistralEmbedder(
        id=model,
        api_key=settings.MISTRAL_API_KEY,
    )

    return embedder, f"Mistral ({model})", EMBEDDING_DIMENSIONS["mistral"]


def _create_ollama_embedder(model: str) -> Tuple[Embedder, str, int]:
    """Create Ollama embedder for local models."""
    from agno.knowledge.embedder.ollama import OllamaEmbedder

    host = settings.AI_URL or "http://localhost:11434"

    embedder = OllamaEmbedder(
        id=model,
        host=host,
    )

    return embedder, f"Ollama ({model})", EMBEDDING_DIMENSIONS["ollama"]


def _create_lmstudio_embedder(model: str) -> Tuple[Embedder, str, int]:
    """Create LM Studio embedder using OpenAI-compatible API."""
    from agno.knowledge.embedder.openai import OpenAIEmbedder

    base_url = settings.AI_URL or "http://localhost:1234"
    if not base_url.endswith("/v1"):
        base_url = f"{base_url}/v1"

    embedder = OpenAIEmbedder(
        id=model,
        base_url=base_url,
        api_key="not-needed",
    )

    return embedder, f"LM Studio ({model})", EMBEDDING_DIMENSIONS["lmstudio"]


def _create_anthropic_fallback_embedder(model: str) -> Tuple[Embedder, str, int]:
    """
    Create OpenAI embedder as fallback for Anthropic.

    Anthropic does not provide embedding models, so we use OpenAI as fallback.
    """
    if not settings.OPENAI_API_KEY:
        raise ValueError(
            "Anthropic does not provide embeddings. "
            "OPENAI_API_KEY is required as fallback for RAG functionality."
        )

    from agno.knowledge.embedder.openai import OpenAIEmbedder

    # Use OpenAI model for embeddings
    openai_model = model if model != DEFAULT_EMBEDDING_MODELS["anthropic"] else "text-embedding-3-small"

    embedder = OpenAIEmbedder(
        id=openai_model,
        api_key=settings.OPENAI_API_KEY,
    )

    print("[WARNING] Anthropic does not provide embeddings. Using OpenAI as fallback.")

    return embedder, f"OpenAI fallback ({openai_model})", EMBEDDING_DIMENSIONS["anthropic"]


def _create_azure_openai_embedder(model: str) -> Tuple[Embedder, str, int]:
    """
    Create Azure OpenAI embedder.

    Uses Azure OpenAI embedding models (GPT models like text-embedding-3-small).
    Supports separate endpoint and API key for embeddings if configured.
    """
    # Use separate embedding API key if configured, otherwise fall back to main API key
    embedding_api_key = settings.AZURE_OPENAI_EMBEDDING_API_KEY or settings.AZURE_OPENAI_API_KEY
    if not embedding_api_key:
        raise ValueError(
            "AZURE_OPENAI_EMBEDDING_API_KEY or AZURE_OPENAI_API_KEY is required for Azure OpenAI embeddings"
        )

    # Use separate embedding endpoint if configured, otherwise fall back to main endpoint
    embedding_endpoint = settings.AZURE_OPENAI_EMBEDDING_ENDPOINT or settings.AZURE_OPENAI_ENDPOINT
    if not embedding_endpoint:
        raise ValueError(
            "AZURE_OPENAI_EMBEDDING_ENDPOINT or AZURE_OPENAI_ENDPOINT is required for Azure OpenAI embeddings"
        )

    from agno.knowledge.embedder.azure_openai import AzureOpenAIEmbedder

    embedder = AzureOpenAIEmbedder(
        id=model,
        api_key=embedding_api_key,
        azure_endpoint=embedding_endpoint,
        azure_deployment=settings.AZURE_OPENAI_EMBEDDING_DEPLOYMENT or None,
        api_version=settings.AZURE_OPENAI_API_VERSION,
    )

    deployment_info = settings.AZURE_OPENAI_EMBEDDING_DEPLOYMENT or model
    return embedder, f"Azure OpenAI ({deployment_info})", EMBEDDING_DIMENSIONS["azure-openai"]


def _create_azure_ai_foundry_embedder(model: str) -> Tuple[Embedder, str, int]:
    """
    Create Azure OpenAI embedder for Azure AI Foundry.

    Uses Azure OpenAI embedding models. Requires AZURE_OPENAI_ENDPOINT for embeddings
    (separate from AZURE_ENDPOINT used for chat models).
    """
    if not settings.AZURE_API_KEY:
        raise ValueError("AZURE_API_KEY is required for Azure AI Foundry embeddings")
    if not settings.AZURE_OPENAI_ENDPOINT:
        raise ValueError(
            "AZURE_OPENAI_ENDPOINT is required for Azure AI Foundry embeddings. "
            "This is the Azure OpenAI endpoint (e.g., https://<resource>.openai.azure.com), "
            "separate from AZURE_ENDPOINT used for chat models."
        )

    from agno.knowledge.embedder.azure_openai import AzureOpenAIEmbedder

    embedder = AzureOpenAIEmbedder(
        id=model,
        api_key=settings.AZURE_API_KEY,
        azure_endpoint=settings.AZURE_OPENAI_ENDPOINT,
    )

    return embedder, f"Azure OpenAI ({model})", EMBEDDING_DIMENSIONS["azure-ai-foundry"]


def get_embedding_dimensions(provider: str = None) -> int:
    """Get the embedding dimensions for a provider."""
    if provider is None:
        provider = settings.AI_PROVIDER.lower()
    return EMBEDDING_DIMENSIONS.get(provider, 1536)
