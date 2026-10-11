import json
import logging
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.base import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.academic import Subject, Room, Division
from app.services.ai_client import is_configured, send_chat_message
from app.services.assistant_context import retrieve_enosis_context
from app.services.assistant_prompt import build_chat_messages
from app.core.config import settings

router = APIRouter(prefix="/ai", tags=["ai"])
logger = logging.getLogger("ai_assistant")

_NOT_CONFIGURED_DETAIL = (
    "The AI assistant isn't configured yet. Get a free API key from "
    "console.groq.com and set GROQ_API_KEY in .env, then restart the backend."
)
_AI_REQUEST_FAILED_DETAIL = (
    "The AI assistant could not complete this request. Please try again shortly."
)


class ChatHistoryMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=2000)


class ChatRequest(BaseModel):
    message: str = Field(max_length=2000)
    conversation_history: list[ChatHistoryMessage] = Field(
        default_factory=list,
        max_length=12,
    )


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


def _fallback_generate_reply(message: str, context: dict[str, Any]) -> str:
    """Intelligent, context-aware fallback response generator when external LLM API is temporarily unreachable."""
    q = message.lower()
    current_user = context.get("current_user", {})
    user_name = current_user.get("name") or "Faculty Member"
    today = context.get("today", "Today")
    pub_status = context.get("timetable_publication_status", {})
    is_published = pub_status.get("is_published", False)

    # 1. Timetable / Schedule queries
    if any(k in q for k in ["schedule", "timetable", "today", "tomorrow", "lecture", "class", "period", "slot"]):
        if not is_published:
            return f"Hello {user_name}, the academic timetable has not been published yet by the department administrator. Once published, your daily schedule and classroom locations will automatically appear here."

        my_slots = context.get("my_published_timetable", [])
        if my_slots:
            lines = [f"📅 **Your Schedule for {today}** (User: {user_name}):", ""]
            for s in my_slots:
                sub = s.get("subject_name") or s.get("subject") or "Lecture"
                room = s.get("room_name") or s.get("room") or "Classroom"
                div = s.get("division_name") or s.get("division") or ""
                slot_num = s.get("slot", 0) + 1
                time_str = s.get("time_range") or f"Slot {slot_num}"
                lines.append(f"• **{time_str}**: {sub} — {div} ({room})")
            return "\n".join(lines)

        general_slots = context.get("published_timetable", [])
        if general_slots:
            lines = [f"📅 **Department Timetable Entries for {today}**:", ""]
            for s in general_slots[:6]:
                sub = s.get("subject_name") or s.get("subject") or "Lecture"
                fac = s.get("faculty_name") or s.get("faculty") or ""
                room = s.get("room_name") or s.get("room") or "Room"
                div = s.get("division_name") or s.get("division") or ""
                slot_num = s.get("slot", 0) + 1
                lines.append(f"• **Slot {slot_num}**: {sub} | {fac} | {div} ({room})")
            return "\n".join(lines)

        return f"You have no scheduled classes for **{today}** in the active published timetable."

    # 2. Teaching assignments / subjects
    if any(k in q for k in ["teach", "subject", "assigned", "course"]):
        my_tas = context.get("my_teaching_assignments", []) or context.get("teaching_assignments", [])
        if my_tas:
            lines = [f"📚 **Your Active Teaching Assignments** ({user_name}):", ""]
            for ta in my_tas:
                sub = ta.get("subject_name") or ta.get("subject_code") or "Subject"
                div = ta.get("division_name") or ta.get("division_code") or "Division"
                stype = ta.get("session_type", "Theory").capitalize()
                lines.append(f"• **{sub}** ({stype}) — Division {div}")
            return "\n".join(lines)
        all_subs = context.get("all_subjects", [])
        if all_subs:
            sub_names = [s.get("name") for s in all_subs[:8] if s.get("name")]
            return f"The department has active subjects including: {', '.join(sub_names)}."

    # 3. Career Development & Certificates
    if any(k in q for k in ["certificate", "certification", "career", "achievement", "fdp", "workshop", "publication"]):
        cd = context.get("career_development") or context.get("my_career_development")
        if cd and cd.get("person_exists"):
            achievements = cd.get("all_achievements", [])
            total = cd.get("total_achievements", len(achievements))
            pname = cd.get("name") or user_name
            if not achievements or total == 0:
                return f"{pname} has no certificates or career development achievements currently recorded in ENOSIS."
            lines = [f"🏆 **Career Achievements & Certifications for {pname}** (Total: {total}):", ""]
            for ach in achievements[:5]:
                title = ach.get("title") or "Achievement"
                org = ach.get("issuing_organization") or "Institution"
                cat = ach.get("category") or "Certification"
                lines.append(f"• **{title}** — {org} ({cat})")
            return "\n".join(lines)
        return f"No certificate records were found matching your query for {user_name}."

    # 4. General assistant greeting / fallback
    dept = current_user.get("department") or "Engineering"
    return (
        f"Hello {user_name}! I am your ENOSIS Academic AI Assistant for {dept}.\n\n"
        "I can help you with:\n"
        "• 📅 **Today's Schedule & Room Allocations**\n"
        "• 📚 **Assigned Subjects & Divisions**\n"
        "• 🏆 **Career Development & Certificates**\n"
        "• 📊 **SLI Student Learning Index & Analytics**\n\n"
        "How can I assist you with your academic workflows today?"
    )


@router.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Answer a general faculty question with relevant read-only ENOSIS facts."""
    if not is_configured():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=_NOT_CONFIGURED_DETAIL)

    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    history = [
        {"role": item.role, "content": item.content.strip()}
        for item in payload.conversation_history
        if item.content.strip()
    ]

    try:
        context = retrieve_enosis_context(db, current_user, message, history)
    except Exception as error:
        logger.warning("ENOSIS assistant context lookup non-fatal failure (%s). Proceeding with fallback context: %s", type(error).__name__, error)
        context = {
            "today": "Today",
            "today_weekday_index": 0,
            "current_datetime": "",
            "current_user": {
                "name": current_user.full_name,
                "department": current_user.department,
                "role": current_user.role.value if current_user.role else "faculty",
                "designation": current_user.designation,
            },
            "schedule_config": {},
            "timetable_publication_status": {},
            "matched_subjects": [],
            "matched_faculty": [],
            "matched_divisions": [],
            "teaching_assignments": [],
            "published_timetable": [],
            "my_published_timetable": [],
            "my_open_tasks": [],
            "my_teaching_attendance_summary": None,
            "career_development": None,
            "my_career_development": None,
            "all_divisions": [],
            "all_subjects": [],
            "unavailable_sources": [],
        }

    try:
        prompt_messages = build_chat_messages(message, history, context)
        reply_text = send_chat_message(prompt_messages).strip()
        if not reply_text:
            raise RuntimeError("The AI provider returned an empty response.")
    except Exception as error:
        logger.error("ENOSIS assistant request failed (%s): %s", type(error).__name__, error, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=_AI_REQUEST_FAILED_DETAIL,
        ) from error

    return ChatResponse(reply=reply_text)


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

        candidate_models = [settings.GROQ_MODEL, "openai/gpt-oss-20b", "qwen/qwen3.8-27b", "openai/gpt-oss-120b"]
        models_to_try = list(dict.fromkeys(candidate_models))
        response = None
        for m in models_to_try:
            try:
                response = client.chat.completions.create(
                    model=m,
                    response_format={"type": "json_object"},
                    messages=messages,
                    temperature=0.1
                )
                if response and response.choices:
                    break
            except Exception as mex:
                logger.warning(f"Groq model {m} failed for timetable config: {mex}. Trying next...")

        if not response or not response.choices:
            raise RuntimeError("All Groq candidate models failed.")

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
