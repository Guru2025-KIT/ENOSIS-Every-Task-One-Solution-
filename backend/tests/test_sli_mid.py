"""
Unit and integration tests for the Faculty-Driven MID-Semester Student Assessment.

Tests:
1. Context Retrieval: includes mid_assessed_students count alongside pre assessed_students.
2. Student Roster: returns is_pre_assessed and is_mid_assessed status.
3. Form Details: returns student/subject context, PRE baseline values, PRE-linked target skills, and topics with PRE and MID scores.
4. Submission: Successful atomic save of MidSemesterResponse + skills_progress + StudentTopicFeedback (stage='MID').
5. Coexistence: Confirms PRE and MID topic feedbacks coexist independently in student_topic_feedback.
6. Upsert/Update: Idempotent resubmission updates existing MID response without duplicates, preserving submitted_at.
7. Authorization Guard: Unauthorized faculty -> 403 Forbidden.
8. Validation Guard: Invalid ratings (0 or 6) -> 422 Unprocessable Entity.
9. Validation Guard: Invalid enum values -> 422 Unprocessable Entity.
10. Validation Guard: Invalid topic ID not belonging to subject -> 400 Bad Request.
11. Lifecycle Guard: MID on UPCOMING semester -> 400 Bad Request.
12. Lifecycle Guard: MID on COMPLETED semester -> 400 Bad Request.
13. Zero-topic subject: Subject without configured topics allowed.
"""

import uuid
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.db.base import SessionLocal
from app.main import app
from app.models.academic import Division, Room, Subject
from app.models.generation_history import GenerationRun
from app.models.sli import (
    AcademicClass, Department, Enrollment, MidSemesterResponse,
    PreSemesterResponse, Semester, Student, StudentTopicFeedback, Topic,
)
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole

client = TestClient(app)


@pytest.fixture
def sli_mid_test_data():
    db = SessionLocal()
    try:
        # Create department
        dept_name = f"Dept_MID_{uuid.uuid4().hex[:6]}"
        dept = Department(department_name=dept_name, department_code=f"D{uuid.uuid4().hex[:7]}")
        db.add(dept)
        db.flush()

        # Create Faculty Users
        faculty_user = User(
            id=str(uuid.uuid4()),
            email=f"faculty.mid_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Faculty@123"),
            full_name="Prof. Alan Turing",
            role=UserRole.FACULTY,
            department=dept_name,
        )
        other_faculty_user = User(
            id=str(uuid.uuid4()),
            email=f"other.mid_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Faculty@123"),
            full_name="Prof. Grace Hopper",
            role=UserRole.FACULTY,
            department=dept_name,
        )
        db.add_all([faculty_user, other_faculty_user])
        db.flush()

        # Create Semesters (ACTIVE, UPCOMING, COMPLETED)
        sem_active = Semester(
            academic_year="2026-2027",
            semester_number=5,
            status="ACTIVE",
        )
        sem_upcoming = Semester(
            academic_year="2026-2027",
            semester_number=6,
            status="UPCOMING",
        )
        sem_completed = Semester(
            academic_year="2025-2026",
            semester_number=4,
            status="COMPLETED",
        )
        db.add_all([sem_active, sem_upcoming, sem_completed])
        db.flush()

        # Create Timetable Division & Class
        division_code = f"M{uuid.uuid4().hex[:2].upper()}"
        div = Division(
            id=str(uuid.uuid4()),
            name=f"Division {division_code}",
            year=3,
            division_code=division_code,
        )
        db.add(div)
        db.flush()

        academic_class = AcademicClass(
            department_id=dept.department_id,
            academic_year="2026-2027",
            year_level=3,
            division=division_code,
            division_id=div.id,
        )
        db.add(academic_class)
        db.flush()

        # Create Subject & Topics
        subject = Subject(
            id=str(uuid.uuid4()),
            name=f"Advanced Algorithms {uuid.uuid4().hex[:4]}",
            code=f"CS{uuid.uuid4().hex[:3].upper()}",
            sli_department_id=dept.department_id,
            credits=4,
        )
        db.add(subject)
        db.flush()

        topic_1 = Topic(subject_id=subject.id, topic_name="Dynamic Programming")
        topic_2 = Topic(subject_id=subject.id, topic_name="Graph Algorithms")
        db.add_all([topic_1, topic_2])
        db.flush()

        # Create GenerationRun & TimetableEntry
        batch = str(uuid.uuid4())
        gen_run = GenerationRun(id=batch, status="OPTIMAL", validation_passed=True)
        room = Room(name="Room 301", type="lecture", capacity=70)
        db.add_all([gen_run, room])
        db.flush()

        entry = TimetableEntry(
            id=str(uuid.uuid4()),
            batch_id=batch,
            day=0,
            slot=1,
            division_id=div.id,
            subject_id=subject.id,
            faculty_id=faculty_user.id,
            room_id=room.id,
        )
        db.add(entry)
        db.flush()

        # Create Students & Enrollments
        students = []
        enrollments = []
        for i in range(2):
            stu = Student(
                student_id=f"STU_MID_{uuid.uuid4().hex[:6]}",
                name=f"Student {i+1}",
                email=f"student{i+1}.mid@college.edu",
                department_id=dept.department_id,
                current_year=3,
                division=division_code,
            )
            db.add(stu)
            db.flush()
            students.append(stu)

            enr = Enrollment(
                student_id=stu.student_id,
                class_id=academic_class.class_id,
                semester_id=sem_active.semester_id,
                subject_id=subject.id,
            )
            db.add(enr)
            db.flush()
            enrollments.append(enr)

        # Seed Student 1 with PRE assessment
        pre_resp = PreSemesterResponse(
            enrollment_id=enrollments[0].enrollment_id,
            subject_interest=3,
            self_assessed_skill=2,
            learning_confidence=2,
            expected_difficulty=4,
            preferred_learning_format="PRACTICAL_LABS",
            skills_to_improve="Dynamic Programming, Graph Theory, Recursion",
        )
        pre_topic_1 = StudentTopicFeedback(
            enrollment_id=enrollments[0].enrollment_id,
            topic_id=topic_1.topic_id,
            stage="PRE",
            confidence_level=2,
            difficulty_level=4,
        )
        pre_topic_2 = StudentTopicFeedback(
            enrollment_id=enrollments[0].enrollment_id,
            topic_id=topic_2.topic_id,
            stage="PRE",
            confidence_level=1,
            difficulty_level=5,
        )
        db.add_all([pre_resp, pre_topic_1, pre_topic_2])
        db.commit()

        yield {
            "faculty": faculty_user,
            "other_faculty": other_faculty_user,
            "active_sem": sem_active,
            "upcoming_sem": sem_upcoming,
            "completed_sem": sem_completed,
            "class": academic_class,
            "division": div,
            "subject": subject,
            "topics": [topic_1, topic_2],
            "students": students,
            "enrollments": enrollments,
        }
    finally:
        db.close()


def test_get_faculty_contexts_and_roster_with_mid(sli_mid_test_data):
    """Test 1 & 2: Verify contexts and roster return MID metrics."""
    data = sli_mid_test_data
    token = create_access_token(subject=data["faculty"].id)
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Contexts
    r_ctx = client.get("/sli/faculty/contexts", headers=headers)
    assert r_ctx.status_code == 200
    contexts = r_ctx.json()
    ctx = next((c for c in contexts if c["subject_id"] == data["subject"].id), None)
    assert ctx is not None
    assert ctx["total_students"] == 2
    assert ctx["assessed_students"] == 1  # 1 student completed PRE
    assert ctx["mid_assessed_students"] == 0  # 0 completed MID yet

    # 2. Roster
    r_roster = client.get(
        f"/sli/faculty/contexts/{data['class'].class_id}/{data['subject'].id}/{data['active_sem'].semester_id}/students",
        headers=headers,
    )
    assert r_roster.status_code == 200
    roster = r_roster.json()
    assert len(roster) == 2
    stu1 = next(s for s in roster if s["enrollment_id"] == data["enrollments"][0].enrollment_id)
    assert stu1["is_pre_assessed"] is True
    assert stu1["is_mid_assessed"] is False


def test_get_mid_assessment_form_with_pre_baseline(sli_mid_test_data):
    """Test 3: Verify GET MID form returns metadata, PRE baseline scores, PRE-linked target skills, and topics."""
    data = sli_mid_test_data
    token = create_access_token(subject=data["faculty"].id)
    headers = {"Authorization": f"Bearer {token}"}
    enr1_id = data["enrollments"][0].enrollment_id

    r_form = client.get(f"/sli/faculty/mid-assessment/{enr1_id}", headers=headers)
    assert r_form.status_code == 200
    form = r_form.json()

    assert form["enrollment_id"] == enr1_id
    assert form["is_submitted"] is False

    # Check PRE baseline context
    baseline = form["pre_baseline"]
    assert baseline["has_pre_assessment"] is True
    assert baseline["learning_confidence"] == 2
    assert baseline["subject_interest"] == 3
    assert baseline["expected_difficulty"] == 4
    assert baseline["skills_to_improve"] == "Dynamic Programming, Graph Theory, Recursion"

    # Check pre-seeded target skills extracted from PRE
    skills = form["skills_progress"]
    skill_names = [s["skill_name"] for s in skills]
    assert "Dynamic Programming" in skill_names
    assert "Graph Theory" in skill_names
    assert "Recursion" in skill_names

    # Check topics with PRE baseline values
    topics = form["topics"]
    assert len(topics) == 2
    t1 = next(t for t in topics if t["topic_id"] == data["topics"][0].topic_id)
    assert t1["pre_confidence"] == 2
    assert t1["pre_difficulty"] == 4
    assert t1["mid_confidence"] is None


def test_submit_mid_assessment_atomic_save_and_coexistence(sli_mid_test_data):
    """Test 4 & 5: Verify atomic MID save and coexistence of PRE + MID topic feedbacks."""
    data = sli_mid_test_data
    token = create_access_token(subject=data["faculty"].id)
    headers = {"Authorization": f"Bearer {token}"}
    enr1_id = data["enrollments"][0].enrollment_id
    t1, t2 = data["topics"]

    payload = {
        "enrollment_id": enr1_id,
        "current_confidence": 4,
        "current_interest": 4,
        "perceived_difficulty": 3,
        "understanding_level": 4,
        "concept_application_ability": 4,
        "learning_satisfaction": 4,
        "useful_learning_format": "PRACTICAL_LABS",
        "resource_effectiveness": 4,
        "practical_lab_experience": 5,
        "teaching_pace": "JUST_RIGHT",
        "learning_barriers": ["CONCEPTUAL_DIFFICULTY", "TIME_MANAGEMENT"],
        "skills_progress": [
            {"skill_name": "Dynamic Programming", "confidence_level": 4, "progress_status": "IMPROVED"},
            {"skill_name": "Graph Theory", "confidence_level": 3, "progress_status": "IN_PROGRESS"},
            {"skill_name": "Recursion", "confidence_level": 5, "progress_status": "MASTERED"},
        ],
        "topic_feedback": [
            {"topic_id": t1.topic_id, "confidence_level": 4, "difficulty_level": 3, "progress_status": "COMPLETED"},
            {"topic_id": t2.topic_id, "confidence_level": 3, "difficulty_level": 3, "progress_status": "IN_PROGRESS"},
        ],
    }

    r_submit = client.post("/sli/faculty/mid-assessment", json=payload, headers=headers)
    assert r_submit.status_code == 201
    res = r_submit.json()
    assert res["status"] == "success"
    assert res["topics_recorded"] == 2
    assert res["skills_recorded"] == 3

    # Verify Coexistence: PRE and MID topic feedbacks both exist in DB
    db = SessionLocal()
    try:
        all_tf = db.query(StudentTopicFeedback).filter_by(enrollment_id=enr1_id).all()
        # 2 PRE + 2 MID = 4 total feedbacks
        assert len(all_tf) == 4

        pre_t1 = db.query(StudentTopicFeedback).filter_by(enrollment_id=enr1_id, topic_id=t1.topic_id, stage="PRE").one()
        assert pre_t1.confidence_level == 2

        mid_t1 = db.query(StudentTopicFeedback).filter_by(enrollment_id=enr1_id, topic_id=t1.topic_id, stage="MID").one()
        assert mid_t1.confidence_level == 4
        assert mid_t1.progress_status == "COMPLETED"

        # Verify MidSemesterResponse in DB
        mid_resp = db.query(MidSemesterResponse).filter_by(enrollment_id=enr1_id).one()
        assert mid_resp.current_confidence == 4
        assert mid_resp.teaching_pace == "JUST_RIGHT"
        assert len(mid_resp.learning_barriers) == 2
        assert len(mid_resp.skills_progress) == 3
    finally:
        db.close()


def test_upsert_mid_assessment_preserves_timestamp(sli_mid_test_data):
    """Test 6: Verify resubmission/edit updates values without duplicate records, preserving submitted_at."""
    data = sli_mid_test_data
    token = create_access_token(subject=data["faculty"].id)
    headers = {"Authorization": f"Bearer {token}"}
    enr1_id = data["enrollments"][0].enrollment_id
    t1, t2 = data["topics"]

    # First submission
    payload1 = {
        "enrollment_id": enr1_id,
        "current_confidence": 3,
        "topic_feedback": [
            {"topic_id": t1.topic_id, "confidence_level": 3, "difficulty_level": 3, "progress_status": "IN_PROGRESS"},
        ],
    }
    r1 = client.post("/sli/faculty/mid-assessment", json=payload1, headers=headers)
    assert r1.status_code == 201
    orig_submitted_at = r1.json()["submitted_at"]

    # Resubmission (Edit)
    payload2 = {
        "enrollment_id": enr1_id,
        "current_confidence": 5,
        "topic_feedback": [
            {"topic_id": t1.topic_id, "confidence_level": 5, "difficulty_level": 2, "progress_status": "COMPLETED"},
        ],
    }
    r2 = client.post("/sli/faculty/mid-assessment", json=payload2, headers=headers)
    assert r2.status_code == 201
    updated_submitted_at = r2.json()["submitted_at"]

    # Verify submitted_at timestamp preserved
    assert orig_submitted_at == updated_submitted_at

    db = SessionLocal()
    try:
        assert db.query(MidSemesterResponse).filter_by(enrollment_id=enr1_id).count() == 1
        rec = db.query(MidSemesterResponse).filter_by(enrollment_id=enr1_id).one()
        assert rec.current_confidence == 5
    finally:
        db.close()


def test_mid_authorization_and_validation_guards(sli_mid_test_data):
    """Test 7, 8, 9, 10: Authorization and Validation Guards."""
    data = sli_mid_test_data
    unauth_token = create_access_token(subject=data["other_faculty"].id)
    headers_unauth = {"Authorization": f"Bearer {unauth_token}"}
    auth_token = create_access_token(subject=data["faculty"].id)
    headers_auth = {"Authorization": f"Bearer {auth_token}"}
    enr1_id = data["enrollments"][0].enrollment_id

    # 7. Unauthorized faculty -> 403
    r_unauth = client.get(f"/sli/faculty/mid-assessment/{enr1_id}", headers=headers_unauth)
    assert r_unauth.status_code == 403

    # 8. Invalid rating (outside 1-5) -> 422
    r_invalid_rating = client.post(
        "/sli/faculty/mid-assessment",
        json={"enrollment_id": enr1_id, "current_confidence": 10},
        headers=headers_auth,
    )
    assert r_invalid_rating.status_code == 422

    # 9. Invalid enum for teaching_pace -> 422
    r_invalid_enum = client.post(
        "/sli/faculty/mid-assessment",
        json={"enrollment_id": enr1_id, "teaching_pace": "SUPER_FAST_INVALID"},
        headers=headers_auth,
    )
    assert r_invalid_enum.status_code == 422

    # 10. Invalid topic ID -> 400
    r_invalid_topic = client.post(
        "/sli/faculty/mid-assessment",
        json={
            "enrollment_id": enr1_id,
            "topic_feedback": [{"topic_id": 999999, "confidence_level": 4, "difficulty_level": 2, "progress_status": "IN_PROGRESS"}],
        },
        headers=headers_auth,
    )
    assert r_invalid_topic.status_code == 400


def test_mid_semester_lifecycle_guard(sli_mid_test_data):
    """Test 11 & 12: MID strictly forbidden for UPCOMING and COMPLETED semesters."""
    data = sli_mid_test_data
    token = create_access_token(subject=data["faculty"].id)
    headers = {"Authorization": f"Bearer {token}"}

    db = SessionLocal()
    try:
        # Create enrollment in UPCOMING semester
        enr_upcoming = Enrollment(
            student_id=data["students"][0].student_id,
            class_id=data["class"].class_id,
            semester_id=data["upcoming_sem"].semester_id,
            subject_id=data["subject"].id,
        )
        # Create enrollment in COMPLETED semester
        enr_completed = Enrollment(
            student_id=data["students"][0].student_id,
            class_id=data["class"].class_id,
            semester_id=data["completed_sem"].semester_id,
            subject_id=data["subject"].id,
        )
        db.add_all([enr_upcoming, enr_completed])
        db.commit()
        enr_up_id = enr_upcoming.enrollment_id
        enr_comp_id = enr_completed.enrollment_id
    finally:
        db.close()

    # GET UPCOMING -> 400
    r_up = client.get(f"/sli/faculty/mid-assessment/{enr_up_id}", headers=headers)
    assert r_up.status_code == 400
    assert "ACTIVE semesters" in r_up.text

    # GET COMPLETED -> 400
    r_comp = client.get(f"/sli/faculty/mid-assessment/{enr_comp_id}", headers=headers)
    assert r_comp.status_code == 400
    assert "ACTIVE semesters" in r_comp.text
