import json
import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.academic import Subject, Room, Division
from app.services.ai_client import is_configured, send_chat_message
from app.core.config import settings

router = APIRouter(prefix="/ai", tags=["ai"])
logger = logging.getLogger("ai_assistant")

_NOT_CONFIGURED_DETAIL = (
    "The AI assistant isn't configured yet. Get a free API key from "
    "console.groq.com and set GROQ_API_KEY in .env, then restart the backend."
)


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str
    delta: dict | None = None


class TimetableConfigChatRequest(BaseModel):
    message: str
    conversation_history: list[dict[str, str]] = []


class TimetableConfigCommand(BaseModel):
    type: str          # create_subject | create_division | create_room | create_assignment | set_constraint | update_config
    params: dict[str, Any] = {}


class TimetableConfigChatResponse(BaseModel):
    reply: str
    commands: list[TimetableConfigCommand] = []
    parsed_successfully: bool = True


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
        
        try:
            parsed = json.loads(reply_raw)
            reply_text = parsed.get("reply", "")
            delta = parsed.get("delta", None)
        except json.JSONDecodeError:
            reply_text = reply_raw
            delta = None
            
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI request failed: {e}")

    return ChatResponse(reply=reply_text, delta=delta)


@router.post("/timetable-config-chat", response_model=TimetableConfigChatResponse)
def timetable_config_chat(
    payload: TimetableConfigChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    AI timetable configuration assistant.
    
    Accepts natural language instructions about setting up a timetable
    (e.g., "Add DBMS with 4 lectures per week for Division A") and
    returns structured commands the frontend can execute against the
    existing CRUD endpoints.
    
    Works even without a Groq API key via keyword-based fallback parsing.
    """
    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    # Load DB context for the LLM
    subjects = db.query(Subject).all()
    rooms = db.query(Room).all()
    divisions = db.query(Division).all()
    faculties = db.query(User).all()

    subject_list = [{"id": s.id, "name": s.name, "code": s.code} for s in subjects]
    room_list = [{"id": r.id, "name": r.name, "type": r.type} for r in rooms]
    division_list = [{"id": d.id, "name": d.name, "year": d.year, "code": d.division_code} for d in divisions]
    faculty_list = [{"id": f.id, "name": f.full_name, "email": f.email} for f in faculties]

    if not settings.GROQ_API_KEY:
        # Fallback: simple keyword parsing
        return _fallback_config_parse(message, subject_list, division_list, faculty_list, room_list)

    try:
        from groq import Groq
        client = Groq(api_key=settings.GROQ_API_KEY)

        history_messages = [
            {"role": msg["role"], "content": msg["content"]}
            for msg in payload.conversation_history[-10:]  # last 10 turns
        ]

        system_prompt = f"""You are the ENOSIS Timetable Configuration Assistant.
Your job is to help college timetable coordinators configure a timetable by converting their natural language requests into structured commands.

Current database state:
- Subjects: {json.dumps(subject_list)}
- Divisions: {json.dumps(division_list)}
- Rooms: {json.dumps(room_list)}
- Faculty: {json.dumps(faculty_list)}

You MUST respond with a JSON object with these fields:
{{
  "reply": "<friendly, concise response explaining what you understood and what commands you are returning>",
  "commands": [
    {{
      "type": "<command_type>",
      "params": {{ ... }}
    }}
  ],
  "parsed_successfully": true | false
}}

Supported command types and their params:
1. "create_subject": {{"name": str, "code": str|null, "weekly_lectures": int, "is_lab": bool, "lab_sessions_per_week": int, "lab_block_size": int}}
2. "create_division": {{"name": str, "year": int (1-4), "division_code": str, "strength": int}}
3. "create_room": {{"name": str, "type": "lecture"|"lab", "capacity": int}}
4. "create_assignment": {{"faculty_id": str, "subject_id": str, "division_id": str}}
5. "set_constraint": {{"constraint_type": str, "priority": "hard"|"soft", "payload": dict, "description": str}}
6. "update_config": {{"working_days": int, "periods_per_day": int, "start_time": str, "period_duration_minutes": int}}

Rules:
- If the user mentions a faculty by name, look up their ID from the faculty list above.
- If the user mentions a subject/division/room that doesn't exist yet, create it first.
- If you cannot identify a required entity (e.g. faculty name not found), ask for clarification in the reply and set parsed_successfully=false.
- For lab subjects: set is_lab=true, lab_sessions_per_week=1 (or as specified), lab_block_size=2 by default.
- If no commands are needed (e.g. user is just chatting), return an empty commands array.
- Return ONLY valid JSON, no markdown code blocks.
"""

        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(history_messages)
        messages.append({"role": "user", "content": message})

        response = client.chat.completions.create(
            model=settings.GROQ_MODEL,
            response_format={"type": "json_object"},
            messages=messages,
            temperature=0.1
        )

        raw = response.choices[0].message.content
        data = json.loads(raw)

        commands = [
            TimetableConfigCommand(type=c["type"], params=c.get("params", {}))
            for c in data.get("commands", [])
        ]

        return TimetableConfigChatResponse(
            reply=data.get("reply", "Configuration updated."),
            commands=commands,
            parsed_successfully=data.get("parsed_successfully", True)
        )

    except Exception as e:
        logger.error(f"Timetable config chat error: {e}")
        # Return a graceful fallback
        return TimetableConfigChatResponse(
            reply=f"I had trouble processing that request. Please try rephrasing, or use the manual configuration tabs. (Error: {str(e)[:100]})",
            commands=[],
            parsed_successfully=False
        )


def _fallback_config_parse(
    text: str,
    subjects: list,
    divisions: list,
    faculties: list,
    rooms: list
) -> TimetableConfigChatResponse:
    """Simple keyword-based fallback when Groq is not configured."""
    lower = text.lower()
    commands = []

    # Subject creation pattern: "add <name> with <N> lectures"
    import re
    sub_match = re.search(r"add (.+?) (?:with|having|for) (\d+) (?:lectures?|classes?|sessions?)", lower)
    if sub_match:
        subject_name = sub_match.group(1).strip().title()
        weekly = int(sub_match.group(2))
        is_lab = "lab" in subject_name.lower()
        commands.append(TimetableConfigCommand(
            type="create_subject",
            params={
                "name": subject_name,
                "weekly_lectures": 0 if is_lab else weekly,
                "is_lab": is_lab,
                "lab_sessions_per_week": weekly if is_lab else 0,
                "lab_block_size": 2,
            }
        ))
        return TimetableConfigChatResponse(
            reply=f"I'll add the subject '{subject_name}' with {weekly} {'lab' if is_lab else 'lecture'} sessions per week.",
            commands=commands,
            parsed_successfully=True
        )

    # Division creation: "add division A year 2"
    div_match = re.search(r"add (?:division|batch|class) ([a-z]) (?:year|yr) (\d)", lower)
    if div_match:
        code = div_match.group(1).upper()
        year = int(div_match.group(2))
        commands.append(TimetableConfigCommand(
            type="create_division",
            params={"name": f"Year {year} Div {code}", "year": year, "division_code": code, "strength": 60}
        ))
        return TimetableConfigChatResponse(
            reply=f"I'll create Division {code} for Year {year}.",
            commands=commands,
            parsed_successfully=True
        )

    return TimetableConfigChatResponse(
        reply=(
            "I understand you want to configure the timetable. "
            "You can say things like:\n"
            "• 'Add DBMS with 4 lectures per week'\n"
            "• 'Add Division A Year 2 with 60 students'\n"
            "• 'Add Lab 1 with capacity 30'\n"
            "• 'Dr. Priya is unavailable on Tuesday slot 1'\n\n"
            "Or configure a Groq API key for full natural language support."
        ),
        commands=[],
        parsed_successfully=False
    )
