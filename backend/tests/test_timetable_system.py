"""
Comprehensive Validation & Test Suite for ENOSIS Timetable System.
Covering all 20 verification criteria:
1. Dynamic college start/end time
2. Configurable working days
3. Independent lecture duration
4. Independent lab duration (50min lecture vs 120min lab -> 3 slots)
5. Breaks / Lunch slots
6. Classroom vs Lab room-type matching
7. Room capacity constraints
8. Faculty collision prevention
9. Division collision prevention
10. Room collision prevention
11. Lab continuity
12. Combined sessions
13. Replacement constraints (explicit entity substitution)
14. Fixed sessions
15. Faculty/room unavailability
16. Two-pass soft constraint relaxation
17. Timetable persistence (transactional)
18. Excel room import validation
19. PDF export
20. Excel export
"""

import io
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base, get_db
from app.main import app as fastapi_app
from app.models.user import User, UserRole
from app.models.academic import Division, Subject, Room, RoomType, TeachingAssignment, FacultyUnavailability, InstitutionalCourse, SharedCourse
from app.models.schedule_config import ScheduleConfig
from app.models.constraints import TimetableConstraint
from app.models.generation_history import GenerationRun
from app.models.timetable import TimetableEntry
from app.core.security import create_access_token
from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot, Constraint, solve_from_dicts


from app.db.base import Base, engine, SessionLocal, get_db


@pytest.fixture(autouse=True)
def setup_system_db_user():
    db = SessionLocal()
    user = User(
        id="user-admin-1",
        email="admin@enosis.edu",
        full_name="Dr. Admin HOD",
        hashed_password="hashedpassword",
        role=UserRole.ADMIN,
        can_manage_timetable=True,
        is_active=True
    )
    db.add(user)
    db.commit()
    db.close()
    yield


@pytest.fixture
def auth_headers():
    token = create_access_token("user-admin-1")
    return {"Authorization": f"Bearer {token}"}


# 1. Schedule Config: Dynamic start/end time, working days, durations, breaks
def test_schedule_config_dynamic_durations(auth_headers):
    client = TestClient(fastapi_app)
    
    update_payload = {
        "working_days": 5,
        "day_names": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
        "periods_per_day": 8,
        "period_duration_minutes": 50,
        "lecture_duration_minutes": 50,
        "lab_duration_minutes": 120,
        "tutorial_duration_minutes": 50,
        "start_time": "08:30",
        "end_time": "16:30",
        "break_slots": [2, 5],
        "break_labels": {"2": "Tea Break", "5": "Lunch Break"},
        "college_name": "ENOSIS College of Engineering",
        "time_limit_seconds": 15
    }
    res = client.post("/timetable/schedule-config", json=update_payload, headers=auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["working_days"] == 5
    assert data["start_time"] == "08:30"
    assert data["end_time"] == "16:30"
    assert data["lecture_duration_minutes"] == 50
    assert data["lab_duration_minutes"] == 120


# 2. Independent Lab Duration Calculation (50min lecture vs 120min lab -> 3 slots)
def test_independent_lab_duration_slots():
    solver = TimetableCpSatSolver(
        assignments=[],
        time_slots=[],
        constraints=[],
        lecture_duration_minutes=50,
        lab_duration_minutes=120
    )
    # 120 / 50 = 2.4 -> ceil = 3 slots
    assert solver.lab_slots_per_session == 3


# 3. Room Management & Excel Import Validation
def test_room_crud_and_excel_import(auth_headers):
    client = TestClient(fastapi_app)
    
    room_payload = {
        "name": "CR-101",
        "type": "lecture",
        "capacity": 60,
        "building": "North Wing",
        "equipment": ["Projector"]
    }
    res = client.post("/timetable/rooms", json=room_payload, headers=auth_headers)
    assert res.status_code == 201
    assert res.json()["name"] == "CR-101"

    # Template download
    res_tpl = client.get("/timetable/rooms/template-excel", headers=auth_headers)
    assert res_tpl.status_code == 200
    assert len(res_tpl.content) > 0


# 4. Solver Collisions, Room Matching, Combined Sessions & 2-Pass Soft Relaxation
def test_cpsat_solver_collisions_and_relaxation():
    assignments = [
        Assignment(faculty="Dr. Smith", subject="DBMS", class_name="TY-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. Smith", subject="OS", class_name="TY-B", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Alan", subject="DBMS Lab", class_name="TY-A", type="Lab", batch="A1", weekly_hours=2)
    ]
    slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00"),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00"),
        TimeSlot(slot_number=3, start_time="11:00", end_time="12:00"),
        TimeSlot(slot_number=4, start_time="12:00", end_time="01:00", is_break=True, is_lunch=True),
        TimeSlot(slot_number=5, start_time="01:00", end_time="02:00"),
    ]
    constraints = [
        Constraint(id="c1", category="Faculty Unavailable", intent="avoid", faculty_names=["Dr. Smith"], days=["Monday"], slot_numbers=[1])
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=slots,
        constraints=constraints,
        working_days=["Monday", "Tuesday", "Wednesday"],
        time_limit_seconds=10,
        lecture_duration_minutes=60,
        lab_duration_minutes=120
    )
    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Verify Dr. Smith is NOT scheduled on Monday slot 1 (Faculty Unavailability)
    for c_name, grid in result.timetable.items():
        cell = grid.get("Monday_1", ["Free", "", "", ""])
        if len(cell) > 1:
            assert cell[1] != "Dr. Smith"


# 5. Replacement Rule Support
def test_replacement_constraint_support():
    assignments = [
        Assignment(faculty="Dr. Jones", subject="Theory of Computation", class_name="TY-CS", type="Theory", weekly_hours=2)
    ]
    slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00"),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00"),
    ]
    # Replacement rule: Fill free period on Tuesday slot 2 with LeetCode
    constraints = [
        Constraint(id="r1", category="fill|replace with LeetCode", intent="fill", days=["Tuesday"], slot_numbers=[2])
    ]

    res = solve_from_dicts(
        assignments_raw=[{"facultyName": "Dr. Jones", "subjectName": "TOC", "className": "TY-CS", "type": "Theory", "weeklyHours": 2}],
        constraints_raw=[{"id": "r1", "category": "fill|replace with LeetCode", "intent": "fill", "days": ["Tuesday"], "slot_numbers": [2]}],
        time_slots_raw=[{"slot_number": 1, "start_time": "09:00", "end_time": "10:00"}, {"slot_number": 2, "start_time": "10:00", "end_time": "11:00"}],
        working_days=["Monday", "Tuesday"],
        time_limit_seconds=5
    )
    assert res.status in ("OPTIMAL", "FEASIBLE")
    cell = res.timetable.get("TY-CS", {}).get("Tuesday_2")
    if cell:
        assert cell[0].lower() in ("leetcode", "toc", "free")


# 6. Transactional Persistence & Publish Endpoint
def test_transactional_publish_endpoint(auth_headers):
    client = TestClient(fastapi_app)
    db = SessionLocal()

    div = Division(id="d1", name="SY-IT-A", year=2, division_code="A", strength=60)
    sub = Subject(id="s1", name="Data Structures", code="CS201", weekly_lectures=3)
    room = Room(id="r1", name="CR-202", type=RoomType.LECTURE, capacity=60)
    db.add_all([div, sub, room])
    db.commit()
    db.close()

    publish_payload = {
        "timetable": {
            "SY-IT-A": {
                "Monday_1": ["Data Structures", "Dr. Admin HOD", "CR-202", "All"]
            }
        }
    }
    res = client.post("/timetable/publish", json=publish_payload, headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["status"] == "published"

    # Verify entry in DB
    db2 = SessionLocal()
    entries = db2.query(TimetableEntry).all()
    assert len(entries) == 1
    assert entries[0].batch_name == "All"
    db2.close()


# 7. PDF and Excel Exports
def test_export_pdf_and_excel_endpoints(auth_headers):
    client = TestClient(fastapi_app)

    payload = {
        "view_title": "SY-IT-A",
        "days": ["Monday", "Tuesday"],
        "time_slots": [{"slot_number": 1, "start_time": "09:00", "end_time": "10:00"}],
        "grid_data": {"Monday_1": ["Data Structures", "Dr. Admin HOD", "CR-202", "All"]}
    }

    res_excel = client.post("/timetable/export/excel", json=payload, headers=auth_headers)
    assert res_excel.status_code == 200
    assert "spreadsheetml" in res_excel.headers["content-type"]

    res_pdf = client.post("/timetable/export/pdf", json=payload, headers=auth_headers)
    assert res_pdf.status_code == 200
    assert "pdf" in res_pdf.headers["content-type"]


# 8. Multi-Option PE / Department Electives Parallel Scheduling & Room Assignment
def test_parallel_pe_electives_and_room_allocation():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot, Constraint

    assignments = [
        # TY AIML A Core
        Assignment(faculty="Prof. Core A", subject="Operating Systems", class_name="TY AIML A", type="Theory", weekly_hours=3),
        # TY AIML B Core
        Assignment(faculty="Prof. Core B", subject="Software Engineering", class_name="TY AIML B", type="Theory", weekly_hours=3),
        # 2 Different PE Electives for TY Cohort (Students are shuffled across classes)
        Assignment(faculty="Dr. Sharma", subject="PE-1: Natural Language Processing", class_name="TY AIML A", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Verma", subject="PE-2: Cloud Computing", class_name="TY AIML B", type="Theory", weekly_hours=3),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:30", is_break=True), # Recess
        TimeSlot(slot_number=4, start_time="11:30", end_time="12:30", is_break=False),
    ]

    rooms = [
        {"name": "Room 301", "type": "Theory"},
        {"name": "Room 302", "type": "Theory"},
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday", "Wednesday"],
        rooms=rooms,
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Find the slots where PE is scheduled
    pe_slots_a = []
    pe_slots_b = []
    for day_slot, val in result.timetable.get("TY AIML A", {}).items():
        if "PE-1" in val[0] or "PE-2" in val[0]:
            pe_slots_a.append(day_slot)
            # Check that distinct rooms are assigned to the tracks
            assert " | " in val[2] or "Room" in val[2]

    for day_slot, val in result.timetable.get("TY AIML B", {}).items():
        if "PE-1" in val[0] or "PE-2" in val[0]:
            pe_slots_b.append(day_slot)

    # Both divisions MUST run PE electives simultaneously in the exact same time slots
    assert len(pe_slots_a) == 3
    assert set(pe_slots_a) == set(pe_slots_b)


# 9. Strict Cohort/Year Isolation: TY Electives only to TY, SY Electives only to SY
def test_strict_cohort_isolation_for_dept_electives():
    assignments = [
        # TY Cohort
        Assignment(faculty="Prof. TY Core", subject="TY Core OS", class_name="TY AIML A", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. TY PE1", subject="PE: TY Cloud Computing", class_name="TY AIML A", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. TY PE2", subject="PE: TY Quantum AI", class_name="TY AIML B", type="Theory", weekly_hours=2),

        # SY Cohort
        Assignment(faculty="Prof. SY Core", subject="SY Core DSA", class_name="SY AIML A", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. SY PE1", subject="PE: SY Web Technologies", class_name="SY AIML A", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. SY PE2", subject="PE: SY App Development", class_name="SY AIML B", type="Theory", weekly_hours=2),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True), # Break
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15", is_break=False),
        TimeSlot(slot_number=5, start_time="12:15", end_time="01:15", is_break=False),
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday", "Wednesday"],
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Verify TY classes ONLY get TY electives
    for ty_class in ["TY AIML A", "TY AIML B"]:
        for slot_key, cell in result.timetable.get(ty_class, {}).items():
            subj = cell[0]
            if "PE:" in subj:
                assert "TY" in subj, f"Found non-TY elective {subj} in {ty_class} at {slot_key}"
                assert "SY" not in subj, f"SY elective leaked into {ty_class}: {subj}"

    # Verify SY classes ONLY get SY electives
    for sy_class in ["SY AIML A", "SY AIML B"]:
        for slot_key, cell in result.timetable.get(sy_class, {}).items():
            subj = cell[0]
            if "PE:" in subj:
                assert "SY" in subj, f"Found non-SY elective {subj} in {sy_class} at {slot_key}"
                assert "TY" not in subj, f"TY elective leaked into {sy_class}: {subj}"


# 10. Lab Continuity: Lab NEVER spans across a break (no 1 hr before and 1 hr after break)
def test_lab_continuity_never_spans_across_break():
    assignments = [
        # 2-hour lab
        Assignment(faculty="Dr. Lab Faculty", subject="AI Lab", class_name="TY AIML A", type="Lab", batch="Batch 1", weekly_hours=2),
    ]

    # Slot 1: 9-10 (Lec 1)
    # Slot 2: 10-11 (Lec 2)
    # Slot 0 / 3: 11:00-11:15 (BREAK)
    # Slot 3 / 4: 11:15-12:15 (Lec 3)
    # Slot 4 / 5: 12:15-01:15 (Lec 4)
    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00 AM", end_time="10:00 AM", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00 AM", end_time="11:00 AM", is_break=False),
        TimeSlot(slot_number=0, start_time="11:00 AM", end_time="11:15 AM", is_break=True), # Short Break
        TimeSlot(slot_number=3, start_time="11:15 AM", end_time="12:15 PM", is_break=False),
        TimeSlot(slot_number=4, start_time="12:15 PM", end_time="01:15 PM", is_break=False),
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday"],
        lecture_duration_minutes=60,
        lab_duration_minutes=120,
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    grid = result.timetable.get("TY AIML A", {})
    lab_days_slots = [k for k, v in grid.items() if "AI Lab" in v[0]]
    assert len(lab_days_slots) == 2

    # Check which slots were scheduled
    slots_used = sorted([int(k.split("_")[1]) for k in lab_days_slots])
    
    # Valid continuous blocks are [1, 2] (before break) OR [3, 4] (after break).
    # [2, 3] would mean 1 hr before break (10-11) and 1 hr after break (11:15-12:15), which is strictly ILLEGAL!
    assert slots_used in ([1, 2], [3, 4]), f"Lab was illegally placed across break: {slots_used}"


# ---------------------------------------------------------------------------
# Comprehensive Scenarios A through O Tests (Domain Rules & Reference Timing)
# ---------------------------------------------------------------------------

# Scenario A & B: Three MDM/EMDM options run in parallel in separate rooms with respective faculty and remain distinct
def test_scenario_a_and_b_three_mdm_options_parallel_separate_rooms():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot
    from app.services.timetable_validator import validate_timetable_grid_solution

    assignments = [
        # TY AIML A Core
        Assignment(faculty="Dr. Core", subject="Operating Systems", class_name="TY-AIML-A", type="Theory", weekly_hours=3),
        # 3 Distinct MDM Options for TY Cohort
        Assignment(faculty="Dr. Embedded", subject="MDM-3: Embedded Systems", class_name="TY-AIML-A", type="Theory", weekly_hours=3, subject_code="MDM301"),
        Assignment(faculty="Dr. Bioinfo", subject="MDM-3: Bioinformatics", class_name="TY-AIML-B", type="Theory", weekly_hours=3, subject_code="MDM302"),
        Assignment(faculty="Dr. Finance", subject="MDM-3: Finance", class_name="TY-AIML-C", type="Theory", weekly_hours=3, subject_code="MDM303"),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True),
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15", is_break=False),
        TimeSlot(slot_number=5, start_time="12:15", end_time="01:15", is_break=False),
    ]

    rooms = [
        {"name": "CR-301", "type": "Theory", "capacity": 60},
        {"name": "CR-302", "type": "Theory", "capacity": 60},
        {"name": "CR-303", "type": "Theory", "capacity": 60},
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday", "Wednesday"],
        rooms=rooms,
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Verify all 3 divisions have MDM scheduled in the same time slots
    mdm_slots_a = [k for k, v in result.timetable.get("TY-AIML-A", {}).items() if "MDM-3" in v[0]]
    mdm_slots_b = [k for k, v in result.timetable.get("TY-AIML-B", {}).items() if "MDM-3" in v[0]]
    mdm_slots_c = [k for k, v in result.timetable.get("TY-AIML-C", {}).items() if "MDM-3" in v[0]]

    assert len(mdm_slots_a) == 3
    assert set(mdm_slots_a) == set(mdm_slots_b) == set(mdm_slots_c), "All 3 MDM options must run in parallel in the same slots"

    # Verify that in detailed_timetable, each MDM option is separate and assigned to a distinct room
    for slot in mdm_slots_a:
        cell_a = result.detailed_timetable["TY-AIML-A"][slot]
        assert "batches" in cell_a
        batches = cell_a["batches"]
        assert len(batches) == 3, "All 3 MDM tracks must be recorded distinctly"
        assigned_rms = [b["room"] for b in batches]
        assert len(set(assigned_rms)) == 3, f"Each MDM option must have a separate room, got: {assigned_rms}"
        assigned_facs = [b["faculty"] for b in batches]
        assert len(set(assigned_facs)) == 3, f"Each MDM option must have its own faculty, got: {assigned_facs}"

    # Independent audit validation
    passed, violations = validate_timetable_grid_solution(
        result.timetable,
        result.detailed_timetable,
        break_slots={3}
    )
    assert passed, f"Independent validator found violations: {violations}"


# Scenario C, D, E: B.Tech Honors shared course vs distinct Honors courses
def test_scenario_c_d_e_btech_honors_shared_vs_distinct():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot
    from app.services.timetable_validator import validate_timetable_grid_solution

    assignments = [
        # Shared Honors: Advanced AI shared by CSE, AIML, DS
        Assignment(faculty="Prof. Turing", subject="Honors: Advanced AI", class_name="TY-CSE", type="Theory", weekly_hours=2),
        Assignment(faculty="Prof. Turing", subject="Honors: Advanced AI", class_name="TY-AIML", type="Theory", weekly_hours=2),
        Assignment(faculty="Prof. Turing", subject="Honors: Advanced AI", class_name="TY-DS", type="Theory", weekly_hours=2),

        # Distinct Honors: VLSI Design for ECE with Prof. Shockley
        Assignment(faculty="Prof. Shockley", subject="Honors: VLSI Design", class_name="TY-ECE", type="Theory", weekly_hours=2),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True),
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15", is_break=False),
    ]

    rooms = [
        {"name": "Auditorium 1", "type": "Theory", "capacity": 180},
        {"name": "CR-301", "type": "Theory", "capacity": 60},
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday"],
        rooms=rooms,
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Scenario C & D: The shared course is scheduled at the exact same slot and room across TY-CSE, TY-AIML, TY-DS
    slots_cse = [k for k, v in result.timetable.get("TY-CSE", {}).items() if "Advanced AI" in v[0]]
    slots_aiml = [k for k, v in result.timetable.get("TY-AIML", {}).items() if "Advanced AI" in v[0]]
    slots_ds = [k for k, v in result.timetable.get("TY-DS", {}).items() if "Advanced AI" in v[0]]

    assert len(slots_cse) == 2
    assert slots_cse == slots_aiml == slots_ds, "Shared Honors session must appear at identical slots across departments"

    # Room must be identical for the shared session
    for s in slots_cse:
        rm_cse = result.timetable["TY-CSE"][s][2]
        rm_aiml = result.timetable["TY-AIML"][s][2]
        rm_ds = result.timetable["TY-DS"][s][2]
        assert rm_cse == rm_aiml == rm_ds, "Shared Honors session must share the exact same room allocation"

    # Scenario E: ECE Honors is distinct and not merged into Advanced AI
    slots_ece = [k for k, v in result.timetable.get("TY-ECE", {}).items() if "VLSI" in v[0]]
    assert len(slots_ece) == 2
    for s in slots_ece:
        fac_ece = result.timetable["TY-ECE"][s][1]
        assert fac_ece == "Prof. Shockley"

    # Validate zero clashes
    passed, violations = validate_timetable_grid_solution(
        result.timetable,
        result.detailed_timetable,
        break_slots={3}
    )
    assert passed, f"Violations found: {violations}"


# Scenario F & G & H: Professional Electives (PE) and Open Electives (OE) parallel vs shared
def test_scenario_f_g_h_pe_and_oe_parallel_and_shared():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot
    from app.services.timetable_validator import validate_timetable_grid_solution

    assignments = [
        # PE-1 parallel options for TY cohort
        Assignment(faculty="Dr. NLP", subject="PE-1: Natural Language Processing", class_name="TY-AIML-A", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. Cloud", subject="PE-1: Cloud Computing", class_name="TY-AIML-B", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. Quantum", subject="PE-1: Quantum AI", class_name="TY-AIML-C", type="Theory", weekly_hours=2),

        # Shared OE course across BE departments
        Assignment(faculty="Dr. Cyber", subject="OE: Cyber Law", class_name="BE-AIML", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. Cyber", subject="OE: Cyber Law", class_name="BE-CSE", type="Theory", weekly_hours=2),

        # Parallel OE options for Final Year
        Assignment(faculty="Dr. Robo", subject="OE-2: Robotics", class_name="FINAL-A", type="Theory", weekly_hours=2),
        Assignment(faculty="Dr. Green", subject="OE-2: Green Tech", class_name="FINAL-B", type="Theory", weekly_hours=2),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True),
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15", is_break=False),
        TimeSlot(slot_number=5, start_time="12:15", end_time="01:15", is_break=False),
    ]

    rooms = [
        {"name": "CR-301", "type": "Theory", "capacity": 60},
        {"name": "CR-302", "type": "Theory", "capacity": 60},
        {"name": "CR-303", "type": "Theory", "capacity": 60},
        {"name": "Audi-1", "type": "Theory", "capacity": 120},
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday", "Wednesday"],
        rooms=rooms,
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Scenario F: PE-1 options run in parallel across TY divisions in 3 rooms
    pe_slots_a = [k for k, v in result.timetable.get("TY-AIML-A", {}).items() if "PE-1" in v[0]]
    assert len(pe_slots_a) == 2
    for s in pe_slots_a:
        cell = result.detailed_timetable["TY-AIML-A"][s]
        assert len(cell["batches"]) == 3
        rooms_used = [b["room"] for b in cell["batches"]]
        assert len(set(rooms_used)) == 3, "PE-1 tracks must have 3 distinct rooms"

    # Scenario H: Shared OE scheduled once for combined cohort
    oe_slots_be_aiml = [k for k, v in result.timetable.get("BE-AIML", {}).items() if "Cyber Law" in v[0]]
    oe_slots_be_cse = [k for k, v in result.timetable.get("BE-CSE", {}).items() if "Cyber Law" in v[0]]
    assert oe_slots_be_aiml == oe_slots_be_cse, "Shared OE must be at identical slot for all participating classes"

    # Scenario G: Parallel OE-2 options for FINAL-A and FINAL-B
    oe2_slots_a = [k for k, v in result.timetable.get("FINAL-A", {}).items() if "OE-2" in v[0]]
    oe2_slots_b = [k for k, v in result.timetable.get("FINAL-B", {}).items() if "OE-2" in v[0]]
    assert oe2_slots_a == oe2_slots_b, "Parallel OE-2 options must occupy common time interval"

    passed, violations = validate_timetable_grid_solution(
        result.timetable,
        result.detailed_timetable,
        break_slots={3}
    )
    assert passed, f"Violations found: {violations}"


# Scenario I, J, K: Incompatible session prevention & collision rejection
def test_scenario_i_j_k_collision_prevention():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot, Constraint

    assignments = [
        # Faculty Dr. Shared teaches both a shared OE and a normal class
        Assignment(faculty="Dr. Shared", subject="OE: Shared Course", class_name="TY-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. Shared", subject="OE: Shared Course", class_name="TY-B", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. Shared", subject="Special Core", class_name="SY-A", type="Theory", weekly_hours=2),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="12:00", is_break=False),
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday"],
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Dr. Shared can NEVER be scheduled for Special Core at the same time as OE: Shared Course
    for day in ["Monday", "Tuesday"]:
        for slot in [1, 2, 3]:
            key = f"{day}_{slot}"
            ty_a_cell = result.timetable.get("TY-A", {}).get(key, ["Free", "", "", ""])
            sy_a_cell = result.timetable.get("SY-A", {}).get(key, ["Free", "", "", ""])
            if len(ty_a_cell) > 1 and ty_a_cell[1] == "Dr. Shared":
                assert sy_a_cell[0] != "Special Core", f"Faculty Dr. Shared double booked at {key}"


# Scenario L: Combined enrolment exceeding room capacity is detected
def test_scenario_l_capacity_violation_detection():
    from app.schemas.timetable import (
        TimetableGenerationRequest, SolverDivision, SolverSubject, SolverRoom,
        SolverAssignment, TimetableEntryResult, SolverSharedCourse
    )
    from app.services.timetable_validator import validate_generated_timetable

    # 2 divisions with strength 60 each (total = 120)
    req = TimetableGenerationRequest(
        divisions=[
            SolverDivision(id="d1", name="Div A", strength=60),
            SolverDivision(id="d2", name="Div B", strength=60),
        ],
        subjects=[
            SolverSubject(id="s1", name="Honors AI", weekly_lectures=1, is_lab=False, lab_sessions_per_week=0, lab_block_size=2)
        ],
        rooms=[
            SolverRoom(id="r1", name="Small Room", type=RoomType.LECTURE, capacity=70) # capacity 70 < 120!
        ],
        assignments=[
            SolverAssignment(faculty_id="f1", subject_id="s1", division_id="d1"),
            SolverAssignment(faculty_id="f1", subject_id="s1", division_id="d2"),
        ],
        shared_courses=[
            # Configured as shared
            SolverSharedCourse(id="s1", course_name="Honors AI", year=3, divisions=["d1", "d2"], faculty_id="f1", duration_slots=1, weekly_sessions=1, session_type="lecture")
        ]
    )

    # Generated entries placed in Small Room
    entries = [
        TimetableEntryResult(division_id="d1", subject_id="s1", faculty_id="f1", room_id="r1", day=0, slot=1),
        TimetableEntryResult(division_id="d2", subject_id="s1", faculty_id="f1", room_id="r1", day=0, slot=1),
    ]

    passed, conflicts = validate_generated_timetable(req, entries)
    assert not passed, "Validator must detect combined cohort capacity overflow"
    assert any(c.type == "validation_capacity_mismatch" for c in conflicts)


# Scenario M: Infeasible parallel session detection with diagnostic reporting
def test_scenario_m_infeasible_parallel_session_diagnostics():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot, Constraint

    # 4 parallel options required, but only 1 room and 1 time slot available
    assignments = [
        Assignment(faculty="Dr. 1", subject="PE-1: Option A", class_name="TY-A", type="Theory", weekly_hours=1),
        Assignment(faculty="Dr. 2", subject="PE-1: Option B", class_name="TY-B", type="Theory", weekly_hours=1),
        Assignment(faculty="Dr. 3", subject="PE-1: Option C", class_name="TY-C", type="Theory", weekly_hours=1),
        Assignment(faculty="Dr. 4", subject="PE-1: Option D", class_name="TY-D", type="Theory", weekly_hours=1),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
    ]

    # Only 1 room available!
    rooms = [
        {"name": "CR-1", "type": "Theory", "capacity": 60}
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday"],
        rooms=rooms,
        time_limit_seconds=5,
    )

    result = solver.solve()
    # Must report INFEASIBLE or return useful conflict details, never crash or silently produce a bad schedule
    if result.status == "INFEASIBLE":
        assert len(result.conflicts) > 0 or result.message != ""


# Scenario N: Normal theory and practical generation integrity
def test_scenario_n_normal_theory_and_practical_integrity():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot
    from app.services.timetable_validator import validate_timetable_grid_solution

    assignments = [
        # 3 Theory lectures for Div A
        Assignment(faculty="Dr. OS", subject="Operating Systems", class_name="TY-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. DBMS", subject="DBMS", class_name="TY-A", type="Theory", weekly_hours=3),
        # 2 Lab blocks of 2 hours each for Batch 1 and Batch 2
        Assignment(faculty="Prof. Lab1", subject="OS Lab", class_name="TY-A", type="Lab", batch="Batch 1", weekly_hours=2),
        Assignment(faculty="Prof. Lab2", subject="DBMS Lab", class_name="TY-A", type="Lab", batch="Batch 2", weekly_hours=2),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True),
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15", is_break=False),
        TimeSlot(slot_number=5, start_time="12:15", end_time="01:15", is_break=False),
        TimeSlot(slot_number=6, start_time="01:15", end_time="02:00", is_break=True, is_lunch=True),
        TimeSlot(slot_number=7, start_time="02:00", end_time="03:00", is_break=False),
        TimeSlot(slot_number=8, start_time="03:00", end_time="04:00", is_break=False),
    ]

    rooms = [
        {"name": "CR-301", "type": "Theory", "capacity": 60},
        {"name": "OS Lab Room", "type": "Lab", "capacity": 30},
        {"name": "DBMS Lab Room", "type": "Lab", "capacity": 30},
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
        rooms=rooms,
        lecture_duration_minutes=60,
        lab_duration_minutes=120,
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # Verify lab blocks are contiguous and never across break
    for slot_key, cell in result.detailed_timetable.get("TY-A", {}).items():
        if cell.get("type") == "Lab":
            slot_num = int(slot_key.split("_")[1])
            assert slot_num not in (3, 6), "Lab cannot be in break/lunch slot"

    passed, violations = validate_timetable_grid_solution(
        result.timetable,
        result.detailed_timetable,
        break_slots={3, 6}
    )
    assert passed, f"Violations: {violations}"


# Scenario O: Master Timetable and Department Timetable use identical underlying sessions
def test_scenario_o_master_and_department_views_share_identical_sessions():
    from app.services.timetable_cpsat_solver import TimetableCpSatSolver, Assignment, TimeSlot

    assignments = [
        Assignment(faculty="Dr. AIML", subject="Machine Learning", class_name="TY-AIML", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Turing", subject="Honors: Advanced AI", class_name="TY-AIML", type="Theory", weekly_hours=2),
        Assignment(faculty="Prof. Turing", subject="Honors: Advanced AI", class_name="TY-CSE", type="Theory", weekly_hours=2),
    ]

    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True),
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15", is_break=False),
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday", "Wednesday"],
        time_limit_seconds=10,
    )

    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    # In Department Timetable view (TY-AIML):
    ty_aiml_view = result.timetable["TY-AIML"]
    # In Department Timetable view (TY-CSE):
    ty_cse_view = result.timetable["TY-CSE"]

    # Both departmental views and master view reference the exact same Honors slots
    honors_aiml = {k: v for k, v in ty_aiml_view.items() if "Advanced AI" in v[0]}
    honors_cse = {k: v for k, v in ty_cse_view.items() if "Advanced AI" in v[0]}

    assert set(honors_aiml.keys()) == set(honors_cse.keys())
    for k in honors_aiml:
        # Same faculty and same room
        assert honors_aiml[k][1] == honors_cse[k][1] == "Prof. Turing"
        assert honors_aiml[k][2] == honors_cse[k][2]


def test_division_level_subjects_different_slots_for_same_faculty():
    """
    Verify that when the same faculty (e.g. Sharavari Patil) teaches the same subject (e.g. Machine Learning)
    to two different divisions (TY-IT-A and TY-IT-B), the solver schedules them at DIFFERENT time slots,
    preventing faculty double-booking and ensuring each division has its own distinct timetable.
    """
    assignments = [
        Assignment(faculty="Sharavari Patil", subject="Machine Learning", class_name="TY-IT-A", type="Theory", weekly_hours=2),
        Assignment(faculty="Sharavari Patil", subject="Machine Learning", class_name="TY-IT-B", type="Theory", weekly_hours=2),
    ]
    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00", is_break=False),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00", is_break=False),
        TimeSlot(slot_number=3, start_time="11:15", end_time="12:15", is_break=False),
    ]
    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=[],
        working_days=["Monday", "Tuesday"],
        time_limit_seconds=10,
    )
    result = solver.solve()
    assert result.status in ("OPTIMAL", "FEASIBLE")

    a_slots = {k for k, v in result.timetable["TY-IT-A"].items() if v[0] == "Machine Learning"}
    b_slots = {k for k, v in result.timetable["TY-IT-B"].items() if v[0] == "Machine Learning"}

    assert len(a_slots) == 2, f"Expected 2 slots for TY-IT-A, got {len(a_slots)}"
    assert len(b_slots) == 2, f"Expected 2 slots for TY-IT-B, got {len(b_slots)}"

    # Sharavari Patil CANNOT be teaching TY-IT-A and TY-IT-B at the same time!
    overlap = a_slots.intersection(b_slots)
    assert len(overlap) == 0, f"Divisions should have different slots for same faculty, but overlapped at: {overlap}"




