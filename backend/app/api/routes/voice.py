import json
import logging
import os
import tempfile
import asyncio
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy.orm import Session
from groq import Groq

from app.api.deps import get_current_user
from app.core.config import settings
from app.db.base import get_db
from app.models.user import User
from app.models.academic import Subject, Room
from app.schemas.timetable import TtsRequest, ParseConstraintRequest, ParseConstraintResponse, ConstraintCreate

# Try importing edge_tts. If not installed, we can fall back gracefully.
try:
    import edge_tts
    HAS_EDGE_TTS = True
except ImportError:
    HAS_EDGE_TTS = False

router = APIRouter(prefix="/voice", tags=["voice"])
logger = logging.getLogger("voice_routes")


@router.post("/tts")
async def text_to_speech(payload: TtsRequest, _: User = Depends(get_current_user)):
    """
    Text-to-Speech proxy.
    Tries ElevenLabs first if API key is configured.
    Otherwise falls back to Microsoft Edge-TTS neural voices.
    Returns audio bytes directly.
    """
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Text cannot be empty.")

    # ── Try ElevenLabs (Primary) ───────────────────────────────────────────
    if settings.ELEVENLABS_API_KEY:
        try:
            import httpx
            headers = {
                "xi-api-key": settings.ELEVENLABS_API_KEY,
                "Content-Type": "application/json"
            }
            # Pick voice based on role
            if payload.role in ("error", "conflict", "male"):
                voice_id = settings.ELEVENLABS_VOICE_ID_MALE
            else:
                voice_id = settings.ELEVENLABS_VOICE_ID_FEMALE
            
            url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
            data = {
                "text": text,
                "model_id": "eleven_monolingual_v1",
                "voice_settings": {
                    "stability": 0.5,
                    "similarity_boost": 0.75
                }
            }
            async with httpx.AsyncClient() as client:
                response = await client.post(url, json=data, headers=headers, timeout=15.0)
                if response.status_code == 200:
                    return Response(content=response.content, media_type="audio/mpeg")
                else:
                    logger.warning(f"ElevenLabs API failed with status {response.status_code}: {response.text}")
        except Exception as e:
            logger.warning(f"ElevenLabs TTS failed: {e}")

    # ── Try Edge-TTS (Secondary) ───────────────────────────────────────────
    if HAS_EDGE_TTS:
        try:
            # Determine appropriate neural voice based on role
            # Neerja (Indian Female Neural) or Prabhat (Indian Male Neural)
            voice = "en-IN-NeerjaNeural"
            if payload.role in ("error", "conflict"):
                voice = "en-IN-PrabhatNeural"

            communicate = edge_tts.Communicate(text, voice, rate="+20%")
            
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
                tmp_path = tmp.name

            try:
                await communicate.save(tmp_path)
                with open(tmp_path, "rb") as f:
                    audio_bytes = f.read()
                return Response(content=audio_bytes, media_type="audio/mpeg")
            finally:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
        except Exception as e:
            logger.error(f"Edge-TTS generation failed: {e}")

    # ── No TTS methods succeeded ───────────────────────────────────────────
    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Text-to-Speech engines (ElevenLabs & Edge-TTS) are currently unavailable or unconfigured."
    )


@router.post("/parse-constraint", response_model=ParseConstraintResponse)
def parse_constraint(
    payload: ParseConstraintRequest,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user)
):
    """
    Parses natural language speech into a structured ConstraintCreate payload.
    Uses Groq LLM to perform NLP slot extraction.
    """
    speech_text = payload.speech_text.strip()
    if not speech_text:
        raise HTTPException(status_code=400, detail="Speech text cannot be empty.")

    if not settings.GROQ_API_KEY:
        # Fallback keyword parsing if Groq is unconfigured
        return _fallback_keyword_parse(speech_text, db)

    try:
        # Build context from DB models so LLM knows valid faculty, subjects, and rooms
        faculties = db.query(User).all()
        subjects = db.query(Subject).all()
        rooms = db.query(Room).all()

        faculty_list = [{"id": f.id, "name": f.full_name} for f in faculties]
        subject_list = [{"id": s.id, "name": s.name} for s in subjects]
        room_list = [{"id": r.id, "name": r.name} for r in rooms]

        system_instruction = f"""
You are the ENOSIS Speech Constraint Parser.
Your job is to convert natural language speech about college timetables into structured JSON constraints.

Valid Entities in Database:
Faculty list: {json.dumps(faculty_list)}
Subject list: {json.dumps(subject_list)}
Room list: {json.dumps(room_list)}

Supported constraint_type names:
- "faculty_unavailability" (requires: faculty_id, day, slot)
- "avoid_first_period" (requires: faculty_id)
- "avoid_last_period" (requires: faculty_id)
- "preferred_room" (requires: subject_id, room_id)
- "preferred_slot" (requires: subject_id, day, slot)

Format mapping for Days (0-indexed, Mon=0 ... Sat=5):
Monday=0, Tuesday=1, Wednesday=2, Thursday=3, Friday=4, Saturday=5.
Format mapping for Slots (0-indexed):
"slot 1" or "first period"=0, "slot 2" or "second period"=1, "lunch period" or "break"=no slot, etc.

Return a JSON object with:
{{
  "constraint": {{
    "constraint_type": "<type>",
    "priority": "hard" | "soft",
    "payload": {{ ... }},
    "description": "<Human-readable summary of constraint>"
  }},
  "parsed_successfully": true | false,
  "confirmation_message": "<Polite, concise confirmation or explanation of error>"
}}
If no constraint can be parsed, return parsed_successfully=false.
Return ONLY valid JSON, no markdown formatting blocks, no explanations outside JSON.
"""
        client = Groq(api_key=settings.GROQ_API_KEY)
        response = client.chat.completions.create(
            model=settings.GROQ_MODEL,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system_instruction},
                {"role": "user", "content": f"Speech: \"{speech_text}\""}
            ],
            temperature=0.0
        )
        
        reply_content = response.choices[0].message.content
        data = json.loads(reply_content)
        
        constraint_data = data.get("constraint")
        parsed_successfully = data.get("parsed_successfully", False)
        confirmation_message = data.get("confirmation_message", "Could not parse requirement.")

        constraint = None
        if parsed_successfully and constraint_data:
            constraint = ConstraintCreate(
                constraint_type=constraint_data["constraint_type"],
                priority=constraint_data.get("priority", "hard"),
                payload=constraint_data.get("payload", {}),
                description=constraint_data.get("description", "")
            )

        return ParseConstraintResponse(
            constraint=constraint,
            confirmation_message=confirmation_message,
            raw_text=speech_text,
            parsed_successfully=parsed_successfully
        )

    except Exception as e:
        logger.error(f"NLP parsing error: {e}")
        return _fallback_keyword_parse(speech_text, db)


def _fallback_keyword_parse(text: str, db: Session) -> ParseConstraintResponse:
    """Fallback rule-based string parsing when LLM is unavailable."""
    input_lower = text.lower().strip()
    if not input_lower:
        return ParseConstraintResponse(
            constraint=None,
            confirmation_message="Speech text was empty.",
            raw_text=text,
            parsed_successfully=False
        )

    faculties = db.query(User).all()
    subjects = db.query(Subject).all()
    rooms = db.query(Room).all()

    # Match Faculty
    matched_faculty = None
    for f in faculties:
        if f.full_name and f.full_name.lower() in input_lower:
            matched_faculty = f
            break
        # Also check partial names like "Priya" or "Sharma" if >= 4 chars
        if f.full_name:
            for part in f.full_name.lower().split():
                if len(part) >= 4 and part in input_lower:
                    matched_faculty = f
                    break
        if matched_faculty:
            break

    # Match Subject
    matched_subject = None
    for s in subjects:
        if s.name and (s.name.lower() in input_lower or (s.code and s.code.lower() in input_lower)):
            matched_subject = s
            break

    # Match Day (0=Mon ... 5=Sat)
    day = None
    days_map = {
        "monday": 0, "mon": 0,
        "tuesday": 1, "tue": 1,
        "wednesday": 2, "wed": 2,
        "thursday": 3, "thu": 3,
        "friday": 4, "fri": 4,
        "saturday": 5, "sat": 5
    }
    for d_name, d_idx in days_map.items():
        if d_name in input_lower:
            day = d_idx
            break

    # Match Slot (0-indexed)
    slot = None
    for i in range(1, 10):
        if f"slot {i}" in input_lower or f"period {i}" in input_lower or f"lecture {i}" in input_lower:
            slot = i - 1
            break
    if slot is None:
        if "1st" in input_lower or "first" in input_lower:
            slot = 0
        elif "2nd" in input_lower or "second" in input_lower:
            slot = 1
        elif "3rd" in input_lower or "third" in input_lower:
            slot = 2
        elif "4th" in input_lower or "fourth" in input_lower:
            slot = 3
        elif "5th" in input_lower or "fifth" in input_lower:
            slot = 4

    days_str = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    # 1. Avoid first period
    if ("avoid" in input_lower or "no " in input_lower or "don't" in input_lower) and ("first" in input_lower or "1st" in input_lower or "morning" in input_lower):
        if matched_faculty:
            desc = f"Avoid first period for {matched_faculty.full_name}"
            return ParseConstraintResponse(
                constraint=ConstraintCreate(
                    constraint_type="avoid_first_period",
                    priority="soft",
                    payload={"faculty_id": matched_faculty.id},
                    description=desc
                ),
                confirmation_message=f"Configured preference: {desc}.",
                raw_text=text,
                parsed_successfully=True
            )

    # 2. Avoid last period
    if ("avoid" in input_lower or "no " in input_lower or "don't" in input_lower) and ("last" in input_lower or "evening" in input_lower):
        if matched_faculty:
            desc = f"Avoid last period for {matched_faculty.full_name}"
            return ParseConstraintResponse(
                constraint=ConstraintCreate(
                    constraint_type="avoid_last_period",
                    priority="soft",
                    payload={"faculty_id": matched_faculty.id},
                    description=desc
                ),
                confirmation_message=f"Configured preference: {desc}.",
                raw_text=text,
                parsed_successfully=True
            )

    # 3. Faculty Unavailability
    if ("unavailable" in input_lower or "not available" in input_lower or "leave" in input_lower or "off" in input_lower) and matched_faculty:
        assigned_day = day if day is not None else 0
        assigned_slot = slot if slot is not None else 0
        desc = f"{matched_faculty.full_name} unavailable on {days_str[assigned_day]} Slot {assigned_slot + 1}"
        return ParseConstraintResponse(
            constraint=ConstraintCreate(
                constraint_type="faculty_unavailability",
                priority="hard",
                payload={"faculty_id": matched_faculty.id, "day": assigned_day, "slot": assigned_slot},
                description=desc
            ),
            confirmation_message=f"Configured unavailability: {desc}.",
            raw_text=text,
            parsed_successfully=True
        )

    # 4. Preferred Subject Slot / Fixed
    if matched_subject and day is not None and slot is not None:
        desc = f"Schedule {matched_subject.name} on {days_str[day]} Slot {slot + 1}"
        return ParseConstraintResponse(
            constraint=ConstraintCreate(
                constraint_type="preferred_slot",
                priority="soft",
                payload={"subject_id": matched_subject.id, "day": day, "slot": slot},
                description=desc
            ),
            confirmation_message=f"Configured preference: {desc}.",
            raw_text=text,
            parsed_successfully=True
        )

    # Unrecognized input (e.g. "hellow", "test")
    return ParseConstraintResponse(
        constraint=None,
        confirmation_message=f"Could not understand or extract a timetable constraint from: \"{text}\". Please specify a faculty or subject with day/slot (e.g., 'Dr. Priya Sharma is unavailable on Tuesday slot 1').",
        raw_text=text,
        parsed_successfully=False
    )

