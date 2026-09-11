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
def analytics_test_data():
    db = SessionLocal()
    try:
        # Create department
        dept_name = f"Dept_Analytics_{uuid.uuid4().hex[:6]}"
        dept = Department(department_name=dept_name, department_code=f"D_{uuid.uuid4().hex[:4].upper()}")
        db.add(dept)
        db.flush()

        # Create Users
        faculty_user = User(
            id=str(uuid.uuid4()),
            email=f"faculty.analytics_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Faculty@123"),
            full_name="Dr. Alan Turing",
            role=UserRole.FACULTY,
            department=dept_name,
        )
        other_faculty_user = User(
            id=str(uuid.uuid4()),
            email=f"other.analytics_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Faculty@123"),
            full_name="Prof. Ada Lovelace",
            role=UserRole.FACULTY,
            department=dept_name,
        )
        admin_user = User(
            id=str(uuid.uuid4()),
            email=f"admin.analytics_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Admin@123"),
            full_name="Dean Administration",
            role=UserRole.ADMIN,
            department=dept_name,
        )
        db.add_all([faculty_user, other_faculty_user, admin_user])
        db.flush()

        # Create Semester
        semester = Semester(
            academic_year="2026-27",
            semester_number=5,
            status="ACTIVE",
        )
        db.add(semester)
        db.flush()

        # Create Subject
        subject = Subject(
            id=str(uuid.uuid4()),
            name="Distributed Systems",
            code=f"DS{uuid.uuid4().hex[:4].upper()}",
            credits=4,
        )
        db.add(subject)
        db.flush()

        # Create Topics
        t1 = Topic(subject_id=subject.id, topic_name="Consensus Protocols & Paxos")
        t2 = Topic(subject_id=subject.id, topic_name="Vector Clocks & Causality")
        t3 = Topic(subject_id=subject.id, topic_name="Raft Algorithm & Leader Election")
        db.add_all([t1, t2, t3])
        db.flush()

        # Create Division and AcademicClass
        division = Division(
            id=str(uuid.uuid4()),
            name="TE Computer Division A",
            year=3,
            division_code="A",
        )
        db.add(division)
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

        # Create Room and Timetable Entry for faculty_user
        batch = str(uuid.uuid4())
        gen_run = GenerationRun(id=batch, status="OPTIMAL", validation_passed=True)
        room = Room(name="Room 401", type="lecture", capacity=70)
        db.add_all([gen_run, room])
        db.flush()

        tt_entry = TimetableEntry(
            id=str(uuid.uuid4()),
            batch_id=batch,
            division_id=division.id,
            subject_id=subject.id,
            faculty_id=faculty_user.id,
            room_id=room.id,
            day=1,
            slot=1,
        )
        db.add(tt_entry)
        db.flush()

        # Create 3 Students with Different Assessment Profiles
        # Student 1: Full PRE+MID+END with Positive Trajectory
        s1 = Student(student_id=f"STU-AN-1-{uuid.uuid4().hex[:4].upper()}", name="Aarav Sharma", department_id=dept.department_id, current_year=3, division="A")
        # Student 2: Full PRE+MID+END with Critical Risk (Low Confidence + Drop + Incomplete Topics)
        s2 = Student(student_id=f"STU-AN-2-{uuid.uuid4().hex[:4].upper()}", name="Bhavna Patel", department_id=dept.department_id, current_year=3, division="A")
        # Student 3: PRE-only (Partial assessment state)
        s3 = Student(student_id=f"STU-AN-3-{uuid.uuid4().hex[:4].upper()}", name="Chirag Rao", department_id=dept.department_id, current_year=3, division="A")
        db.add_all([s1, s2, s3])
        db.flush()

        e1 = Enrollment(student_id=s1.student_id, class_id=academic_class.class_id, semester_id=semester.semester_id, subject_id=subject.id)
        e2 = Enrollment(student_id=s2.student_id, class_id=academic_class.class_id, semester_id=semester.semester_id, subject_id=subject.id)
        e3 = Enrollment(student_id=s3.student_id, class_id=academic_class.class_id, semester_id=semester.semester_id, subject_id=subject.id)
        db.add_all([e1, e2, e3])
        db.flush()

        # S1 Assessments (Positive)
        p1 = PreSemesterResponse(enrollment_id=e1.enrollment_id, subject_interest=3, learning_confidence=2, expected_difficulty=4, skills_to_improve="Paxos, Raft", preferred_learning_format="PRACTICAL_LABS")
        m1 = MidSemesterResponse(enrollment_id=e1.enrollment_id, current_confidence=4, current_interest=4, perceived_difficulty=3, understanding_level=4, learning_satisfaction=4, useful_learning_format="PRACTICAL_LABS", teaching_pace="JUST_RIGHT", skills_progress=[{"skill_name": "Paxos", "confidence_level": 4, "progress_status": "IMPROVED"}])
        end1 = EndSemesterResponse(enrollment_id=e1.enrollment_id, final_confidence=5, final_interest=5, perceived_difficulty=2, understanding_level=5, learning_satisfaction=5, effective_learning_format="PRACTICAL_LABS", teaching_pace="JUST_RIGHT", overall_learning_experience=5, skills_progress=[{"skill_name": "Paxos", "confidence_level": 5, "progress_status": "MASTERED"}])
        db.add_all([p1, m1, end1])

        # S1 Topic Feedbacks (All completed with high confidence)
        for t in [t1, t2, t3]:
            db.add_all([
                StudentTopicFeedback(enrollment_id=e1.enrollment_id, topic_id=t.topic_id, stage="PRE", confidence_level=2, difficulty_level=4),
                StudentTopicFeedback(enrollment_id=e1.enrollment_id, topic_id=t.topic_id, stage="MID", confidence_level=4, difficulty_level=3, progress_status="IN_PROGRESS"),
                StudentTopicFeedback(enrollment_id=e1.enrollment_id, topic_id=t.topic_id, stage="END", confidence_level=5, difficulty_level=2, progress_status="COMPLETED"),
            ])

        # S2 Assessments (Critical Risk: Drop 4 -> 2, Stagnant Skill, Unresolved Topics)
        p2 = PreSemesterResponse(enrollment_id=e2.enrollment_id, subject_interest=4, learning_confidence=4, expected_difficulty=3, skills_to_improve="Consensus", preferred_learning_format="INTERACTIVE_LECTURES")
        m2 = MidSemesterResponse(enrollment_id=e2.enrollment_id, current_confidence=3, current_interest=3, perceived_difficulty=4, understanding_level=2, learning_satisfaction=2, useful_learning_format="INTERACTIVE_LECTURES", teaching_pace="TOO_FAST", learning_barriers=["CONCEPTUAL_DIFFICULTY"], skills_progress=[{"skill_name": "Consensus", "confidence_level": 2, "progress_status": "IN_PROGRESS"}])
        end2 = EndSemesterResponse(enrollment_id=e2.enrollment_id, final_confidence=2, final_interest=2, perceived_difficulty=5, understanding_level=2, learning_satisfaction=2, effective_learning_format="INTERACTIVE_LECTURES", teaching_pace="TOO_FAST", overall_learning_experience=2, skills_progress=[{"skill_name": "Consensus", "confidence_level": 2, "progress_status": "IN_PROGRESS"}])
        db.add_all([p2, m2, end2])

        # S2 Topic Feedbacks (Multiple Unresolved at END)
        db.add_all([
            StudentTopicFeedback(enrollment_id=e2.enrollment_id, topic_id=t1.topic_id, stage="PRE", confidence_level=4, difficulty_level=3),
            StudentTopicFeedback(enrollment_id=e2.enrollment_id, topic_id=t1.topic_id, stage="MID", confidence_level=3, difficulty_level=4, progress_status="IN_PROGRESS"),
            StudentTopicFeedback(enrollment_id=e2.enrollment_id, topic_id=t1.topic_id, stage="END", confidence_level=2, difficulty_level=5, progress_status="IN_PROGRESS"),

            StudentTopicFeedback(enrollment_id=e2.enrollment_id, topic_id=t2.topic_id, stage="PRE", confidence_level=3, difficulty_level=3),
            StudentTopicFeedback(enrollment_id=e2.enrollment_id, topic_id=t2.topic_id, stage="MID", confidence_level=2, difficulty_level=5, progress_status="NOT_STARTED"),
            StudentTopicFeedback(enrollment_id=e2.enrollment_id, topic_id=t2.topic_id, stage="END", confidence_level=1, difficulty_level=5, progress_status="NOT_STARTED"),
        ])

        # S3 Assessments (PRE-only)
        p3 = PreSemesterResponse(enrollment_id=e3.enrollment_id, subject_interest=5, learning_confidence=3, expected_difficulty=3, skills_to_improve="Vector Clocks", preferred_learning_format="HYBRID")
        db.add(p3)

        db.commit()

        # JWT Tokens
        faculty_token = create_access_token(subject=faculty_user.id)
        other_faculty_token = create_access_token(subject=other_faculty_user.id)
        admin_token = create_access_token(subject=admin_user.id)

        yield {
            "faculty_token": faculty_token,
            "other_faculty_token": other_faculty_token,
            "admin_token": admin_token,
            "class_id": academic_class.class_id,
            "subject_id": subject.id,
            "semester_id": semester.semester_id,
            "enrollment_ids": [e1.enrollment_id, e2.enrollment_id, e3.enrollment_id],
            "e1_id": e1.enrollment_id,
            "e2_id": e2.enrollment_id,
            "e3_id": e3.enrollment_id,
            "topics": [t1, t2, t3],
        }
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Test Cases
# ---------------------------------------------------------------------------

def test_context_analytics_full_aggregation(analytics_test_data):
    """Context analytics returns correct assessment funnel, cohort trajectories, topic metrics, and risk findings."""
    token = analytics_test_data["faculty_token"]
    class_id = analytics_test_data["class_id"]
    subject_id = analytics_test_data["subject_id"]
    semester_id = analytics_test_data["semester_id"]

    resp = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    # 1. Funnel
    funnel = data["funnel"]
    assert funnel["total_enrolled"] == 3
    assert funnel["pre_completed"] == 3
    assert funnel["mid_completed"] == 2
    assert funnel["end_completed"] == 2
    assert funnel["fully_assessed"] == 2

    # 2. Trajectories (Averages non-null values only)
    # Pre: 2 (s1), 4 (s2), 3 (s3) -> avg = 3.0
    # Mid: 4 (s1), 3 (s2) -> avg = 3.5
    # End: 5 (s1), 2 (s2) -> avg = 3.5
    traj = data["trajectories"]
    assert traj["confidence"]["pre"] == 3.0
    assert traj["confidence"]["mid"] == 3.5
    assert traj["confidence"]["end"] == 3.5

    # 3. Topics
    topics = data["topics"]
    assert len(topics) == 3

    # 4. Skills
    skills = data["skills"]
    assert skills["total_tracked_skills"] == 2
    assert skills["mastered_count"] == 1
    assert skills["in_progress_count"] == 1
    assert skills["stagnant_skills_count"] == 1

    # 5. Learning Experience (Pace friction = 50% at END due to 1 TOO_FAST out of 2)
    lexp = data["learning_experience"]
    assert lexp["pace_friction_end_pct"] == 50.0
    assert lexp["barriers_frequency"].get("CONCEPTUAL_DIFFICULTY") == 1

    # 6. Risk Findings (High pace friction + stagnant skills)
    findings = data["risk_findings"]
    rules = {f["rule_id"] for f in findings}
    assert "COHORT_PACE_FRICTION" in rules
    assert "COHORT_SKILL_STAGNATION" in rules


def test_student_longitudinal_analytics(analytics_test_data):
    """Student 360° analytics returns full trajectory, topic progression, skill continuity, and deterministic risk findings."""
    token = analytics_test_data["faculty_token"]
    e2_id = analytics_test_data["e2_id"]

    resp = client.get(
        f"/sli/faculty/analytics/student/{e2_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["enrollment_id"] == e2_id
    assert data["has_pre"] is True
    assert data["has_mid"] is True
    assert data["has_end"] is True
    assert data["is_fully_assessed"] is True

    # Check Trajectory (4 -> 3 -> 2, delta = -2)
    assert data["confidence"]["pre"] == 4.0
    assert data["confidence"]["mid"] == 3.0
    assert data["confidence"]["end"] == 2.0
    assert data["confidence"]["delta_end_pre"] == -2.0

    # Check Risk Findings for Student 2
    findings = data["risk_findings"]
    rules = {f["rule_id"] for f in findings}
    assert "GAP_LOW_FINAL_CONF" in rules
    assert "GAP_SEVERE_CONF_DROP" in rules
    assert "GAP_MULTIPLE_UNRESOLVED" in rules
    assert "GAP_SKILL_STAGNATION" in rules
    assert "GAP_PERSISTENT_BARRIER" in rules

    # Verify no action prescriptions are present in explanations
    for f in findings:
        assert "should" not in f["explanation"].lower()
        assert "conduct" not in f["explanation"].lower()
        assert "session" not in f["explanation"].lower()


def test_student_longitudinal_analytics_pre_only(analytics_test_data):
    """PRE-only student computes baseline metrics cleanly without null pointer errors."""
    token = analytics_test_data["faculty_token"]
    e3_id = analytics_test_data["e3_id"]

    resp = client.get(
        f"/sli/faculty/analytics/student/{e3_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["has_pre"] is True
    assert data["has_mid"] is False
    assert data["has_end"] is False
    assert data["is_fully_assessed"] is False

    assert data["confidence"]["pre"] == 3.0
    assert data["confidence"]["mid"] is None
    assert data["confidence"]["end"] is None
    assert data["confidence"]["delta_end_pre"] is None


def test_context_attention_roster(analytics_test_data):
    """Attention roster returns flagged students sorted by severity (CRITICAL first)."""
    token = analytics_test_data["faculty_token"]
    class_id = analytics_test_data["class_id"]
    subject_id = analytics_test_data["subject_id"]
    semester_id = analytics_test_data["semester_id"]

    resp = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}/attention-roster",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["total_flagged_students"] >= 1
    assert data["critical_count"] >= 1

    # First student must be Student 2 with CRITICAL severity
    first_student = data["students"][0]
    assert first_student["enrollment_id"] == analytics_test_data["e2_id"]
    assert first_student["highest_severity"] == "CRITICAL"
    assert first_student["risk_count"] >= 3


def test_analytics_authorization_enforcement(analytics_test_data):
    """Unassigned faculty receives 403 Forbidden; Admin receives 200 OK."""
    other_token = analytics_test_data["other_faculty_token"]
    admin_token = analytics_test_data["admin_token"]
    class_id = analytics_test_data["class_id"]
    subject_id = analytics_test_data["subject_id"]
    semester_id = analytics_test_data["semester_id"]
    e1_id = analytics_test_data["e1_id"]

    # Other faculty context -> 403
    r1 = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert r1.status_code == 403

    # Other faculty student -> 403
    r2 = client.get(
        f"/sli/faculty/analytics/student/{e1_id}",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert r2.status_code == 403

    # Admin context -> 200
    r3 = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r3.status_code == 200

    # Admin student -> 200
    r4 = client.get(
        f"/sli/faculty/analytics/student/{e1_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r4.status_code == 200


def test_context_interventions_tracker(analytics_test_data):
    """Context-wide intervention tracker returns logged interventions with student details and respects filters."""
    faculty_token = analytics_test_data["faculty_token"]
    other_token = analytics_test_data["other_faculty_token"]
    class_id = analytics_test_data["class_id"]
    subject_id = analytics_test_data["subject_id"]
    semester_id = analytics_test_data["semester_id"]
    e1_id = analytics_test_data["e1_id"]
    e2_id = analytics_test_data["e2_id"]

    # Log two interventions for this context: one COMPLETED, one PLANNED (PENDING)
    r_log1 = client.post(
        "/sli/interventions/log",
        json={
            "enrollment_id": e1_id,
            "intervention_type": "One-on-One Tutoring",
            "status": "COMPLETED",
            "notes": "Reviewed core algorithms.",
        },
        headers={"Authorization": f"Bearer {faculty_token}"},
    )
    assert r_log1.status_code == 201

    r_log2 = client.post(
        "/sli/interventions/log",
        json={
            "enrollment_id": e2_id,
            "intervention_type": "Remedial Problem Set",
            "status": "PLANNED",
            "notes": "Assigned remedial worksheet for topics 1 and 2.",
        },
        headers={"Authorization": f"Bearer {faculty_token}"},
    )
    assert r_log2.status_code == 201

    # 1. Fetch all interventions for context
    resp_all = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}/interventions",
        headers={"Authorization": f"Bearer {faculty_token}"},
    )
    assert resp_all.status_code == 200
    all_data = resp_all.json()
    assert len(all_data) >= 2
    types = [item["intervention_type"] for item in all_data]
    assert "One-on-One Tutoring" in types
    assert "Remedial Problem Set" in types

    # Check student identification is populated
    item1 = next(item for item in all_data if item["enrollment_id"] == e1_id)
    assert item1["student_name"] is not None
    assert item1["student_id"] is not None
    assert item1["status"] == "COMPLETED"

    # 2. Status filter: PENDING (includes PLANNED and IN_PROGRESS)
    resp_pending = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}/interventions?status=PENDING",
        headers={"Authorization": f"Bearer {faculty_token}"},
    )
    assert resp_pending.status_code == 200
    pending_data = resp_pending.json()
    for item in pending_data:
        assert item["status"] in ["PLANNED", "IN_PROGRESS"]

    # 3. Status filter: COMPLETED
    resp_completed = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}/interventions?status=COMPLETED",
        headers={"Authorization": f"Bearer {faculty_token}"},
    )
    assert resp_completed.status_code == 200
    completed_data = resp_completed.json()
    for item in completed_data:
        assert item["status"] == "COMPLETED"

    # 4. Unauthorized faculty receives 403
    resp_unauth = client.get(
        f"/sli/faculty/analytics/context/{class_id}/{subject_id}/{semester_id}/interventions",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert resp_unauth.status_code == 403
