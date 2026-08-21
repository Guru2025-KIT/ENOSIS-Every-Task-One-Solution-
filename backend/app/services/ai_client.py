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


def send_chat_message(message: str, timetable_context: str = "") -> str:
    """
    Sends a user message to Groq's chat completion API instructing it
    to return a JSON object with a friendly explanation and structured
    swap delta parameters, using the active database timetable state as context.
    """
    client = Groq(api_key=settings.GROQ_API_KEY)
    
    system_prompt = (
        "You are the ENOSIS Timetable Assistant. You help college faculty swap classes.\n"
        "Here is the CURRENT active timetable schedule locked in the database:\n"
        "=========================================\n"
        f"{timetable_context}\n"
        "=========================================\n\n"
        "You MUST respond with a JSON object containing two fields:\n"
        "1. 'reply': A friendly, concise message explaining the response.\n"
        "2. 'delta': If the user asks to move, shift, reschedule, or swap a class, "
        "provide a dictionary with the following keys:\n"
        "   - 'course_name': name of the course/subject to swap\n"
        "   - 'day_from': current day index (0 for Mon, 1 for Tue, 2 for Wed, 3 for Thu, 4 for Fri, 5 for Sat)\n"
        "   - 'slot_from': current slot index (0 to 7)\n"
        "   - 'day_to': target day index (0 to 5)\n"
        "   - 'slot_to': target slot index (0 to 7)\n"
        "   - 'division': division code (e.g. 'A' or 'B')\n"
        "If the user is NOT requesting a reschedule/swap, set 'delta' to null.\n"
        "Ensure that course_name, day_from, slot_from, and division match the actual current schedule provided in the context above!\n"
        "Example JSON:\n"
        "{\n"
        "  \"reply\": \"I propose shifting DAA from Tuesday Slot 1 to Friday Slot 4.\",\n"
        "  \"delta\": {\n"
        "    \"course_name\": \"DAA\",\n"
        "    \"day_from\": 1,\n"
        "    \"slot_from\": 0,\n"
        "    \"day_to\": 4,\n"
        "    \"slot_to\": 3,\n"
        "    \"division\": \"A\"\n"
        "  }\n"
        "}"
    )

    response = client.chat.completions.create(
        model=settings.GROQ_MODEL,
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": system_prompt,
            },
            {"role": "user", "content": message},
        ],
    )
    return response.choices[0].message.content
