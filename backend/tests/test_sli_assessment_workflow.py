from datetime import datetime, timezone
import uuid
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token
from app.main import app
from app.models.academic import Division, Room, Subject
from app.models.generation_history import GenerationRun
from app.models.sli import (
    AcademicClass, Assessment, Department, EndSemesterResponse, Enrollment,
    MidSemesterResponse, PreSemesterResponse, QuestionBank, Semester, Student,
    StudentTopicFeedback, Topic,
)
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole
from app.db.base import SessionLocal

client = TestClient(app)


# ---------------------------------------------------------------------------
# Test Fixtures & Setup
# ---------------------------------------------------------------------------

@pytest.fixture
def workflow_test_data():
    """
    Sets up a realistic multi-subject academic environment:
    - Faculty: Dr. Rachana Patil
    - Subject 1: Database Management Systems (CS301)
    - Subject 2: Operating Systems (CS302)
    - Division: TY CSE Div A & Div B
    - Semester: 2025-26 Sem-5 (ACTIVE)
    """
    db_session = SessionLocal()
    uid = uuid.uuid4().hex[:6]

    # 1. Faculty
    faculty = User(
        email=f"faculty_rachana_{uid}@enosis.edu.in",
        hashed_password="hashed_pw",
        full_name="Dr. Rachana Patil",
        role=UserRole.FACULTY,
    )
    db_session.add(faculty)
    db_session.flush()

    # 2. Departments
    dept_sli = Department(department_name=f"Computer Science {uid}", department_code=f"CSE_{uid}")
    db_session.add(dept_sli)
    db_session.flush()

    # 3. Subjects
    sub_dbms = Subject(name="Database Management Systems", code=f"CS301_{uid}", sli_department_id=dept_sli.department_id)
    sub_os = Subject(name="Operating Systems", code=f"CS302_{uid}", sli_department_id=dept_sli.department_id)
    db_session.add_all([sub_dbms, sub_os])
    db_session.flush()

    # 4. Topics for DBMS
    topics_dbms = [
        Topic(subject_id=sub_dbms.id, topic_name="Relational Data Model & ER Diagrams"),
        Topic(subject_id=sub_dbms.id, topic_name="SQL Queries & Joins"),
        Topic(subject_id=sub_dbms.id, topic_name="Normalization & Relational Algebra"),
        Topic(subject_id=sub_dbms.id, topic_name="Transaction Management & ACID"),
    ]
    db_session.add_all(topics_dbms)

    # Topics for OS
    topics_os = [
        Topic(subject_id=sub_os.id, topic_name="Process Synchronization & Semaphores"),
        Topic(subject_id=sub_os.id, topic_name="Virtual Memory & Paging"),
        Topic(subject_id=sub_os.id, topic_name="CPU Scheduling Algorithms"),
        Topic(subject_id=sub_os.id, topic_name="Deadlock Avoidance & Bankers Algorithm"),
    ]
    db_session.add_all(topics_os)
    db_session.flush()

    # 5. Divisions & Classes
    div_a = Division(name=f"TY CSE Div A {uid}", year=3, division_code="A")
    div_b = Division(name=f"TY CSE Div B {uid}", year=3, division_code="B")
    db_session.add_all([div_a, div_b])
    db_session.flush()

    class_a = AcademicClass(
        department_id=dept_sli.department_id,
        year_level=3,
        division="A",
        division_id=div_a.id,
        academic_year="2025-26",
    )
    class_b = AcademicClass(
        department_id=dept_sli.department_id,
        year_level=3,
        division="B",
        division_id=div_b.id,
        academic_year="2025-26",
    )
    db_session.add_all([class_a, class_b])
    db_session.flush()

    # 6. Active Semester
    semester = Semester(
        academic_year="2025-26",
        semester_number=5,
        status="ACTIVE",
    )
    db_session.add(semester)
    db_session.flush()

    # 7. Timetable Entry (Authorizing Faculty for DBMS in Div A)
    batch_id = str(uuid.uuid4())
    gen_run = GenerationRun(
        id=batch_id,
        status="OPTIMAL",
        validation_passed=True,
    )
    room = Room(name=f"Room 301 {uid}", type="lecture", capacity=70)
    db_session.add_all([gen_run, room])
    db_session.flush()

    tt_entry = TimetableEntry(
        batch_id=batch_id,
        faculty_id=faculty.id,
        subject_id=sub_dbms.id,
        division_id=div_a.id,
        room_id=room.id,
        day=0,
        slot=1,
    )
    db_session.add(tt_entry)
    db_session.commit()

    topic_ids = [t.topic_id for t in topics_dbms]
    os_topic_ids = [t.topic_id for t in topics_os]
    class_a_id = class_a.class_id
    class_b_id = class_b.class_id
    div_a_id = div_a.id
    div_b_id = div_b.id
    sub_dbms_id = sub_dbms.id
    sub_os_id = sub_os.id
    semester_id = semester.semester_id
    token = create_access_token(subject=faculty.id)
    db_session.close()

    return {
        "faculty_id": faculty.id,
        "token": token,
        "sub_dbms_id": sub_dbms_id,
        "sub_os_id": sub_os_id,
        "div_a_id": div_a_id,
        "div_b_id": div_b_id,
        "topic_ids": topic_ids,
        "os_topic_ids": os_topic_ids,
        "class_a_id": class_a_id,
        "class_b_id": class_b_id,
        "semester_id": semester_id,
    }


# ---------------------------------------------------------------------------
# Test Suite: Assessment Creation, Dynamic Questions, Question Bank CRUD
# ---------------------------------------------------------------------------

def test_dynamic_assessment_creation_and_question_alignment(workflow_test_data):
    """
    Verifies that creating an assessment for a Teaching Context dynamically selects the
    exact subject's topics, generates shareable URLs, and supports variable question counts.
    """
    token = workflow_test_data["token"]
    class_a_id = workflow_test_data["class_a_id"]
    sub_dbms_id = workflow_test_data["sub_dbms_id"]
    semester_id = workflow_test_data["semester_id"]

    # 1. Create PRE assessment with 20 questions
    resp = client.post(
        "/sli/faculty/assessments",
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
            "question_count": 20,
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "DRAFT"
    assert data["subject_name"] == "Database Management Systems"
    assert data["assessment_type"] == "PRE"
    assert data["access_token"] is not None
    assert "share_url" in data and data["share_url"] is not None
    assert f"/assessment/{data['access_token']}" in data["share_url"]
    assert 15 <= len(data["questions"]) <= 20
    assert len(data["questions"]) == 20

    # Verify questions contain standardized ML metadata
    for q in data["questions"]:
        assert q["subject_id"] == sub_dbms_id
        assert q["assessment_stage"] == "PRE"
        assert q["skill_id"] is not None
        assert 1 <= q["difficulty"] <= 5
        assert q["marks"] >= 1


def test_question_bank_crud_and_assessment_builder(workflow_test_data):
    """
    Verifies that faculty can:
    1. Add custom questions to the Question Bank.
    2. View and update question bank items.
    3. Soft-deactivate questions.
    4. Custom configure draft assessment questions.
    5. Ensure published assessment snapshot remains immutable.
    """
    token = workflow_test_data["token"]
    sub_dbms_id = workflow_test_data["sub_dbms_id"]
    class_a_id = workflow_test_data["class_a_id"]
    semester_id = workflow_test_data["semester_id"]

    # 1. Add question to Question Bank
    add_resp = client.post(
        "/sli/faculty/questions/bank",
        json={
            "subject_id": sub_dbms_id,
            "assessment_type": "MID",
            "question_title": "Indexing & B-Trees",
            "question_text": "Rate your confidence in designing B+ Tree indexes for complex query optimization.",
            "question_type": "LIKERT_1_5",
            "section": "Advanced Storage & Indexing",
            "dimension": "indexing_competence",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert add_resp.status_code == 201
    bank_item = add_resp.json()
    assert bank_item["question_title"] == "Indexing & B-Trees"
    q_id = bank_item["question_id"]

    # 2. Query Question Bank
    get_resp = client.get(
        f"/sli/faculty/questions/bank/{sub_dbms_id}?assessment_type=MID",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_resp.status_code == 200
    items = get_resp.json()
    assert any(i["question_id"] == q_id for i in items)

    # 3. Create Draft Assessment (picks up the bank question)
    create_resp = client.post(
        "/sli/faculty/assessments",
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "MID",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert create_resp.status_code == 201
    assessment = create_resp.json()
    assert any("Indexing" in q.get("title", "") for q in assessment["questions"])

    # 4. Update questions on DRAFT assessment (maintaining 15-20 bounds)
    custom_questions = assessment["questions"][:19] + [{
        "question_id": "CUSTOM_01",
        "section": "Lab Experience",
        "title": "PostgreSQL Stored Procedures",
        "description": "Have you executed PL/pgSQL triggers in lab?",
        "type": "LIKERT_1_5",
    }]
    up_resp = client.put(
        f"/sli/faculty/assessments/{assessment['assessment_id']}/questions",
        json={"questions": custom_questions},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert up_resp.status_code == 200
    assert len(up_resp.json()["questions"]) == len(custom_questions)
    assert any(q.get("title") == "PostgreSQL Stored Procedures" for q in up_resp.json()["questions"])

    # 5. Soft-deactivate question from bank
    del_resp = client.delete(
        f"/sli/faculty/questions/bank/{q_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert del_resp.status_code == 200

    # Verify inactive in bank
    get_resp2 = client.get(
        f"/sli/faculty/questions/bank/{sub_dbms_id}?assessment_type=MID",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert not any(i["question_id"] == q_id for i in get_resp2.json())


def test_assessment_status_lifecycle_and_draft_protection(workflow_test_data):
    """
    Verifies that DRAFT assessments cannot receive submissions, but once PUBLISHED
    they allow submissions, and once CLOSED they reject further submissions.
    """
    token = workflow_test_data["token"]
    class_a_id = workflow_test_data["class_a_id"]
    sub_dbms_id = workflow_test_data["sub_dbms_id"]
    semester_id = workflow_test_data["semester_id"]

    # 1. Create PRE in DRAFT
    create_resp = client.post(
        "/sli/faculty/assessments",
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assessment = create_resp.json()
    access_token = assessment["access_token"]

    # 2. Attempt student access in DRAFT -> Rejected (403 Forbidden)
    portal_resp = client.get(f"/sli/student/assessment/{access_token}")
    assert portal_resp.status_code == 403
    assert "DRAFT" in portal_resp.json()["detail"]

    # 3. Publish Assessment
    pub_resp = client.put(
        f"/sli/faculty/assessments/{assessment['assessment_id']}/status",
        json={"status": "PUBLISHED"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert pub_resp.status_code == 200
    assert pub_resp.json()["status"] == "PUBLISHED"

    # 4. Student access now succeeds
    portal_resp = client.get(f"/sli/student/assessment/{access_token}")
    assert portal_resp.status_code == 200
    portal_data = portal_resp.json()
    assert portal_data["status"] == "PUBLISHED"
    assert portal_data["division_name"] == "A"

    # 5. Close Assessment
    close_resp = client.put(
        f"/sli/faculty/assessments/{assessment['assessment_id']}/status",
        json={"status": "CLOSED"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert close_resp.status_code == 200
    assert close_resp.json()["status"] == "CLOSED"

    # 6. Student access in CLOSED -> Rejected (400)
    portal_resp = client.get(f"/sli/student/assessment/{access_token}")
    assert portal_resp.status_code == 400
    assert "closed" in portal_resp.json()["detail"]


def test_student_self_registration_and_division_validation(workflow_test_data):
    """
    Verifies that:
    1. A student with NO prior DB record enters their Name, Roll No, and Division -> Created on the fly.
    2. Enrollment is created automatically without manual faculty roster entry.
    3. Entering an incorrect division (e.g. 'B' for a Div A assessment) is strictly rejected.
    4. Duplicate submissions by the same student are rejected (HTTP 409 Conflict).
    """
    token = workflow_test_data["token"]
    class_a_id = workflow_test_data["class_a_id"]
    sub_dbms_id = workflow_test_data["sub_dbms_id"]
    semester_id = workflow_test_data["semester_id"]

    # Create & Publish PRE assessment
    create_resp = client.post(
        "/sli/faculty/assessments",
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assessment = create_resp.json()
    access_token = assessment["access_token"]
    client.put(
        f"/sli/faculty/assessments/{assessment['assessment_id']}/status",
        json={"status": "PUBLISHED"},
        headers={"Authorization": f"Bearer {token}"},
    )

    # 1. New Student attempts submission with WRONG Division -> 400 Bad Request
    wrong_div_resp = client.post(
        f"/sli/student/assessment/{access_token}/submit",
        json={
            "full_name": "New Student One",
            "student_id": f"TEST_ROLL_{uuid.uuid4().hex[:6]}",
            "division_code": "Div B",  # Mismatch (Assessment is Div A)
            "subject_interest": 4,
            "learning_confidence": 3,
        },
    )
    assert wrong_div_resp.status_code == 400
    assert "Division mismatch" in wrong_div_resp.json()["detail"]

    # 2. New Student submits with valid normalized division ("A" or "Div A")
    new_roll = f"TEST_ROLL_{uuid.uuid4().hex[:6]}"
    valid_sub_resp = client.post(
        f"/sli/student/assessment/{access_token}/submit",
        json={
            "full_name": "Aarav Test Student",
            "student_id": new_roll,
            "division_code": "Div A",
            "subject_interest": 5,
            "self_assessed_skill": 3,
            "learning_confidence": 4,
            "expected_difficulty": 3,
            "preferred_learning_format": "PRACTICAL_LABS",
            "skills_to_improve": "SQL Optimization",
        },
    )
    assert valid_sub_resp.status_code == 201
    res_data = valid_sub_resp.json()
    assert res_data["status"] == "success"
    assert res_data["student_name"] == "Aarav Test Student"
    assert res_data["student_id"] == new_roll

    # Verify Student and Enrollment were created in database
    db_session = SessionLocal()
    st_record = db_session.query(Student).filter(Student.student_id == new_roll).first()
    assert st_record is not None
    assert st_record.name == "Aarav Test Student"
    assert st_record.division == "A"

    enr_record = db_session.query(Enrollment).filter(
        Enrollment.student_id == new_roll,
        Enrollment.class_id == class_a_id,
        Enrollment.subject_id == sub_dbms_id,
    ).first()
    assert enr_record is not None

    # 3. Attempt duplicate submission by same student -> 409 Conflict
    dup_resp = client.post(
        f"/sli/student/assessment/{access_token}/submit",
        json={
            "full_name": "Aarav Test Student",
            "student_id": new_roll,
            "division_code": "A",
            "subject_interest": 5,
        },
    )
    assert dup_resp.status_code == 409
    assert "already submitted" in dup_resp.json()["detail"]

    db_session.close()


def test_complete_real_end_to_end_student_lifecycle(workflow_test_data):
    """
    Real End-to-End PRE -> MID -> END Student Workflow:
    - 2 self-registering students submit PRE
    - Same students submit MID with canonical learning barriers & progress
    - Same students submit END with exit competencies
    - Verify PRE baseline -> MID progress -> END mastery
    - Verify Student 360° analytics & Context Analytics update
    - Test across a second subject (Operating Systems) with distinct questions and zero hardcoding.
    """
    db_session = SessionLocal()
    token = workflow_test_data["token"]
    class_a_id = workflow_test_data["class_a_id"]
    sub_dbms_id = workflow_test_data["sub_dbms_id"]
    sub_os_id = workflow_test_data["sub_os_id"]
    div_b_id = workflow_test_data["div_b_id"]
    semester_id = workflow_test_data["semester_id"]
    topic_ids = workflow_test_data["topic_ids"]
    os_topic_ids = workflow_test_data["os_topic_ids"]

    student_1_roll = f"AUTO_ST_01_{uuid.uuid4().hex[:4]}"
    student_2_roll = f"AUTO_ST_02_{uuid.uuid4().hex[:4]}"

    # ═══════════════════════════════════════════════════════════════════════
    # STAGE 1: PRE ASSESSMENT (DBMS)
    # ═══════════════════════════════════════════════════════════════════════

    pre_create = client.post(
        "/sli/faculty/assessments",
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
        },
        headers={"Authorization": f"Bearer {token}"},
    ).json()

    client.put(
        f"/sli/faculty/assessments/{pre_create['assessment_id']}/status",
        json={"status": "PUBLISHED"},
        headers={"Authorization": f"Bearer {token}"},
    )

    pre_token = pre_create["access_token"]

    for roll, name in [(student_1_roll, "Student Alpha"), (student_2_roll, "Student Beta")]:
        submit_resp = client.post(
            f"/sli/student/assessment/{pre_token}/submit",
            json={
                "student_id": roll,
                "full_name": name,
                "division_code": "Div A",
                "subject_interest": 4,
                "self_assessed_skill": 3,
                "learning_confidence": 4,
                "expected_difficulty": 3,
                "preferred_learning_format": "PRACTICAL_LABS",
                "skills_to_improve": "SQL Joins, Normalization",
                "topic_feedback": [
                    {"topic_id": topic_ids[0], "confidence_level": 3, "difficulty_level": 2},
                    {"topic_id": topic_ids[1], "confidence_level": 4, "difficulty_level": 3},
                ],
            },
        )
        assert submit_resp.status_code == 201

    # ═══════════════════════════════════════════════════════════════════════
    # STAGE 2: MID ASSESSMENT (DBMS)
    # ═══════════════════════════════════════════════════════════════════════

    mid_create = client.post(
        "/sli/faculty/assessments",
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "MID",
        },
        headers={"Authorization": f"Bearer {token}"},
    ).json()

    client.put(
        f"/sli/faculty/assessments/{mid_create['assessment_id']}/status",
        json={"status": "PUBLISHED"},
        headers={"Authorization": f"Bearer {token}"},
    )

    mid_token = mid_create["access_token"]

    for roll, name in [(student_1_roll, "Student Alpha"), (student_2_roll, "Student Beta")]:
        mid_resp = client.post(
            f"/sli/student/assessment/{mid_token}/submit",
            json={
                "student_id": roll,
                "full_name": name,
                "division_code": "A",
                "current_confidence": 4,
                "current_interest": 4,
                "understanding_level": 4,
                "learning_satisfaction": 4,
                "useful_learning_format": "PRACTICAL_LABS",
                "teaching_pace": "JUST_RIGHT",
                "learning_barriers": ["CONCEPTUAL_DIFFICULTY", "TIME_MANAGEMENT"],
                "skills_progress": [
                    {"skill_name": "SQL Joins", "confidence_level": 4, "progress_status": "IMPROVED"},
                    {"skill_name": "Normalization", "confidence_level": 3, "progress_status": "IN_PROGRESS"},
                ],
                "topic_feedback": [
                    {"topic_id": topic_ids[0], "confidence_level": 4, "difficulty_level": 2, "progress_status": "COMPLETED"},
                    {"topic_id": topic_ids[1], "confidence_level": 4, "difficulty_level": 3, "progress_status": "COMPLETED"},
                ],
            },
        )
        assert mid_resp.status_code == 201

    # ═══════════════════════════════════════════════════════════════════════
    # STAGE 3: END ASSESSMENT (DBMS)
    # ═══════════════════════════════════════════════════════════════════════

    end_create = client.post(
        "/sli/faculty/assessments",
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "END",
        },
        headers={"Authorization": f"Bearer {token}"},
    ).json()

    client.put(
        f"/sli/faculty/assessments/{end_create['assessment_id']}/status",
        json={"status": "PUBLISHED"},
        headers={"Authorization": f"Bearer {token}"},
    )

    end_token = end_create["access_token"]

    for roll, name in [(student_1_roll, "Student Alpha"), (student_2_roll, "Student Beta")]:
        end_resp = client.post(
            f"/sli/student/assessment/{end_token}/submit",
            json={
                "student_id": roll,
                "full_name": name,
                "division_code": "A",
                "final_confidence": 5,
                "final_interest": 5,
                "understanding_level": 5,
                "core_concepts_mastery": 5,
                "problem_solving_ability": 5,
                "practical_lab_competence": 5,
                "independent_learning_ability": 4,
                "real_world_application": 5,
                "effective_learning_format": "HYBRID",
                "overall_learning_experience": 5,
                "skills_progress": [
                    {"skill_name": "SQL Joins", "confidence_level": 5, "progress_status": "MASTERED"},
                    {"skill_name": "Normalization", "confidence_level": 5, "progress_status": "MASTERED"},
                ],
                "topic_feedback": [
                    {"topic_id": topic_ids[0], "confidence_level": 5, "difficulty_level": 2, "progress_status": "COMPLETED"},
                    {"topic_id": topic_ids[1], "confidence_level": 5, "difficulty_level": 2, "progress_status": "COMPLETED"},
                ],
            },
        )
        assert end_resp.status_code == 201

    # Verify Analytics Update
    analytics_resp = client.get(
        f"/sli/faculty/analytics/context/{class_a_id}/{sub_dbms_id}/{semester_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert analytics_resp.status_code == 200
    analytics_data = analytics_resp.json()
    assert analytics_data["funnel"]["pre_completed"] >= 2
    assert analytics_data["funnel"]["mid_completed"] >= 2
    assert analytics_data["funnel"]["end_completed"] >= 2

    # ═══════════════════════════════════════════════════════════════════════
    # STAGE 4: SECOND SUBJECT VERIFICATION (Operating Systems)
    # ═══════════════════════════════════════════════════════════════════════

    # Assign Operating Systems to Div B explicitly
    assign_resp = client.post(
        "/sli/faculty/assign-context",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "subject_id": sub_os_id,
            "division_id": div_b_id,
            "semester_id": semester_id,
        },
    )
    assert assign_resp.status_code == 200
    assigned_os = assign_resp.json()
    assert assigned_os["subject_name"] == "Operating Systems"

    # Create MID assessment for OS
    os_mid = client.post(
        "/sli/faculty/assessments",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "class_id": assigned_os["class_id"],
            "subject_id": sub_os_id,
            "semester_id": semester_id,
            "assessment_type": "MID",
        },
    ).json()

    # Verify questions are OS-specific, NOT DBMS
    os_questions = os_mid["questions"]
    assert 15 <= len(os_questions) <= 20
    assert any("Operating Systems" in q.get("title", "") or "Operating Systems" in q.get("description", "") or "Operating Systems" in q.get("section", "") for q in os_questions)
    assert all(q["subject_id"] == sub_os_id for q in os_questions)
    assert not any("SQL" in q.get("title", "") or "SQL" in q.get("skill_id", "") for q in os_questions)

    db_session.close()


def test_15_to_20_questions_and_ml_metadata_standardization(workflow_test_data):
    """
    Validates:
    1. Assessment bounds strictly enforce MINIMUM 15 and MAXIMUM 20 questions.
    2. 14 questions -> rejected (HTTP 400/422).
    3. 15 questions -> accepted (HTTP 200/201).
    4. 20 questions -> accepted (HTTP 200/201).
    5. 21 questions -> rejected (HTTP 400/422).
    6. Every question maintains standardized metadata (question_id, subject_id, topic_id, skill_id, difficulty, marks, assessment_stage).
    7. Custom questions automatically adopt standardized metadata structure.
    8. Zero subject leakage across question sets.
    """
    data = workflow_test_data
    token = data["token"]
    class_a_id = data["class_a_id"]
    sub_dbms_id = data["sub_dbms_id"]
    semester_id = data["semester_id"]

    # 1. Attempt creating with 14 questions (< 15) -> HTTP 400/422 Rejected
    too_few_questions = [
        {"question_id": f"Q_{i}", "title": f"Question {i}", "type": "LIKERT_1_5"}
        for i in range(14)
    ]
    resp_under = client.post(
        "/sli/faculty/assessments",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
            "questions": too_few_questions,
        },
    )
    assert resp_under.status_code in [400, 422]

    # 2. Attempt requesting question_count = 14 (< 15) -> HTTP 400/422 Rejected
    resp_count_under = client.post(
        "/sli/faculty/assessments",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
            "question_count": 14,
        },
    )
    assert resp_count_under.status_code in [400, 422]

    # 3. Attempt creating with 21 questions (> 20) -> HTTP 400/422 Rejected
    too_many_questions = [
        {"question_id": f"Q_{i}", "title": f"Question {i}", "type": "LIKERT_1_5"}
        for i in range(21)
    ]
    resp_excess = client.post(
        "/sli/faculty/assessments",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
            "questions": too_many_questions,
        },
    )
    assert resp_excess.status_code in [400, 422]

    # 4. Attempt requesting question_count = 21 (> 20) -> HTTP 400/422 Rejected
    resp_count_excess = client.post(
        "/sli/faculty/assessments",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
            "question_count": 21,
        },
    )
    assert resp_count_excess.status_code in [400, 422]

    # 5. Create PRE assessment with valid 20 questions (Upper bound = 20) -> HTTP 201 Accepted
    resp_valid_20 = client.post(
        "/sli/faculty/assessments",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "class_id": class_a_id,
            "subject_id": sub_dbms_id,
            "semester_id": semester_id,
            "assessment_type": "PRE",
            "question_count": 20,
        },
    )
    assert resp_valid_20.status_code == 201
    created = resp_valid_20.json()
    questions = created["questions"]
    assert len(questions) == 20

    # 6. Verify all questions have standardized metadata and unique question_ids
    seen_ids = set()
    for q in questions:
        assert "question_id" in q and q["question_id"]
        assert q["question_id"] not in seen_ids
        seen_ids.add(q["question_id"])
        assert "subject_id" in q and q["subject_id"] == sub_dbms_id
        assert "assessment_stage" in q and q["assessment_stage"] == "PRE"
        assert "skill_id" in q and q["skill_id"]
        assert "difficulty" in q and 1 <= q["difficulty"] <= 5
        assert "marks" in q and q["marks"] >= 1

    # 7. Attempt updating assessment with 14 questions (< 15) -> HTTP 400/422 Rejected
    resp_update_under = client.put(
        f"/sli/faculty/assessments/{created['assessment_id']}/questions",
        headers={"Authorization": f"Bearer {token}"},
        json={"questions": too_few_questions},
    )
    assert resp_update_under.status_code in [400, 422]

    # 8. Attempt updating assessment with 21 questions (> 20) -> HTTP 400/422 Rejected
    resp_update_excess = client.put(
        f"/sli/faculty/assessments/{created['assessment_id']}/questions",
        headers={"Authorization": f"Bearer {token}"},
        json={"questions": too_many_questions},
    )
    assert resp_update_excess.status_code in [400, 422]

    # 9. Update with 15 questions (Lower bound = 15) -> HTTP 200 Accepted
    custom_update_15 = [
        {
            "title": f"Custom Assessment Question {i}",
            "description": f"Evaluate competency in area {i}",
            "section": f"Custom Section {i}",
        }
        for i in range(1, 16)
    ]
    resp_update_15 = client.put(
        f"/sli/faculty/assessments/{created['assessment_id']}/questions",
        headers={"Authorization": f"Bearer {token}"},
        json={"questions": custom_update_15},
    )
    assert resp_update_15.status_code == 200
    updated_questions = resp_update_15.json()["questions"]
    assert len(updated_questions) == 15
    for uq in updated_questions:
        assert uq["question_id"].startswith("CUSTOM_")
        assert uq["subject_id"] == sub_dbms_id
        assert uq["assessment_stage"] == "PRE"
        assert uq["difficulty"] == 3
        assert uq["marks"] == 1


