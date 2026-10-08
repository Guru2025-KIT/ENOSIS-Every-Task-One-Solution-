import logging
from groq import Groq

from app.core.config import settings

logger = logging.getLogger("ai_client")


def is_configured() -> bool:
    """Return whether a server-side Groq API key is configured."""
    return bool(settings.GROQ_API_KEY)


def send_chat_message(messages: list[dict[str, str]]) -> str:
    """Send one bounded conversation to Groq with automatic fallback models."""
    client = Groq(
        api_key=settings.GROQ_API_KEY,
        timeout=settings.AI_REQUEST_TIMEOUT_SECONDS,
        max_retries=2,
    )
    candidate_models = [
        settings.GROQ_MODEL,
        "openai/gpt-oss-20b",
        "qwen/qwen3.8-27b",
        "openai/gpt-oss-120b",
    ]
    # Remove duplicates preserving order
    models_to_try = list(dict.fromkeys(candidate_models))

    last_error = None
    for model in models_to_try:
        try:
            response = client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=0.3,
            )
            content = response.choices[0].message.content or ""
            if content.strip():
                return content
        except Exception as e:
            last_error = e
            logger.warning("Groq chat attempt with model %s failed: %s. Trying fallback...", model, e)

    if lastError := last_error:
        raise lastError
    return ""
