from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.base import get_db
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
    delta: dict | None = None


@router.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Single-turn chat with the LLM — parsed post-solve Timetable Assistant
    routing. Supports returning friendly conversational responses alongside
    an optional structured delta for timetable swaps.
    """
    if not is_configured():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=_NOT_CONFIGURED_DETAIL)

    if not payload.message.strip():
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    # 1. Fetch current timetable entries from database to populate LLM context
    from app.models.timetable import TimetableEntry
    entries = db.query(TimetableEntry).all()
    
    context_lines = []
    for e in entries:
        context_lines.append(
            f"- Subject: {e.subject.name}, Teacher: {e.faculty.full_name}, "
            f"Division: {e.division.division_code}, Day: {e.day}, Slot: {e.slot}, Room: {e.room.name}"
        )
    timetable_context = "\n".join(context_lines)

    try:
        reply_raw = send_chat_message(payload.message, timetable_context=timetable_context)
        
        # Robust parsing of JSON response
        import json
        try:
            parsed = json.loads(reply_raw)
            reply_text = parsed.get("reply", "")
            delta = parsed.get("delta", None)
        except json.JSONDecodeError:
            # Fallback if Groq response wasn't structured JSON
            reply_text = reply_raw
            delta = None
            
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI request failed: {e}")

    return ChatResponse(reply=reply_text, delta=delta)
