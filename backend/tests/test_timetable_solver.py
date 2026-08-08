"""
Unit tests for the timetable solver itself — deliberately no database, no
FastAPI, no HTTP. Just plain Pydantic objects in, plain Pydantic objects
out. This proves the solver is correct independent of everything else.

Run with: pytest tests/test_timetable_solver.py -v
"""
from app.models.academic import RoomType
from app.schemas.timetable import (
    TimetableGenerationRequest,
    SolverDivision,
    SolverSubject,
    SolverRoom,
    SolverAssignment,
    SolverUnavailability,
)
from app.services.timetable_solver import generate_timetable


def _small_scenario() -> TimetableGenerationRequest:
    """
    A small, realistic scenario: 2 divisions, 3 subjects (one is a lab),
    2 faculty, 2 lecture rooms + 1 lab. Small enough to solve instantly,
    big enough to actually exercise every constraint type.
    """
    return TimetableGenerationRequest(
        divisions=[
            SolverDivision(id="div-A", name="TE-A", strength=60),
            SolverDivision(id="div-B", name="TE-B", strength=55),
        ],
        subjects=[
            SolverSubject(id="sub-daa", name="DAA", weekly_lectures=3, is_lab=False, lab_sessions_per_week=0, lab_block_size=2),
            SolverSubject(id="sub-dbms", name="DBMS", weekly_lectures=2, is_lab=True, lab_sessions_per_week=1, lab_block_size=2),
            SolverSubject(id="sub-os", name="Operating Systems", weekly_lectures=3, is_lab=False, lab_sessions_per_week=0, lab_block_size=2),
        ],
        rooms=[
            SolverRoom(id="room-301", name="Room 301", type=RoomType.LECTURE, capacity=70),
            SolverRoom(id="room-302", name="Room 302", type=RoomType.LECTURE, capacity=70),
            SolverRoom(id="lab-1", name="Lab 1", type=RoomType.LAB, capacity=70),
        ],
        assignments=[
            # Dr. Sharma teaches DAA to A, DBMS to A
            SolverAssignment(faculty_id="fac-sharma", subject_id="sub-daa", division_id="div-A"),
            SolverAssignment(faculty_id="fac-sharma", subject_id="sub-dbms", division_id="div-A"),
            # Dr. Kumar teaches OS to A, DAA to B, OS to B
            SolverAssignment(faculty_id="fac-kumar", subject_id="sub-os", division_id="div-A"),
            SolverAssignment(faculty_id="fac-kumar", subject_id="sub-daa", division_id="div-B"),
            SolverAssignment(faculty_id="fac-kumar", subject_id="sub-os", division_id="div-B"),
            # Dr. Sharma also teaches DBMS to B
            SolverAssignment(faculty_id="fac-sharma", subject_id="sub-dbms", division_id="div-B"),
        ],
        unavailability=[
            # Dr. Kumar is unavailable Monday morning (day 0, slots 0-1)
            SolverUnavailability(faculty_id="fac-kumar", day=0, slot=0),
            SolverUnavailability(faculty_id="fac-kumar", day=0, slot=1),
        ],
        working_days=6,
        periods_per_day=6,
        max_lectures_per_day_per_faculty=4,
        time_limit_seconds=15,
    )


def test_solver_finds_a_feasible_timetable():
    result = generate_timetable(_small_scenario())
    assert result.status in ("OPTIMAL", "FEASIBLE")
    assert len(result.entries) > 0


def test_solver_produces_correct_number_of_entries():
    """
    div-A: DAA(3) + DBMS lectures(2) + DBMS lab(1 session x 2 slots) + OS(3) = 3+2+2+3 = 10 slot-entries
    div-B: DAA(3) + DBMS lectures(2) + DBMS lab(2 slots) + OS(3) = 10 slot-entries
    Total expected slot-entries = 20
    """
    result = generate_timetable(_small_scenario())
    assert result.status in ("OPTIMAL", "FEASIBLE")
    assert len(result.entries) == 20


def test_no_faculty_double_booked():
    result = generate_timetable(_small_scenario())
    assert result.status in ("OPTIMAL", "FEASIBLE")

    seen = set()
    for entry in result.entries:
        key = (entry.faculty_id, entry.day, entry.slot)
        assert key not in seen, f"Faculty {entry.faculty_id} double-booked at day {entry.day} slot {entry.slot}"
        seen.add(key)


def test_no_division_double_booked():
    result = generate_timetable(_small_scenario())
    assert result.status in ("OPTIMAL", "FEASIBLE")

    seen = set()
    for entry in result.entries:
        key = (entry.division_id, entry.day, entry.slot)
        assert key not in seen, f"Division {entry.division_id} double-booked at day {entry.day} slot {entry.slot}"
        seen.add(key)


def test_no_room_double_booked():
    result = generate_timetable(_small_scenario())
    assert result.status in ("OPTIMAL", "FEASIBLE")

    seen = set()
    for entry in result.entries:
        key = (entry.room_id, entry.day, entry.slot)
        assert key not in seen, f"Room {entry.room_id} double-booked at day {entry.day} slot {entry.slot}"
        seen.add(key)


def test_faculty_unavailability_is_respected():
    result = generate_timetable(_small_scenario())
    assert result.status in ("OPTIMAL", "FEASIBLE")

    for entry in result.entries:
        if entry.faculty_id == "fac-kumar":
            assert not (entry.day == 0 and entry.slot in (0, 1)), \
                "Dr. Kumar was scheduled during a declared-unavailable slot"


def test_lab_sessions_use_lab_rooms_and_are_consecutive():
    result = generate_timetable(_small_scenario())
    assert result.status in ("OPTIMAL", "FEASIBLE")

    lab_entries = [e for e in result.entries if e.is_lab_block]
    assert len(lab_entries) == 4  # 2 lab sessions x 2 slots each (div-A + div-B)

    for e in lab_entries:
        assert e.room_id == "lab-1", "Lab session wasn't placed in a lab-type room"

    # Group lab slots by (division, subject, day) and check they're consecutive
    from collections import defaultdict
    grouped = defaultdict(list)
    for e in lab_entries:
        grouped[(e.division_id, e.subject_id, e.day)].append(e.slot)

    for key, slots in grouped.items():
        slots.sort()
        assert slots == list(range(slots[0], slots[0] + len(slots))), \
            f"Lab slots for {key} aren't consecutive: {slots}"


def test_infeasible_when_no_compatible_room_exists():
    """A lab subject with zero lab-type rooms available must be reported
    as INFEASIBLE with a helpful message, not crash or silently drop it."""
    request = TimetableGenerationRequest(
        divisions=[SolverDivision(id="div-A", name="TE-A", strength=60)],
        subjects=[SolverSubject(id="sub-dbms", name="DBMS", weekly_lectures=0, is_lab=True, lab_sessions_per_week=1, lab_block_size=2)],
        rooms=[SolverRoom(id="room-301", name="Room 301", type=RoomType.LECTURE, capacity=70)],  # no LAB room!
        assignments=[SolverAssignment(faculty_id="fac-sharma", subject_id="sub-dbms", division_id="div-A")],
    )
    result = generate_timetable(request)
    assert result.status == "INFEASIBLE"
    assert result.message is not None


def test_empty_input_reports_infeasible_not_a_crash():
    request = TimetableGenerationRequest(divisions=[], subjects=[], rooms=[], assignments=[])
    result = generate_timetable(request)
    assert result.status == "INFEASIBLE"
    assert result.entries == []
