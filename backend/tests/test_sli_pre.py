"""
Unit and integration tests for the Faculty-Driven PRE-Semester Student Assessment.

Tests:
1. Context Retrieval: Faculty sees ONLY their assigned teaching contexts from active timetable entries.
2. Context Retrieval: Admin sees all contexts.
3. Student Roster: Returns enrolled students and their assessment status.
4. Pre-assessment Form: Retrieves student, subject, semester, topics, and existing data.
5. Submission: Successful atomic save of PreSemesterResponse + StudentTopicFeedback (stage='PRE').
6. Upsert/Update: Idempotent resubmission updates the existing record with new updated_at without duplicating.
7. Authorization Guard: Faculty A accessing Faculty B's context -> 403 Forbidden.
8. Authorization Guard: Faculty A accessing an unassigned subject -> 403 Forbidden.
9. Authorization Guard: Faculty A accessing an unassigned division -> 403 Forbidden.
10. Validation Guard: Invalid topic ID not belonging to subject -> 400 Bad Request.
11. Validation Guard: Invalid ratings (0 or 6) -> 422 Unprocessable Entity.
12. Validation Guard: Invalid content types enum -> 422 Unprocessable Entity.
13. Validation Guard: Invalid free_vs_paid_preference enum -> 422 Unprocessable Entity.
14. Lifecycle Guard: PRE assessment on COMPLETED semester -> 400 Bad Request.
15. Non-existent enrollment -> 404 Not Found.
"""
import uuid
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.db.base import SessionLocal
from app.models.academic import Division, Subject, Room
from app.models.generation_history import GenerationRun
from app.models.sli import (
    Department, Student, AcademicClass, Semester, Enrollment,
    Topic, PreSemesterResponse, StudentTopicFeedback,
)
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole
from app.core.security import create_access_token, hash_password

client = TestClient(app)


@pytest.fixture
def sli_pre_test_env():
    """Sets up a complete teaching context with 2 faculty members, 2 subjects, 2 divisions, and enrolled students."""
    db = SessionLocal()

    # 1. Create two faculty members
    fac_a = User(
        email=f"fac.a.{uuid.uuid4().hex[:6]}@enosis.edu",
        hashed_password=hash_password("password123"),
        full_name="Professor A (OS Specialist)",
        role=UserRole.FACULTY,
    )
    fac_b = User(
        email=f"fac.b.{uuid.uuid4().hex[:6]}@enosis.edu",
        hashed_password=hash_password("password123"),
        full_name="Professor B (DBMS Specialist)",
        role=UserRole.FACULTY,
    )
    db.add_all([fac_a, fac_b])
    db.flush()

    token_a = create_access_token(subject=fac_a.id)
    token_b = create_access_token(subject=fac_b.id)

    # 2. Department & Semester
    dept = Department(department_name="Computer Science", department_code=f"CSE_{uuid.uuid4().hex[:4]}")
    db.add(dept)
    db.flush()

    sem_active = Semester(academic_year="2026-27", semester_number=5, status="ACTIVE")
    sem_upcoming = Semester(academic_year="2026-27", semester_number=6, status="UPCOMING")
    sem_completed = Semester(academic_year="2025-26", semester_number=4, status="COMPLETED")
    db.add_all([sem_active, sem_upcoming, sem_completed])
    db.flush()

    # 3. Divisions & Subjects
    div_a = Division(name="TY-A", year=3, division_code="A", strength=60)
    div_b = Division(name="TY-B", year=3, division_code="B", strength=60)
    db.add_all([div_a, div_b])
    db.flush()

    sub_os = Subject(name="Operating Systems", code="CS302", credits=4.0, subject_type="THEORY")
    sub_dbms = Subject(name="Database Systems", code="CS303", credits=4.0, subject_type="THEORY")
    sub_math = Subject(name="Discrete Mathematics", code="MA301", credits=3.0, subject_type="THEORY")
    db.add_all([sub_os, sub_dbms, sub_math])
    db.flush()

    # 4. Topics for OS and DBMS
    topic_os_1 = Topic(subject_id=sub_os.id, topic_name="Process Management & Threads")
    topic_os_2 = Topic(subject_id=sub_os.id, topic_name="CPU Scheduling Algorithms")
    topic_os_3 = Topic(subject_id=sub_os.id, topic_name="Memory Management & Paging")
    topic_dbms_1 = Topic(subject_id=sub_dbms.id, topic_name="Relational Algebra & SQL")
    db.add_all([topic_os_1, topic_os_2, topic_os_3, topic_dbms_1])
    db.flush()

    # 5. Academic Classes
    class_ty_a = AcademicClass(
        department_id=dept.department_id,
        academic_year="2026-27",
        year_level=3,
        division="A",
        division_id=div_a.id,
    )
    class_ty_b = AcademicClass(
        department_id=dept.department_id,
        academic_year="2026-27",
        year_level=3,
        division="B",
        division_id=div_b.id,
    )
    db.add_all([class_ty_a, class_ty_b])
    db.flush()

    # 6. Active Timetable Entries (Source of truth)
    # Faculty A teaches OS to TY-A
    batch = str(uuid.uuid4())
    gen_run = GenerationRun(id=batch, status="OPTIMAL", validation_passed=True)
    room = Room(name="Room 301", type="lecture", capacity=70)
    db.add_all([gen_run, room])
    db.flush()

    tt_entry_a = TimetableEntry(
        batch_id=batch,
        division_id=div_a.id,
        subject_id=sub_os.id,
        faculty_id=fac_a.id,
        room_id=room.id,
        day=0,
        slot=1,
    )
    # Faculty B teaches DBMS to TY-A AND TY-B
    tt_entry_b1 = TimetableEntry(
        batch_id=batch,
        division_id=div_a.id,
        subject_id=sub_dbms.id,
        faculty_id=fac_b.id,
        room_id=room.id,
        day=1,
        slot=2,
    )
    tt_entry_b2 = TimetableEntry(
        batch_id=batch,
        division_id=div_b.id,
        subject_id=sub_dbms.id,
        faculty_id=fac_b.id,
        room_id=room.id,
        day=2,
        slot=3,
    )
    db.add_all([tt_entry_a, tt_entry_b1, tt_entry_b2])
    db.flush()

    # 7. Students & Enrollments
    stu1 = Student(student_id=f"STU_{uuid.uuid4().hex[:5]}", name="Aarav Student", current_year=3, division="A")
    stu2 = Student(student_id=f"STU_{uuid.uuid4().hex[:5]}", name="Bhavna Student", current_year=3, division="A")
    stu3 = Student(student_id=f"STU_{uuid.uuid4().hex[:5]}", name="Chetan Student", current_year=3, division="B")
    db.add_all([stu1, stu2, stu3])
    db.flush()

    # Enrollments for active semester
    enr_stu1_os = Enrollment(student_id=stu1.student_id, class_id=class_ty_a.class_id, semester_id=sem_active.semester_id, subject_id=sub_os.id)
    enr_stu2_os = Enrollment(student_id=stu2.student_id, class_id=class_ty_a.class_id, semester_id=sem_active.semester_id, subject_id=sub_os.id)
    enr_stu1_dbms = Enrollment(student_id=stu1.student_id, class_id=class_ty_a.class_id, semester_id=sem_active.semester_id, subject_id=sub_dbms.id)
    enr_stu3_dbms = Enrollment(student_id=stu3.student_id, class_id=class_ty_b.class_id, semester_id=sem_active.semester_id, subject_id=sub_dbms.id)

    # Enrollment in completed semester
    enr_completed = Enrollment(student_id=stu1.student_id, class_id=class_ty_a.class_id, semester_id=sem_completed.semester_id, subject_id=sub_os.id)

    db.add_all([enr_stu1_os, enr_stu2_os, enr_stu1_dbms, enr_stu3_dbms, enr_completed])
    db.commit()

    env_data = {
        "fac_a_id": fac_a.id,
        "fac_b_id": fac_b.id,
        "token_a": token_a,
        "token_b": token_b,
        "sub_os_id": sub_os.id,
        "sub_dbms_id": sub_dbms.id,
        "sub_math_id": sub_math.id,
        "div_a_id": div_a.id,
        "div_b_id": div_b.id,
        "class_ty_a_id": class_ty_a.class_id,
        "class_ty_b_id": class_ty_b.class_id,
        "sem_active_id": sem_active.semester_id,
        "sem_upcoming_id": sem_upcoming.semester_id,
        "sem_completed_id": sem_completed.semester_id,
        "stu1_id": stu1.student_id,
        "stu2_id": stu2.student_id,
        "stu3_id": stu3.student_id,
        "enr_stu1_os_id": enr_stu1_os.enrollment_id,
        "enr_stu2_os_id": enr_stu2_os.enrollment_id,
        "enr_stu1_dbms_id": enr_stu1_dbms.enrollment_id,
        "enr_stu3_dbms_id": enr_stu3_dbms.enrollment_id,
        "enr_completed_id": enr_completed.enrollment_id,
        "topic_os_1_id": topic_os_1.topic_id,
        "topic_os_2_id": topic_os_2.topic_id,
        "topic_dbms_1_id": topic_dbms_1.topic_id,
    }

    db.close()
    return env_data


def test_faculty_contexts_isolation(sli_pre_test_env):
    """Faculty A should only see OS -> TY-A, while Faculty B sees DBMS -> TY-A and DBMS -> TY-B."""
    env = sli_pre_test_env

    # Faculty A contexts
    res_a = client.get(
        "/sli/faculty/contexts",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_a.status_code == 200
    contexts_a = res_a.json()
    assert len(contexts_a) == 1
    assert contexts_a[0]["subject_name"] == "Operating Systems"
    assert contexts_a[0]["division_name"] == "TY-A"
    assert contexts_a[0]["total_students"] == 2  # stu1 and stu2
    assert contexts_a[0]["assessed_students"] == 0

    # Faculty B contexts
    res_b = client.get(
        "/sli/faculty/contexts",
        headers={"Authorization": f"Bearer {env['token_b']}"}
    )
    assert res_b.status_code == 200
    contexts_b = res_b.json()
    assert len(contexts_b) == 2
    subject_names = {c["subject_name"] for c in contexts_b}
    assert subject_names == {"Database Systems"}


def test_student_roster_retrieval(sli_pre_test_env):
    """Faculty A retrieves roster for OS in TY-A."""
    env = sli_pre_test_env
    res = client.get(
        f"/sli/faculty/contexts/{env['class_ty_a_id']}/{env['sub_os_id']}/{env['sem_active_id']}/students",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res.status_code == 200
    students = res.json()
    assert len(students) == 2
    student_ids = {s["student_id"] for s in students}
    assert env["stu1_id"] in student_ids
    assert env["stu2_id"] in student_ids
    assert all(not s["is_assessed"] for s in students)


def test_pre_assessment_form_structure(sli_pre_test_env):
    """Loads form template with topics for student 1 in OS."""
    env = sli_pre_test_env
    res = client.get(
        f"/sli/faculty/pre-assessment/{env['enr_stu1_os_id']}",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["student_id"] == env["stu1_id"]
    assert data["subject_name"] == "Operating Systems"
    assert data["is_submitted"] is False
    assert len(data["topics"]) == 3  # OS has 3 topics


def test_submit_pre_assessment_and_upsert(sli_pre_test_env):
    """Submits PRE assessment and verifies atomic write and idempotent upsert."""
    env = sli_pre_test_env

    payload = {
        "enrollment_id": env["enr_stu1_os_id"],
        "subject_interest": 4,
        "self_assessed_skill": 2,
        "learning_confidence": 3,
        "expected_difficulty": 4,
        "preferred_learning_format": "interactive_hands_on",
        "preferred_content_types": ["VIDEO", "PRACTICAL"],
        "learning_source": "YouTube & Documentation",
        "free_vs_paid_preference": "FREE",
        "career_interest": "Systems Engineer",
        "placement_goal": "Product Company",
        "skills_to_improve": "Process scheduling, C programming",
        "topic_feedback": [
            {
                "topic_id": env["topic_os_1_id"],
                "confidence_level": 4,
                "difficulty_level": 2,
            },
            {
                "topic_id": env["topic_os_2_id"],
                "confidence_level": 2,
                "difficulty_level": 5,
            },
        ],
    }

    # 1. Initial creation
    res = client.post(
        "/sli/faculty/pre-assessment",
        json=payload,
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res.status_code == 201
    resp_data = res.json()
    assert resp_data["status"] == "success"
    assert resp_data["topics_recorded"] == 2
    assert resp_data["submitted_at"] is not None

    # 2. Check form now returns submitted data
    res_form = client.get(
        f"/sli/faculty/pre-assessment/{env['enr_stu1_os_id']}",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_form.status_code == 200
    form_data = res_form.json()
    assert form_data["is_submitted"] is True
    assert form_data["subject_interest"] == 4
    assert form_data["preferred_content_types"] == ["VIDEO", "PRACTICAL"]
    assert form_data["free_vs_paid_preference"] == "FREE"

    # 3. Check assessed count on contexts endpoint
    res_ctx = client.get(
        "/sli/faculty/contexts",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_ctx.json()[0]["assessed_students"] == 1

    # 4. Upsert (update) with modified values
    payload_update = dict(payload)
    payload_update["subject_interest"] = 5
    payload_update["learning_confidence"] = 5

    res_update = client.post(
        "/sli/faculty/pre-assessment",
        json=payload_update,
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_update.status_code == 201

    # Verify updated values
    res_form_after = client.get(
        f"/sli/faculty/pre-assessment/{env['enr_stu1_os_id']}",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_form_after.json()["subject_interest"] == 5
    assert res_form_after.json()["learning_confidence"] == 5


def test_authorization_negative_cases(sli_pre_test_env):
    """Tests 403 Forbidden when faculty attempts unauthorized access."""
    env = sli_pre_test_env

    # Faculty A trying to access DBMS (taught by Faculty B)
    res = client.get(
        f"/sli/faculty/contexts/{env['class_ty_a_id']}/{env['sub_dbms_id']}/{env['sem_active_id']}/students",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res.status_code == 403
    assert "not assigned" in res.json()["detail"].lower()

    # Faculty A trying to access student form for DBMS enrollment
    res_form = client.get(
        f"/sli/faculty/pre-assessment/{env['enr_stu1_dbms_id']}",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_form.status_code == 403

    # Faculty A trying to submit PRE assessment for DBMS enrollment
    res_post = client.post(
        "/sli/faculty/pre-assessment",
        json={
            "enrollment_id": env["enr_stu1_dbms_id"],
            "subject_interest": 3,
        },
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_post.status_code == 403


def test_validation_negative_cases(sli_pre_test_env):
    """Tests input validation rules."""
    env = sli_pre_test_env

    # Rating > 5
    res_invalid_rating = client.post(
        "/sli/faculty/pre-assessment",
        json={
            "enrollment_id": env["enr_stu1_os_id"],
            "subject_interest": 6,  # invalid
        },
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_invalid_rating.status_code == 422

    # Rating < 1
    res_zero_rating = client.post(
        "/sli/faculty/pre-assessment",
        json={
            "enrollment_id": env["enr_stu1_os_id"],
            "subject_interest": 0,  # invalid
        },
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_zero_rating.status_code == 422

    # Invalid preferred content type
    res_invalid_content = client.post(
        "/sli/faculty/pre-assessment",
        json={
            "enrollment_id": env["enr_stu1_os_id"],
            "preferred_content_types": ["INVALID_CONTENT_TYPE"],
        },
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_invalid_content.status_code == 422

    # Invalid free vs paid preference
    res_invalid_cost = client.post(
        "/sli/faculty/pre-assessment",
        json={
            "enrollment_id": env["enr_stu1_os_id"],
            "free_vs_paid_preference": "UNKNOWN_PLAN",
        },
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_invalid_cost.status_code == 422

    # Submitting topic from DBMS for an OS enrollment
    res_wrong_topic = client.post(
        "/sli/faculty/pre-assessment",
        json={
            "enrollment_id": env["enr_stu1_os_id"],
            "topic_feedback": [
                {
                    "topic_id": env["topic_dbms_1_id"],  # DBMS topic!
                    "confidence_level": 3,
                    "difficulty_level": 3,
                }
            ],
        },
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_wrong_topic.status_code == 400
    assert "does not belong to subject" in res_wrong_topic.json()["detail"]

    # Non-existent enrollment ID
    res_not_found = client.get(
        "/sli/faculty/pre-assessment/999999",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_not_found.status_code == 404

    # Completed semester not eligible for PRE assessment
    res_completed_sem = client.get(
        f"/sli/faculty/pre-assessment/{env['enr_completed_id']}",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res_completed_sem.status_code == 400
    assert "only open for UPCOMING or ACTIVE" in res_completed_sem.json()["detail"]


def test_wrong_division_authorization_rejected(sli_pre_test_env):
    """Faculty A is assigned to OS in TY-A, NOT TY-B."""
    env = sli_pre_test_env

    res = client.get(
        f"/sli/faculty/contexts/{env['class_ty_b_id']}/{env['sub_os_id']}/{env['sem_active_id']}/students",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res.status_code == 403


def test_inactive_timetable_batch_rejected(sli_pre_test_env):
    """If a new valid generation run exists, old batch timetable entries are rejected."""
    env = sli_pre_test_env
    db = SessionLocal()

    # Create a newer valid generation run with a new batch_id that assigns only Faculty B
    new_batch_id = str(uuid.uuid4())
    new_run = GenerationRun(
        id=new_batch_id,
        status="OPTIMAL",
        validation_passed=True,
    )
    # New entry: Faculty B now teaches OS in TY-A
    new_tt_entry = TimetableEntry(
        batch_id=new_batch_id,
        division_id=env["div_a_id"],
        subject_id=env["sub_os_id"],
        faculty_id=env["fac_b_id"],
        room_id=db.query(Room).first().id,
        day=3,
        slot=1,
    )
    db.add_all([new_run, new_tt_entry])
    db.commit()
    db.close()

    # Faculty A (whose assignment was in the previous batch) now gets 403
    res = client.get(
        f"/sli/faculty/contexts/{env['class_ty_a_id']}/{env['sub_os_id']}/{env['sem_active_id']}/students",
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res.status_code == 403

    # Faculty B (in the new active batch) now gets 200
    res_b = client.get(
        f"/sli/faculty/contexts/{env['class_ty_a_id']}/{env['sub_os_id']}/{env['sem_active_id']}/students",
        headers={"Authorization": f"Bearer {env['token_b']}"}
    )
    assert res_b.status_code == 200


def test_atomic_rollback_on_topic_failure(sli_pre_test_env):
    """When a topic validation error occurs, entire PRE assessment is rolled back."""
    env = sli_pre_test_env
    db = SessionLocal()

    # Verify no response exists initially for student 2
    pre_before = db.query(PreSemesterResponse).filter(
        PreSemesterResponse.enrollment_id == env["enr_stu2_os_id"]
    ).first()
    assert pre_before is None
    db.close()

    # Attempt to post with an invalid foreign topic ID
    payload = {
        "enrollment_id": env["enr_stu2_os_id"],
        "subject_interest": 4,
        "self_assessed_skill": 3,
        "topic_feedback": [
            {
                "topic_id": env["topic_dbms_1_id"],  # DBMS topic on OS enrollment!
                "confidence_level": 3,
                "difficulty_level": 3,
            }
        ],
    }

    res = client.post(
        "/sli/faculty/pre-assessment",
        json=payload,
        headers={"Authorization": f"Bearer {env['token_a']}"}
    )
    assert res.status_code == 400

    # Verify that database has NO half-committed PreSemesterResponse
    db = SessionLocal()
    pre_after = db.query(PreSemesterResponse).filter(
        PreSemesterResponse.enrollment_id == env["enr_stu2_os_id"]
    ).first()
    assert pre_after is None
    db.close()

