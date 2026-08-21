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
    SolverInstitutionalCourse,
    SolverSharedCourse,
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


def test_multi_lecture_subject_is_spread_across_different_days():
    """
    The specific bug being fixed: a subject meeting 3x/week must land on
    3 DIFFERENT days, not get crammed onto one day just because that's
    technically conflict-free. Uses a single division/subject/faculty so
    there's nothing else competing for room/slots — if the spread
    constraint weren't enforced, the solver would have no reason to avoid
    stacking all 3 on Monday.
    """
    request = TimetableGenerationRequest(
        divisions=[SolverDivision(id="div-A", name="TE-A", strength=60)],
        subjects=[
            SolverSubject(id="sub-daa", name="DAA", weekly_lectures=3, is_lab=False, lab_sessions_per_week=0, lab_block_size=2),
        ],
        rooms=[SolverRoom(id="room-301", name="Room 301", type=RoomType.LECTURE, capacity=70)],
        assignments=[SolverAssignment(faculty_id="fac-sharma", subject_id="sub-daa", division_id="div-A")],
        working_days=6,
        periods_per_day=6,
    )
    result = generate_timetable(request)
    assert result.status in ("OPTIMAL", "FEASIBLE")
    assert len(result.entries) == 3

    days_used = [e.day for e in result.entries]
    assert len(set(days_used)) == 3, f"Expected 3 distinct days, got {days_used}"


def test_spread_constraint_applies_per_division_independently():
    """Two divisions each having DAA 3x/week — the spread constraint is
    per (division, subject), so each division independently gets 3
    distinct days; they don't have to be the SAME 3 days as each other."""
    request = TimetableGenerationRequest(
        divisions=[
            SolverDivision(id="div-A", name="TE-A", strength=60),
            SolverDivision(id="div-B", name="TE-B", strength=60),
        ],
        subjects=[
            SolverSubject(id="sub-daa", name="DAA", weekly_lectures=3, is_lab=False, lab_sessions_per_week=0, lab_block_size=2),
        ],
        rooms=[
            SolverRoom(id="room-301", name="Room 301", type=RoomType.LECTURE, capacity=70),
            SolverRoom(id="room-302", name="Room 302", type=RoomType.LECTURE, capacity=70),
        ],
        assignments=[
            SolverAssignment(faculty_id="fac-sharma", subject_id="sub-daa", division_id="div-A"),
            SolverAssignment(faculty_id="fac-kumar", subject_id="sub-daa", division_id="div-B"),
        ],
        working_days=6,
        periods_per_day=6,
    )
    result = generate_timetable(request)
    assert result.status in ("OPTIMAL", "FEASIBLE")

    for division_id in ("div-A", "div-B"):
        days_used = [e.day for e in result.entries if e.division_id == division_id]
        assert len(set(days_used)) == 3, f"{division_id}: expected 3 distinct days, got {days_used}"


def test_institutional_fixed_course_constraint():
    request = TimetableGenerationRequest(
        divisions=[SolverDivision(id="div-A", name="TE-A", strength=60)],
        subjects=[SolverSubject(id="sub-daa", name="DAA", weekly_lectures=1, is_lab=False, lab_sessions_per_week=0, lab_block_size=1)],
        rooms=[SolverRoom(id="room-301", name="Room 301", type=RoomType.LECTURE, capacity=70)],
        assignments=[SolverAssignment(faculty_id="fac-sharma", subject_id="sub-daa", division_id="div-A")],
        institutional_courses=[
            SolverInstitutionalCourse(
                course_name="Professional Ethics",
                course_code="PE101",
                year=1,
                divisions=["TE-A"],
                day=1,          # Tuesday
                start_slot=2,   # Period 2
                duration_slots=1,
                faculty_id="fac-guest",
                room_id="room-301"
            )
        ],
        working_days=5,
        periods_per_day=4,
    )
    result = generate_timetable(request)
    assert result.status in ("OPTIMAL", "FEASIBLE")
    
    # Verify professional ethics is in the output entries
    ethics_entries = [e for e in result.entries if e.day == 1 and e.slot == 2]
    assert len(ethics_entries) == 1
    # Verify no other course is scheduled in Division A at Day 1, Slot 2
    div_a_ethics = [e for e in result.entries if e.division_id == "div-a" and e.day == 1 and e.slot == 2]
    # (Pydantic models lower-case the ID or keep div-A, let's check case-insensitive)
    div_a_ethics = [e for e in result.entries if e.division_id.lower() == "div-a" and e.day == 1 and e.slot == 2]
    assert len(div_a_ethics) == 1


def test_shared_course_constraint():
    # Two divisions attend same lecture together (same day, same slot, same room)
    request = TimetableGenerationRequest(
        divisions=[
            SolverDivision(id="div-A", name="TE-A", strength=30),
            SolverDivision(id="div-B", name="TE-B", strength=30),
        ],
        subjects=[],
        rooms=[SolverRoom(id="room-large", name="Large Room", type=RoomType.LECTURE, capacity=70)],
        assignments=[],
        shared_courses=[
            SolverSharedCourse(
                id="sc-ai",
                course_name="Advanced AI",
                course_code="CS401",
                year=1,
                divisions=["TE-A", "TE-B"],
                faculty_id="fac-kumar",
                room_id="room-large",
                duration_slots=1,
                weekly_sessions=2,
                session_type="lecture"
            )
        ],
        working_days=5,
        periods_per_day=4,
    )
    result = generate_timetable(request)
    assert result.status in ("OPTIMAL", "FEASIBLE")
    
    # We expect 4 entries total (2 sessions * 2 divisions)
    assert len(result.entries) == 4
    
    # Verify they run simultaneously in the same room
    slots = {}
    for entry in result.entries:
        # Group by division or day-slot
        slots.setdefault((entry.day, entry.slot), []).append(entry)
        
    # There should be exactly 2 occupied time slots
    assert len(slots) == 2
    for slot_entries in slots.values():
        assert len(slot_entries) == 2
        # Both must use large room
        assert slot_entries[0].room_id == "room-large"
        assert slot_entries[1].room_id == "room-large"
        # They must belong to TE-A and TE-B respectively
        div_ids = {e.division_id.lower() for e in slot_entries}
        assert "div-a" in div_ids
        assert "div-b" in div_ids


def test_simultaneous_course_group_constraint():
    # Two electives under same main name "MDM" run at the same time but in different rooms
    request = TimetableGenerationRequest(
        divisions=[
            SolverDivision(id="div-A", name="TE-A", strength=30),
            SolverDivision(id="div-B", name="TE-B", strength=30),
        ],
        subjects=[],
        rooms=[
            SolverRoom(id="room-1", name="R101", type=RoomType.LECTURE, capacity=40),
            SolverRoom(id="room-2", name="R102", type=RoomType.LECTURE, capacity=40),
        ],
        assignments=[],
        shared_courses=[
            # MDM elective 1 for division A
            SolverSharedCourse(
                id="sc-mdm1",
                course_name="MDM",
                course_code="MDM-1",
                year=1,
                divisions=["TE-A"],
                faculty_id="fac-x",
                room_id="room-1",
                duration_slots=1,
                weekly_sessions=1,
                session_type="lecture"
            ),
            # MDM elective 2 for division B
            SolverSharedCourse(
                id="sc-mdm2",
                course_name="MDM",
                course_code="MDM-2",
                year=1,
                divisions=["TE-B"],
                faculty_id="fac-y",
                room_id="room-2",
                duration_slots=1,
                weekly_sessions=1,
                session_type="lecture"
            ),
        ],
        working_days=5,
        periods_per_day=4,
    )
    result = generate_timetable(request)
    assert result.status in ("OPTIMAL", "FEASIBLE")
    
    # We expect 2 entries total
    assert len(result.entries) == 2
    # Verify they run at the exact same day and slot
    assert result.entries[0].day == result.entries[1].day
    assert result.entries[0].slot == result.entries[1].slot
    # They should use different rooms and divisions
    assert result.entries[0].room_id != result.entries[1].room_id
    assert result.entries[0].division_id != result.entries[1].division_id
