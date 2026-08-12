import json
from unittest.mock import patch, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.academic import RoomType
from app.schemas.timetable import (
    TimetableGenerationRequest,
    SolverDivision,
    SolverSubject,
    SolverRoom,
    SolverAssignment,
    SolverUnavailability,
    SolverSoftConstraint,
    TimetableEntryResult,
)
from app.services.timetable_solver import generate_timetable
from app.services.timetable_validator import validate_generated_timetable

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Unit tests for Validator and Solver Extras
# ---------------------------------------------------------------------------

def test_independent_validator_passes():
    request = TimetableGenerationRequest(
        divisions=[SolverDivision(id="div-1", name="Div A", strength=60)],
        subjects=[SolverSubject(id="sub-1", name="Math", weekly_lectures=2, is_lab=False, lab_sessions_per_week=0, lab_block_size=0)],
        rooms=[SolverRoom(id="room-1", name="R101", type=RoomType.LECTURE, capacity=70)],
        assignments=[SolverAssignment(faculty_id="fac-1", subject_id="sub-1", division_id="div-1")],
        working_days=5,
        periods_per_day=8,
    )
    entries = [
        TimetableEntryResult(division_id="div-1", subject_id="sub-1", faculty_id="fac-1", room_id="room-1", day=0, slot=0),
        TimetableEntryResult(division_id="div-1", subject_id="sub-1", faculty_id="fac-1", room_id="room-1", day=1, slot=1),
    ]
    passed, conflicts = validate_generated_timetable(request, entries)
    assert passed
    assert len(conflicts) == 0


def test_independent_validator_fails_on_double_booking():
    request = TimetableGenerationRequest(
        divisions=[
            SolverDivision(id="div-1", name="Div A", strength=60),
            SolverDivision(id="div-2", name="Div B", strength=60),
        ],
        subjects=[SolverSubject(id="sub-1", name="Math", weekly_lectures=2, is_lab=False, lab_sessions_per_week=0, lab_block_size=0)],
        rooms=[SolverRoom(id="room-1", name="R101", type=RoomType.LECTURE, capacity=70)],
        assignments=[
            SolverAssignment(faculty_id="fac-1", subject_id="sub-1", division_id="div-1"),
            SolverAssignment(faculty_id="fac-1", subject_id="sub-1", division_id="div-2"),
        ],
        working_days=5,
        periods_per_day=8,
    )
    # Faculty is in two places at once!
    entries = [
        TimetableEntryResult(division_id="div-1", subject_id="sub-1", faculty_id="fac-1", room_id="room-1", day=0, slot=0),
        TimetableEntryResult(division_id="div-2", subject_id="sub-1", faculty_id="fac-1", room_id="room-1", day=0, slot=0),
    ]
    passed, conflicts = validate_generated_timetable(request, entries)
    assert not passed
    assert any(c.type == "validation_faculty_double_booked" for c in conflicts)


def test_independent_validator_fails_on_capacity_mismatch():
    request = TimetableGenerationRequest(
        divisions=[SolverDivision(id="div-1", name="Div A", strength=80)],
        subjects=[SolverSubject(id="sub-1", name="Math", weekly_lectures=1, is_lab=False, lab_sessions_per_week=0, lab_block_size=0)],
        rooms=[SolverRoom(id="room-1", name="R101", type=RoomType.LECTURE, capacity=50)], # Too small!
        assignments=[SolverAssignment(faculty_id="fac-1", subject_id="sub-1", division_id="div-1")],
    )
    entries = [
        TimetableEntryResult(division_id="div-1", subject_id="sub-1", faculty_id="fac-1", room_id="room-1", day=0, slot=0)
    ]
    passed, conflicts = validate_generated_timetable(request, entries)
    assert not passed
    assert any(c.type == "validation_capacity_mismatch" for c in conflicts)


# ---------------------------------------------------------------------------
# Integration tests for new endpoints
# ---------------------------------------------------------------------------

def test_schedule_config_endpoint(admin_token):
    headers = _auth_headers(admin_token)
    
    # 1. Get default config
    response = client.get("/timetable/schedule-config", headers=headers)
    assert response.status_code == 200
    assert response.json()["working_days"] in (5, 6)


    # 2. Update config
    update_data = {
        "working_days": 5,
        "day_names": ["Mon", "Tue", "Wed", "Thu", "Fri"],
        "periods_per_day": 7,
        "period_duration_minutes": 50,
        "start_time": "08:30",
        "break_slots": [3],
        "break_labels": {"3": "Lunch"},
        "time_limit_seconds": 15
    }
    response = client.post("/timetable/schedule-config", json=update_data, headers=headers)
    assert response.status_code == 200
    assert response.json()["periods_per_day"] == 7
    assert response.json()["break_slots"] == [3]


def test_constraints_crud_endpoints(admin_token):
    headers = _auth_headers(admin_token)
    
    # 1. Create constraint
    payload = {
        "constraint_type": "faculty_unavailability",
        "priority": "hard",
        "payload": {"faculty_id": "fac-temp-id", "day": 1, "slot": 3},
        "description": "Dr. Smith unavailable Tue Slot 4"
    }
    response = client.post("/timetable/constraints", json=payload, headers=headers)
    assert response.status_code == 201
    c_id = response.json()["id"]
    assert response.json()["priority"] == "hard"

    # 2. List constraints
    response = client.get("/timetable/constraints", headers=headers)
    assert response.status_code == 200
    assert any(c["id"] == c_id for c in response.json())

    # 3. Delete constraint
    response = client.delete(f"/timetable/constraints/{c_id}", headers=headers)
    assert response.status_code == 200
    
    # Verify deleted
    response = client.get("/timetable/constraints", headers=headers)
    assert not any(c["id"] == c_id for c in response.json())


def test_pre_validate_endpoint(admin_token):
    headers = _auth_headers(admin_token)
    response = client.get("/timetable/validate", headers=headers)
    assert response.status_code == 200
    assert "valid" in response.json()
    assert "conflicts" in response.json()


def test_generation_history_endpoint(admin_token):
    headers = _auth_headers(admin_token)
    response = client.get("/timetable/history", headers=headers)
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_voice_tts_endpoint(faculty_user):
    _, token = faculty_user
    payload = {
        "text": "Your timetable configuration is valid.",
        "role": "assistant"
    }
    
    # Mocking Edge-TTS since we don't have ElevenLabs key or edge-tts configured fully during headless tests
    with patch("app.api.routes.voice.HAS_EDGE_TTS", True), \
         patch("edge_tts.Communicate") as mock_comm:
        
        # Mock communicate.save to return successfully
        mock_comm.return_value.save = MagicMock()
        
        # Patch open to return fake mp3 bytes
        with patch("builtins.open", MagicMock(return_value=MagicMock(__enter__=MagicMock(return_value=MagicMock(read=lambda: b"fake-mp3-bytes"))))):
            response = client.post("/voice/tts", json=payload, headers=_auth_headers(token))
            
            # Should fall back cleanly or succeed
            assert response.status_code in (200, 503)


def test_voice_parse_constraint_endpoint(faculty_user):
    _, token = faculty_user
    payload = {
        "speech_text": "Dr. Priya Sharma is unavailable on Tuesday slot 1"
    }
    
    # NLP fallback mapping
    response = client.post("/voice/parse-constraint", json=payload, headers=_auth_headers(token))
    assert response.status_code == 200
    assert response.json()["parsed_successfully"] is True
    assert "unavailable" in response.json()["confirmation_message"]
