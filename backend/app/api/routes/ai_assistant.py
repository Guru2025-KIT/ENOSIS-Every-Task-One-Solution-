from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.deps import get_current_user
from app.models.user import User
from app.services.ai_client import is_configured, send_chat_message

router = APIRouter(prefix="/ai", tags=["ai"])

_NOT_CONFIGURED_DETAIL = (
    "The AI assistant isn't configured yet. Get a free API key from "
    "console.groq.com and set GROQ_API_KEY in .env, then restart the backend."
)


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


@router.post("/chat", response_model=ChatResponse)
def chat(payload: ChatRequest, current_user: User = Depends(get_current_user)):
    """
    Single-turn chat with the LLM — foundational plumbing for the future
    Conversational AI Assistant module, not the assistant itself. No
    tool-calling, no memory of past messages, no access to any other
    ENOSIS data. Protected by login (get_current_user) since it costs API
    credits per call, same reasoning as any other paid external service.
    """
    if not is_configured():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=_NOT_CONFIGURED_DETAIL)

    if not payload.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    try:
        reply = send_chat_message(payload.message)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI request failed: {e}")

    return ChatResponse(reply=reply or "")
