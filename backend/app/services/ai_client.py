"""Backend-only Groq chat client for the ENOSIS faculty assistant."""
from groq import Groq

from app.core.config import settings


def is_configured() -> bool:
    """Return whether a server-side Groq API key is configured."""
    return bool(settings.GROQ_API_KEY)


def send_chat_message(messages: list[dict[str, str]]) -> str:
    """Send one bounded conversation to Groq and return its plain-text answer."""
    client = Groq(
        api_key=settings.GROQ_API_KEY,
        timeout=settings.AI_REQUEST_TIMEOUT_SECONDS,
        max_retries=0,
    )
    response = client.chat.completions.create(
        model=settings.GROQ_MODEL,
        messages=messages,
        temperature=0.3,
    )
    return response.choices[0].message.content or ""
