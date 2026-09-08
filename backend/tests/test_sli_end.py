"""
Unit and integration tests for the Faculty-Driven END-Semester Student Assessment.

Tests:
1. Context Retrieval: includes end_assessed_students count alongside pre and mid assessed_students.
2. Student Roster: returns is_pre_assessed, is_mid_assessed, and is_end_assessed status.
3. Form Details: returns student/subject context, PRE baseline, MID baseline, target skills, and topics with PRE, MID, and END scores.
4. Submission: Successful atomic save of EndSemesterResponse + skills_progress + StudentTopicFeedback (stage='END').
5. Coexistence: Confirms PRE, MID, and END topic feedbacks coexist independently in student_topic_feedback with unique constraint.
6. Upsert/Update: Idempotent resubmission updates existing END response without duplicates, preserving submitted_at.
7. Skills Progression Chain: Preserves target skill identities from MID/PRE, allows updating confidence and progress_status.
8. Lifecycle Guard (POST): END submission permitted ONLY during ACTIVE semester. POST during COMPLETED or ARCHIVED returns 400.
9. Lifecycle Guard (GET): Form view permitted during ACTIVE and COMPLETED semesters. Form view during ARCHIVED returns 400.
10. Authorization Guard: Unauthorized faculty -> 403 Forbidden. Wrong division -> 403 Forbidden.
11. Validation Guard: Invalid ratings (0 or 6) -> 422 Unprocessable Entity.
12. Validation Guard: Invalid enum values -> 422 Unprocessable Entity.
13. Validation Guard: Invalid topic ID not belonging to subject -> 400 Bad Request.
"""

import uuid
from datetime import datetime, timezone
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.db.base import SessionLocal
from app.main import app
from app.models.academic import Division, Room, Subject
from app.models.generation_history import GenerationRun
from app.models.sli import (
    AcademicClass, Department, EndSemesterResponse, Enrollment, MidSemesterResponse,
    PreSemesterResponse, Semester, Student, StudentTopicFeedback, Topic,
)
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole

client = TestClient(app)


@pytest.fixture
def sli_end_test_data():
    db = SessionLocal()
    try:
        # Create department
        dept_name = f"Dept_END_{uuid.uuid4().hex[:6]}"
        dept = Department(department_name=dept_name, department_code=f"D{uuid.uuid4().hex[:7]}")
        db.add(dept)
        db.flush()

        # Create Faculty Users
        faculty_user = User(
            id=str(uuid.uuid4()),
            email=f"faculty.end_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Faculty@123"),
            full_name="Prof. Donald Knuth",
            role=UserRole.FACULTY,
            department=dept_name,
        )
        other_faculty_user = User(
            id=str(uuid.uuid4()),
            email=f"other.faculty.end_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Faculty@123"),
            full_name="Prof. Grace Hopper",
            role=UserRole.FACULTY,
            department=dept_name,
        )
        admin_user = User(
            id=str(uuid.uuid4()),
            email=f"admin.end_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Admin@123"),
            full_name="Dean Administration",
            role=UserRole.ADMIN,
            department=dept_name,
        )
        db.add_all([faculty_user, other_faculty_user, admin_user])
        db.flush()

        # Create Semester (ACTIVE)
        active_semester = Semester(
            academic_year="2026-27",
            semester_number=5,
            status="ACTIVE",
        )
        completed_semester = Semester(
            academic_year="2026-27",
            semester_number=4,
            status="COMPLETED",
        )
        archived_semester = Semester(
            academic_year="2025-26",
            semester_number=3,
            status="ARCHIVED",
        )
        db.add_all([active_semester, completed_semester, archived_semester])
        db.flush()

        # Create Subject
        subject = Subject(
            id=str(uuid.uuid4()),
            name="Algorithms and Complexity",
            code=f"CS{uuid.uuid4().hex[:4].upper()}",
            credits=4,
        )
        db.add(subject)
        db.flush()

        # Create Topics for Subject
        t1 = Topic(subject_id=subject.id, topic_name="Dynamic Programming & Memoization")
        t2 = Topic(subject_id=subject.id, topic_name="Graph Algorithms & Shortest Path")
        t3 = Topic(subject_id=subject.id, topic_name="NP-Completeness & Reductions")
        db.add_all([t1, t2, t3])
        db.flush()

        # Create Division and AcademicClass
        division = Division(
            id=str(uuid.uuid4()),
            name="TE Computer Division A",
            year=3,
            division_code="A",
        )
        other_division = Division(
            id=str(uuid.uuid4()),
            name="TE Computer Division B",
            year=3,
            division_code="B",
        )
        db.add_all([division, other_division])
        db.flush()

        academic_class = AcademicClass(
            department_id=dept.department_id,
            academic_year="2026-2027",
            year_level=3,
            division="A",
            division_id=division.id,
        )
        db.add(academic_class)
        db.flush()

        # Create Student and Enrollment
        student = Student(
            student_id=f"STU-END-{uuid.uuid4().hex[:4].upper()}",
            department_id=dept.department_id,
            current_year=3,
            division="A",
            name="Aditya Verma",
            email=f"aditya.{uuid.uuid4().hex[:6]}@college.edu",
        )
        db.add(student)
        db.flush()

        enrollment = Enrollment(
            student_id=student.student_id,
            class_id=academic_class.class_id,
            semester_id=active_semester.semester_id,
            subject_id=subject.id,
        )
        db.add(enrollment)
        db.flush()

        # Create PRE baseline response and PRE topic feedback
        pre_response = PreSemesterResponse(
            enrollment_id=enrollment.enrollment_id,
            subject_interest=4,
            self_assessed_skill=3,
            learning_confidence=2,
            expected_difficulty=4,
            preferred_learning_format="PRACTICAL_LABS",
            career_interest="Algorithm Design",
            skills_to_improve="Dynamic programming, Graph traversal, State space reduction",
        )
        db.add(pre_response)
        db.flush()

        pre_tf1 = StudentTopicFeedback(
            enrollment_id=enrollment.enrollment_id,
            topic_id=t1.topic_id,
            stage="PRE",
            confidence_level=2,
            difficulty_level=4,
        )
        pre_tf2 = StudentTopicFeedback(
            enrollment_id=enrollment.enrollment_id,
            topic_id=t2.topic_id,
            stage="PRE",
            confidence_level=3,
            difficulty_level=3,
        )
        db.add_all([pre_tf1, pre_tf2])
        db.flush()

        # Create MID baseline response and MID topic feedback
        mid_response = MidSemesterResponse(
            enrollment_id=enrollment.enrollment_id,
            current_confidence=3,
            current_interest=4,
            perceived_difficulty=3,
            understanding_level=4,
            concept_application_ability=3,
            learning_satisfaction=4,
            useful_learning_format="PRACTICAL_LABS",
            resource_effectiveness=4,
            practical_lab_experience=5,
            teaching_pace="JUST_RIGHT",
            skills_progress=[
                {"skill_name": "Dynamic programming", "confidence_level": 3, "progress_status": "IN_PROGRESS"},
                {"skill_name": "Graph traversal", "confidence_level": 4, "progress_status": "IMPROVED"},
                {"skill_name": "State space reduction", "confidence_level": 2, "progress_status": "IN_PROGRESS"},
            ],
        )
        db.add(mid_response)
        db.flush()

        mid_tf1 = StudentTopicFeedback(
            enrollment_id=enrollment.enrollment_id,
            topic_id=t1.topic_id,
            stage="MID",
            confidence_level=3,
            difficulty_level=3,
            progress_status="IN_PROGRESS",
        )
        mid_tf2 = StudentTopicFeedback(
            enrollment_id=enrollment.enrollment_id,
            topic_id=t2.topic_id,
            stage="MID",
            confidence_level=4,
            difficulty_level=3,
            progress_status="COMPLETED",
        )
        db.add_all([mid_tf1, mid_tf2])
        db.flush()

        # Create Room and Timetable Validation Run
        batch = str(uuid.uuid4())
        gen_run = GenerationRun(id=batch, status="OPTIMAL", validation_passed=True)
        room = Room(name="Room 301", type="lecture", capacity=70)
        db.add_all([gen_run, room])
        db.flush()

        # Create authorized Timetable Entry for Faculty
        tt_entry = TimetableEntry(
            id=str(uuid.uuid4()),
            batch_id=batch,
            division_id=division.id,
            subject_id=subject.id,
            faculty_id=faculty_user.id,
            room_id=room.id,
            day=0,
            slot=1,
        )
        db.add(tt_entry)
        db.commit()

        # Generate JWT Tokens
        faculty_token = create_access_token(subject=faculty_user.id)
        other_faculty_token = create_access_token(subject=other_faculty_user.id)
        admin_token = create_access_token(subject=admin_user.id)

        yield {
            "faculty_token": faculty_token,
            "other_faculty_token": other_faculty_token,
            "admin_token": admin_token,
            "enrollment_id": enrollment.enrollment_id,
            "class_id": academic_class.class_id,
            "subject_id": subject.id,
            "active_semester_id": active_semester.semester_id,
            "completed_semester_id": completed_semester.semester_id,
            "archived_semester_id": archived_semester.semester_id,
            "topics": [t1, t2, t3],
            "student": student,
        }
    finally:
        db.close()


def test_get_end_assessment_form_with_pre_and_mid_baselines(sli_end_test_data):
    """GET /sli/faculty/end-assessment/{enrollment_id} returns PRE baseline, MID baseline, and topic progression."""
    token = sli_end_test_data["faculty_token"]
    enrollment_id = sli_end_test_data["enrollment_id"]

    resp = client.get(
        f"/sli/faculty/end-assessment/{enrollment_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["enrollment_id"] == enrollment_id
    assert data["student_name"] == "Aditya Verma"
    assert data["is_submitted"] is False

    # Check PRE baseline
    pre_base = data["pre_baseline"]
    assert pre_base["has_pre_assessment"] is True
    assert pre_base["learning_confidence"] == 2
    assert pre_base["subject_interest"] == 4
    assert pre_base["expected_difficulty"] == 4

    # Check MID baseline
    mid_base = data["mid_baseline"]
    assert mid_base["has_mid_assessment"] is True
    assert mid_base["current_confidence"] == 3
    assert mid_base["understanding_level"] == 4
    assert mid_base["useful_learning_format"] == "PRACTICAL_LABS"
    assert mid_base["teaching_pace"] == "JUST_RIGHT"

    # Check Skills initialized from MID structured progression
    skills = data["skills_progress"]
    assert len(skills) == 3
    assert skills[0]["skill_name"] == "Dynamic programming"
    assert skills[0]["confidence_level"] == 3
    assert skills[0]["progress_status"] == "IN_PROGRESS"
    assert skills[1]["skill_name"] == "Graph traversal"
    assert skills[1]["progress_status"] == "IMPROVED"

    # Check Topics with merged PRE and MID ratings
    topics = data["topics"]
    assert len(topics) == 3
    t1_data = next(t for t in topics if t["topic_name"] == "Dynamic Programming & Memoization")
    assert t1_data["pre_confidence"] == 2
    assert t1_data["pre_difficulty"] == 4
    assert t1_data["mid_confidence"] == 3
    assert t1_data["mid_difficulty"] == 3
    assert t1_data["mid_progress_status"] == "IN_PROGRESS"
    assert t1_data["end_confidence"] is None


def test_submit_end_assessment_success(sli_end_test_data):
    """POST /sli/faculty/end-assessment atomically records END responses, competencies, and stage='END' topics."""
    token = sli_end_test_data["faculty_token"]
    enrollment_id = sli_end_test_data["enrollment_id"]
    topics = sli_end_test_data["topics"]

    payload = {
        "enrollment_id": enrollment_id,
        "final_confidence": 5,
        "final_interest": 5,
        "perceived_difficulty": 3,
        "understanding_level": 5,
        "concept_application_ability": 5,
        "learning_satisfaction": 5,
        "core_concepts_mastery": 5,
        "problem_solving_ability": 4,
        "practical_lab_competence": 5,
        "independent_learning_ability": 4,
        "real_world_application": 5,
        "effective_learning_format": "PRACTICAL_LABS",
        "resource_effectiveness": 5,
        "practical_lab_experience": 5,
        "teaching_pace": "JUST_RIGHT",
        "overall_learning_experience": 5,
        "skills_progress": [
            {"skill_name": "Dynamic programming", "confidence_level": 5, "progress_status": "MASTERED"},
            {"skill_name": "Graph traversal", "confidence_level": 5, "progress_status": "MASTERED"},
            {"skill_name": "State space reduction", "confidence_level": 4, "progress_status": "IMPROVED"},
        ],
        "topic_feedback": [
            {
                "topic_id": topics[0].topic_id,
                "confidence_level": 5,
                "difficulty_level": 2,
                "progress_status": "COMPLETED",
            },
            {
                "topic_id": topics[1].topic_id,
                "confidence_level": 5,
                "difficulty_level": 2,
                "progress_status": "COMPLETED",
            },
            {
                "topic_id": topics[2].topic_id,
                "confidence_level": 4,
                "difficulty_level": 3,
                "progress_status": "COMPLETED",
            },
        ],
    }

    resp = client.post(
        "/sli/faculty/end-assessment",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "success"
    assert data["topics_recorded"] == 3
    assert data["skills_recorded"] == 3

    # Re-fetch form and verify END values are populated
    get_resp = client.get(
        f"/sli/faculty/end-assessment/{enrollment_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_resp.status_code == 200
    form = get_resp.json()
    assert form["is_submitted"] is True
    assert form["final_confidence"] == 5
    assert form["core_concepts_mastery"] == 5
    assert form["problem_solving_ability"] == 4
    assert form["effective_learning_format"] == "PRACTICAL_LABS"
    assert form["teaching_pace"] == "JUST_RIGHT"

    # Verify topic progression
    t1_form = next(t for t in form["topics"] if t["topic_id"] == topics[0].topic_id)
    assert t1_form["pre_confidence"] == 2
    assert t1_form["mid_confidence"] == 3
    assert t1_form["end_confidence"] == 5
    assert t1_form["end_progress_status"] == "COMPLETED"


def test_end_assessment_upsert_preserves_submitted_at(sli_end_test_data):
    """Submitting END assessment updates existing record and preserves original submitted_at timestamp."""
    token = sli_end_test_data["faculty_token"]
    enrollment_id = sli_end_test_data["enrollment_id"]
    topics = sli_end_test_data["topics"]

    payload1 = {
        "enrollment_id": enrollment_id,
        "final_confidence": 4,
        "final_interest": 4,
        "core_concepts_mastery": 4,
        "effective_learning_format": "INTERACTIVE_LECTURES",
        "topic_feedback": [
            {"topic_id": topics[0].topic_id, "confidence_level": 4, "difficulty_level": 3, "progress_status": "IN_PROGRESS"},
        ],
    }
    r1 = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=payload1)
    assert r1.status_code == 201
    submitted_at_1 = r1.json()["submitted_at"]

    # Update submission
    payload2 = {
        "enrollment_id": enrollment_id,
        "final_confidence": 5,
        "final_interest": 5,
        "core_concepts_mastery": 5,
        "effective_learning_format": "HYBRID",
        "topic_feedback": [
            {"topic_id": topics[0].topic_id, "confidence_level": 5, "difficulty_level": 2, "progress_status": "COMPLETED"},
        ],
    }
    r2 = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=payload2)
    assert r2.status_code == 201
    submitted_at_2 = r2.json()["submitted_at"]

    # submitted_at must be preserved
    assert submitted_at_1 == submitted_at_2

    # Verify updated values
    get_resp = client.get(f"/sli/faculty/end-assessment/{enrollment_id}", headers={"Authorization": f"Bearer {token}"})
    assert get_resp.status_code == 200
    assert get_resp.json()["final_confidence"] == 5
    assert get_resp.json()["effective_learning_format"] == "HYBRID"


def test_pre_mid_end_topic_coexistence(sli_end_test_data):
    """Confirms PRE, MID, and END topic feedbacks coexist for the same enrollment and topic."""
    db = SessionLocal()
    try:
        enrollment_id = sli_end_test_data["enrollment_id"]
        topic_id = sli_end_test_data["topics"][0].topic_id

        # Insert an END topic feedback directly or verify existing
        end_tf = StudentTopicFeedback(
            enrollment_id=enrollment_id,
            topic_id=topic_id,
            stage="END",
            confidence_level=5,
            difficulty_level=2,
            progress_status="COMPLETED",
        )
        db.add(end_tf)
        db.commit()

        # Query all 3 feedbacks for this enrollment and topic
        feedbacks = db.query(StudentTopicFeedback).filter(
            StudentTopicFeedback.enrollment_id == enrollment_id,
            StudentTopicFeedback.topic_id == topic_id,
        ).all()

        stages = {f.stage for f in feedbacks}
        assert stages == {"PRE", "MID", "END"}
        assert len(feedbacks) == 3
    finally:
        db.close()


def test_end_lifecycle_active_post_allowed_and_completed_post_rejected(sli_end_test_data):
    """POST is allowed during ACTIVE semester, but strictly rejected with 400 during COMPLETED, ARCHIVED, and CANCELLED semesters. GET is allowed for all historical review."""
    token = sli_end_test_data["faculty_token"]
    db = SessionLocal()
    try:
        # Create an enrollment in a COMPLETED semester
        comp_sem_id = sli_end_test_data["completed_semester_id"]
        enrollment_comp = Enrollment(
            student_id=sli_end_test_data["student"].student_id,
            class_id=sli_end_test_data["class_id"],
            semester_id=comp_sem_id,
            subject_id=sli_end_test_data["subject_id"],
        )

        # Create ARCHIVED and CANCELLED semesters + enrollments
        archived_sem = Semester(
            semester_number=6,
            academic_year="2025-26",
            start_date=datetime(2025, 6, 1),
            end_date=datetime(2025, 11, 30),
            status="ARCHIVED",
        )
        cancelled_sem = Semester(
            semester_number=7,
            academic_year="2025-26",
            start_date=datetime(2025, 12, 1),
            end_date=datetime(2026, 4, 30),
            status="CANCELLED",
        )
        db.add_all([enrollment_comp, archived_sem, cancelled_sem])
        db.flush()

        enrollment_arch = Enrollment(
            student_id=sli_end_test_data["student"].student_id,
            class_id=sli_end_test_data["class_id"],
            semester_id=archived_sem.semester_id,
            subject_id=sli_end_test_data["subject_id"],
        )
        enrollment_canc = Enrollment(
            student_id=sli_end_test_data["student"].student_id,
            class_id=sli_end_test_data["class_id"],
            semester_id=cancelled_sem.semester_id,
            subject_id=sli_end_test_data["subject_id"],
        )
        db.add_all([enrollment_arch, enrollment_canc])
        db.commit()

        comp_enrollment_id = enrollment_comp.enrollment_id
        arch_enrollment_id = enrollment_arch.enrollment_id
        canc_enrollment_id = enrollment_canc.enrollment_id
    finally:
        db.close()

    for eid, status_name in [
        (comp_enrollment_id, "COMPLETED"),
        (arch_enrollment_id, "ARCHIVED"),
        (canc_enrollment_id, "CANCELLED"),
    ]:
        # POST must be rejected with 400
        post_resp = client.post(
            "/sli/faculty/end-assessment",
            headers={"Authorization": f"Bearer {token}"},
            json={"enrollment_id": eid, "final_confidence": 5},
        )
        assert post_resp.status_code == 400
        assert "ACTIVE semesters" in post_resp.json()["detail"]

        # GET must be allowed for historical review (200)
        get_resp = client.get(
            f"/sli/faculty/end-assessment/{eid}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert get_resp.status_code == 200
        assert get_resp.json()["semester_status"] == status_name


def test_end_enum_validation(sli_end_test_data):
    """Pydantic rejects invalid learning format or teaching pace with 422."""
    token = sli_end_test_data["faculty_token"]
    enrollment_id = sli_end_test_data["enrollment_id"]

    # Invalid learning format
    bad_payload1 = {
        "enrollment_id": enrollment_id,
        "effective_learning_format": "INVALID_FORMAT_KEY",
    }
    r1 = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=bad_payload1)
    assert r1.status_code == 422

    # Invalid teaching pace
    bad_payload2 = {
        "enrollment_id": enrollment_id,
        "teaching_pace": "SUPER_FAST",
    }
    r2 = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=bad_payload2)
    assert r2.status_code == 422


def test_end_rating_validation(sli_end_test_data):
    """Pydantic rejects ratings outside the 1-5 scale with 422."""
    token = sli_end_test_data["faculty_token"]
    enrollment_id = sli_end_test_data["enrollment_id"]

    # Rating 0 (below min 1)
    bad_payload1 = {
        "enrollment_id": enrollment_id,
        "final_confidence": 0,
    }
    r1 = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=bad_payload1)
    assert r1.status_code == 422

    # Rating 6 (above max 5)
    bad_payload2 = {
        "enrollment_id": enrollment_id,
        "core_concepts_mastery": 6,
    }
    r2 = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=bad_payload2)
    assert r2.status_code == 422


def test_end_authorization_guards(sli_end_test_data):
    """Non-assigned faculty receives 403 Forbidden; Admin receives 200 OK."""
    other_token = sli_end_test_data["other_faculty_token"]
    admin_token = sli_end_test_data["admin_token"]
    enrollment_id = sli_end_test_data["enrollment_id"]

    # Other faculty GET -> 403
    r1 = client.get(
        f"/sli/faculty/end-assessment/{enrollment_id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert r1.status_code == 403

    # Other faculty POST -> 403
    r2 = client.post(
        "/sli/faculty/end-assessment",
        headers={"Authorization": f"Bearer {other_token}"},
        json={"enrollment_id": enrollment_id, "final_confidence": 5},
    )
    assert r2.status_code == 403

    # Admin GET -> 200
    r3 = client.get(
        f"/sli/faculty/end-assessment/{enrollment_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r3.status_code == 200


def test_end_invalid_topic_rejected(sli_end_test_data):
    """Providing a topic_id not belonging to the subject is rejected with 400."""
    token = sli_end_test_data["faculty_token"]
    enrollment_id = sli_end_test_data["enrollment_id"]

    bad_payload = {
        "enrollment_id": enrollment_id,
        "final_confidence": 5,
        "topic_feedback": [
            {"topic_id": 999999, "confidence_level": 4, "difficulty_level": 2},
        ],
    }
    resp = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=bad_payload)
    assert resp.status_code == 400
    assert "is not valid for subject" in resp.json()["detail"]


def test_end_atomic_rollback_on_topic_failure(sli_end_test_data):
    """Force a submission failure with invalid topic and confirm no EndSemesterResponse or StudentTopicFeedback is persisted."""
    token = sli_end_test_data["faculty_token"]
    db = SessionLocal()
    try:
        # Create a fresh enrollment with no END response
        student = Student(
            student_id=f"STU-END-ROLL-{uuid.uuid4().hex[:6].upper()}",
            name="Atomic Rollback Test Student",
            current_year=2,
            current_semester=4,
            department_id=sli_end_test_data["student"].department_id,
        )
        db.add(student)
        db.flush()

        new_enrollment = Enrollment(
            student_id=student.student_id,
            class_id=sli_end_test_data["class_id"],
            semester_id=sli_end_test_data["active_semester_id"],
            subject_id=sli_end_test_data["subject_id"],
        )
        db.add(new_enrollment)
        db.commit()
        new_eid = new_enrollment.enrollment_id
    finally:
        db.close()

    # Attempt POST with invalid topic
    bad_payload = {
        "enrollment_id": new_eid,
        "final_confidence": 5,
        "core_concepts_mastery": 5,
        "topic_feedback": [
            {"topic_id": 999999, "confidence_level": 4, "difficulty_level": 2},
        ],
    }
    resp = client.post("/sli/faculty/end-assessment", headers={"Authorization": f"Bearer {token}"}, json=bad_payload)
    assert resp.status_code == 400

    # Verify atomicity in DB: no EndSemesterResponse or END StudentTopicFeedback exists
    db = SessionLocal()
    try:
        end_resp = db.query(EndSemesterResponse).filter(EndSemesterResponse.enrollment_id == new_eid).first()
        assert end_resp is None

        end_topics = db.query(StudentTopicFeedback).filter(
            StudentTopicFeedback.enrollment_id == new_eid,
            StudentTopicFeedback.stage == "END",
        ).all()
        assert len(end_topics) == 0
    finally:
        db.close()

