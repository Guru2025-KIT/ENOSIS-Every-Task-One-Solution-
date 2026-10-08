import logging
from groq import Groq

from app.core.config import settings

logger = logging.getLogger("ai_client")


def is_configured() -> bool:
    """Return whether a server-side Groq API key is configured."""
    return bool(settings.GROQ_API_KEY)


def send_chat_message(messages: list[dict[str, str]]) -> str:
    """Send one bounded conversation to Groq with automatic fallback models and token compression."""
    client = Groq(
        api_key=settings.GROQ_API_KEY,
        timeout=max(settings.AI_REQUEST_TIMEOUT_SECONDS, 45),
        max_retries=2,
    )
    candidate_models = [
        settings.GROQ_MODEL,
        "openai/gpt-oss-20b",
        "qwen/qwen3.8-27b",
        "openai/gpt-oss-120b",
        "allam-2-7b",
    ]
    # Remove duplicates preserving order
    models_to_try = [m for m in dict.fromkeys(candidate_models) if m]

    def _execute_chat(msg_list: list[dict[str, str]]) -> str:
        last_error = None
        for model in models_to_try:
            try:
                response = client.chat.completions.create(
                    model=model,
                    messages=msg_list,
                    temperature=0.3,
                )
                content = response.choices[0].message.content or ""
                if content.strip():
                    return content
            except Exception as e:
                last_error = e
                logger.warning("Groq chat attempt with model %s failed: %s. Trying fallback...", model, e)
        if last_error:
            raise last_error
        return ""

    try:
        return _execute_chat(messages)
    except Exception as error:
        err_str = str(error).lower()
        if "413" in err_str or "rate_limit" in err_str or "too large" in err_str or "tokens" in err_str:
            logger.warning("Groq rate/token limit error (%s). Compressing messages and retrying...", error)
            compressed_msgs: list[dict[str, str]] = []
            for msg in messages:
                if msg.get("role") == "system":
                    content = msg.get("content", "")
                    if len(content) > 4000:
                        content = content[:4000] + "\n[Context trimmed for token budget]\n"
                    compressed_msgs.append({"role": "system", "content": content})
            # Only keep the last user query
            last_user_msg = messages[-1] if messages else {"role": "user", "content": ""}
            compressed_msgs.append(last_user_msg)
            try:
                return _execute_chat(compressed_msgs)
            except Exception as retry_err:
                logger.error("Compressed chat retry also failed: %s", retry_err)
                raise retry_err from error
        raise error

