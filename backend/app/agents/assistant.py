"""
Main Assistant Agent - A helpful AI assistant.
"""

from agno.agent import Agent
from app.config.models import get_model


def create_assistant_agent() -> Agent:
    """
    Create the main assistant agent.
    
    Returns:
        Agent: Configured Agno agent instance.
    """
    return Agent(
        name="Assistant",
        model=get_model(),
        instructions=[
            "You are a helpful AI assistant.",
            "Be concise and clear in your responses.",
            "If you don't know something, say so honestly.",
            "Respond in plain text, do not wrap your response in markdown code blocks.",
        ],
        markdown=False,
    )
