"""
Thin wrapper around the Groq SDK (free-tier, fast Llama inference).
Deliberately minimal — this is groundwork for the future Conversational
AI Assistant module (Phase 17+ in the original plan), NOT the assistant
itself. No tool-calling, no agent orchestration, no memory — just "can we
send a message and get a real LLM response back." Everything else in the
original AI Assistant spec (tool calling, Gmail integration, document
generation, etc.) builds on top of this later, deliberately not now.
"""
from groq import Groq

from app.core.config import settings


def is_configured() -> bool:
    """Every route touching this checks first — see documents.py's
    is_configured() for the same pattern and why."""
    return bool(settings.GROQ_API_KEY)


def send_chat_message(message: str) -> str:
    """
    Sends a single user message to Groq's chat completion API and
    returns the reply text. No conversation history yet — each call is
    independent. Multi-turn context is a real feature to add once this
    basic plumbing is proven, not before.
    """
    client = Groq(api_key=settings.GROQ_API_KEY)
    response = client.chat.completions.create(
        model=settings.GROQ_MODEL,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are the ENOSIS Assistant, a helpful faculty copilot for a "
                    "college management platform. Keep answers concise and practical."
                ),
            },
            {"role": "user", "content": message},
        ],
    )
    return response.choices[0].message.content
