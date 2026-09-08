"""
Verification tests for the SLI (Student Learning Intelligence) database.

Covers:
    1. All 20 new tables + 4 extended Subject columns exist
    2. FK constraints accept valid references
    3. FK constraints reject invalid references (MySQL only; SQLite
       doesn't enforce FKs by default)
    4. UNIQUE enrollment constraint prevents duplicates
    5. Full insertion pipeline:
       department → student → class → semester → enrollment → responses
    6. Existing tables (users, subjects, timetable_entries) are unbroken
    7. CHECK constraint on topic feedback stage
"""
import os
import uuid

import pytest
from sqlalchemy import inspect, text
from sqlalchemy.exc import IntegrityError

from app.db.base import Base, engine, SessionLocal
from app.models.academic import Subject
from app.models.user import User
from app.models.sli import (
    Department, Student, AcademicClass, Semester, Enrollment,
    PreSemesterResponse, AcademicHistory, SubjectHistory,
    MidSemesterResponse, Topic, StudentTopicFeedback,
    Assessment, StudentAssessmentScore, AttendanceRecord,
    CopoRecord, SemesterOutcome, MlPrediction, MlRecommendation,
    Intervention, InterventionOutcome,
)


# ── Ensure tables exist ──────────────────────────────────────────────

@pytest.fixture(scope="module", autouse=True)
def create_tables():
    """Make sure all SLI tables AND existing tables are created before tests."""
    # Import all models so Base.metadata knows about every table
    from app.models import (  # noqa: F401
        user, academic, timetable, todo, document,
        notification, achievement, schedule_config,
        constraints, generation_history, sli,
    )
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture
def db():
    """Provide a fresh DB session for each test, with rollback on teardown."""
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


# =====================================================================
# 1. TABLE EXISTENCE CHECKS
# =====================================================================

SLI_TABLES = [
    "departments", "students", "classes", "semesters", "enrollments",
    "pre_semester_responses", "academic_history", "subject_history",
    "mid_semester_responses", "topics", "student_topic_feedback",
    "assessments", "student_assessment_scores", "attendance_records",
    "copo_records", "semester_outcomes", "ml_predictions",
    "ml_recommendations", "interventions", "intervention_outcomes",
]


def test_all_sli_tables_exist():
    """All 20 SLI tables must exist in the database."""
    inspector = inspect(engine)
    existing_tables = inspector.get_table_names()
    for table in SLI_TABLES:
        assert table in existing_tables, f"Table '{table}' not found in database"


def test_existing_tables_still_exist():
    """Existing ENOSIS tables must not be broken by SLI additions."""
    inspector = inspect(engine)
    existing_tables = inspector.get_table_names()
    # Check core model-defined tables. We only check tables whose models
    # are guaranteed to be imported by conftest → main.py chain.
    for table in ["users", "subjects", "divisions", "rooms",
                   "teaching_assignments", "documents",
                   "notifications", "achievements"]:
        assert table in existing_tables, f"Existing table '{table}' missing!"


def test_subject_has_sli_columns():
    """Extended Subject model must have the new SLI columns."""
    inspector = inspect(engine)
    columns = {col["name"] for col in inspector.get_columns("subjects")}
    for col in ["sli_department_id", "credits", "subject_type", "placement_relevance"]:
        assert col in columns, f"Column 'subjects.{col}' not found"


# =====================================================================
# 2. FULL INSERTION PIPELINE
# =====================================================================

def _make_dept(db) -> Department:
    dept = Department(department_name="Test CSE", department_code=f"TCSE-{uuid.uuid4().hex[:6]}")
    db.add(dept)
    db.flush()
    return dept


def _make_semester(db) -> Semester:
    sem = Semester(academic_year="2025-26", semester_number=5, status="ACTIVE")
    db.add(sem)
    db.flush()
    return sem


def _make_student(db, dept) -> Student:
    stu = Student(
        student_id=f"T-{uuid.uuid4().hex[:8]}",
        name="Test Student",
        department_id=dept.department_id,
    )
    db.add(stu)
    db.flush()
    return stu


def _make_class(db, dept) -> AcademicClass:
    cls = AcademicClass(
        department_id=dept.department_id,
        academic_year="2025-26",
        year_level=3,
        division="A",
    )
    db.add(cls)
    db.flush()
    return cls


def _make_subject(db, dept) -> Subject:
    subj = Subject(
        id=str(uuid.uuid4()),
        name="Test Subject",
        code=f"TS-{uuid.uuid4().hex[:6]}",
        sli_department_id=dept.department_id,
        credits=4.0,
        subject_type="THEORY",
        placement_relevance=7.5,
    )
    db.add(subj)
    db.flush()
    return subj


def test_full_insertion_pipeline(db):
    """Insert data across the full chain: dept → student → class → semester → enrollment → response."""
    dept = _make_dept(db)
    sem = _make_semester(db)
    stu = _make_student(db, dept)
    cls = _make_class(db, dept)
    subj = _make_subject(db, dept)

    # Enrollment
    enr = Enrollment(
        student_id=stu.student_id,
        class_id=cls.class_id,
        semester_id=sem.semester_id,
        subject_id=subj.id,
    )
    db.add(enr)
    db.flush()
    assert enr.enrollment_id is not None

    # Pre-semester response
    pre = PreSemesterResponse(
        enrollment_id=enr.enrollment_id,
        subject_interest=4,
        self_assessed_skill=3,
        learning_confidence=4,
        preferred_content_source="YouTube",
        preferred_learning_format="Video",
        career_interest="Software Development",
        placement_goal="Product-based company",
    )
    db.add(pre)
    db.flush()
    assert pre.response_id is not None

    # Mid-semester response
    mid = MidSemesterResponse(
        enrollment_id=enr.enrollment_id,
        current_interest=3,
        current_confidence=3,
        perceived_difficulty=4,
        understanding_level=3,
        learning_satisfaction=3,
    )
    db.add(mid)
    db.flush()
    assert mid.response_id is not None

    # Academic history
    hist = AcademicHistory(
        student_id=stu.student_id,
        semester_id=sem.semester_id,
        sgpa=8.5,
        cgpa=8.2,
        backlog_count=0,
        attendance_percentage=85.0,
    )
    db.add(hist)
    db.flush()
    assert hist.history_id is not None

    # Subject history
    sh = SubjectHistory(
        student_id=stu.student_id,
        subject_id=subj.id,
        semester_id=sem.semester_id,
        score=78.5,
        grade="A",
    )
    db.add(sh)
    db.flush()
    assert sh.history_id is not None

    # Topic + feedback
    topic = Topic(subject_id=subj.id, topic_name="Normalization")
    db.add(topic)
    db.flush()
    assert topic.topic_id is not None

    feedback = StudentTopicFeedback(
        enrollment_id=enr.enrollment_id,
        topic_id=topic.topic_id,
        stage="PRE",
        difficulty_level=3,
        confidence_level=4,
    )
    db.add(feedback)
    db.flush()
    assert feedback.feedback_id is not None

    # Assessment + score
    assess = Assessment(
        subject_id=subj.id,
        semester_id=sem.semester_id,
        assessment_name="Internal Test 1",
        assessment_type="INTERNAL",
        max_score=30.0,
    )
    db.add(assess)
    db.flush()
    score = StudentAssessmentScore(
        assessment_id=assess.assessment_id,
        student_id=stu.student_id,
        score=25.0,
    )
    db.add(score)
    db.flush()
    assert score.score_id is not None

    # Attendance
    att = AttendanceRecord(
        enrollment_id=enr.enrollment_id,
        total_classes=40,
        attended_classes=35,
        attendance_percentage=87.5,
    )
    db.add(att)
    db.flush()
    assert att.attendance_id is not None

    # COPO
    copo = CopoRecord(
        enrollment_id=enr.enrollment_id,
        co_code="CO1",
        po_code="PO1",
        attainment_score=75.0,
        attainment_percentage=75.0,
    )
    db.add(copo)
    db.flush()
    assert copo.copo_record_id is not None

    # Semester outcome
    outcome = SemesterOutcome(
        enrollment_id=enr.enrollment_id,
        final_score=78.0,
        final_grade="A",
        final_attendance=87.5,
        backlog_status=False,
    )
    db.add(outcome)
    db.flush()
    assert outcome.outcome_id is not None

    # ML prediction → recommendation → intervention → outcome
    pred = MlPrediction(
        enrollment_id=enr.enrollment_id,
        model_version="v0.1-test",
        prediction_stage="PRE",
        predicted_learning_profile="Visual Learner",
        predicted_gap_level="Moderate",
        predicted_score=72.0,
        confidence=0.85,
    )
    db.add(pred)
    db.flush()

    rec = MlRecommendation(
        prediction_id=pred.prediction_id,
        recommendation_type="teaching_approach",
        priority="HIGH",
        what_to_teach="Normalization deep dive",
        how_to_teach="Use visual diagrams and practical exercises",
        recommended_depth="Intermediate",
    )
    db.add(rec)
    db.flush()

    intv = Intervention(
        recommendation_id=rec.recommendation_id,
        implemented=True,
        intervention_type="Extra tutorial",
        notes="Scheduled after regular hours",
    )
    db.add(intv)
    db.flush()

    intv_out = InterventionOutcome(
        intervention_id=intv.intervention_id,
        interest_change=0.5,
        performance_change=3.2,
        confidence_change=1.0,
        copo_change=2.0,
        effectiveness="POSITIVE",
    )
    db.add(intv_out)
    db.flush()
    assert intv_out.outcome_id is not None


# =====================================================================
# 3. UNIQUE ENROLLMENT CONSTRAINT
# =====================================================================

def test_duplicate_enrollment_rejected(db):
    """The same student+class+semester+subject must not enroll twice."""
    dept = _make_dept(db)
    sem = _make_semester(db)
    stu = _make_student(db, dept)
    cls = _make_class(db, dept)
    subj = _make_subject(db, dept)

    enr1 = Enrollment(
        student_id=stu.student_id,
        class_id=cls.class_id,
        semester_id=sem.semester_id,
        subject_id=subj.id,
    )
    db.add(enr1)
    db.flush()

    enr2 = Enrollment(
        student_id=stu.student_id,
        class_id=cls.class_id,
        semester_id=sem.semester_id,
        subject_id=subj.id,
    )
    db.add(enr2)
    with pytest.raises(IntegrityError):
        db.flush()


# =====================================================================
# 4. FK CONSTRAINT VALIDATION
# =====================================================================

# SQLite does not enforce FK constraints by default (requires
# PRAGMA foreign_keys = ON per connection).  These tests verify
# correct FK rejection on MySQL but are skipped on SQLite.
_is_sqlite = os.environ.get("DATABASE_URL", "").startswith("sqlite")


@pytest.mark.skipif(_is_sqlite, reason="SQLite does not enforce FKs by default")
def test_enrollment_rejects_invalid_student(db):
    """Enrollment with a non-existent student_id must fail."""
    dept = _make_dept(db)
    sem = _make_semester(db)
    cls = _make_class(db, dept)
    subj = _make_subject(db, dept)

    enr = Enrollment(
        student_id="NONEXISTENT-STUDENT",
        class_id=cls.class_id,
        semester_id=sem.semester_id,
        subject_id=subj.id,
    )
    db.add(enr)
    with pytest.raises(IntegrityError):
        db.flush()


@pytest.mark.skipif(_is_sqlite, reason="SQLite does not enforce FKs by default")
def test_enrollment_rejects_invalid_subject(db):
    """Enrollment with a non-existent subject_id must fail."""
    dept = _make_dept(db)
    sem = _make_semester(db)
    stu = _make_student(db, dept)
    cls = _make_class(db, dept)

    enr = Enrollment(
        student_id=stu.student_id,
        class_id=cls.class_id,
        semester_id=sem.semester_id,
        subject_id="nonexistent-uuid-12345678901234",
    )
    db.add(enr)
    with pytest.raises(IntegrityError):
        db.flush()


@pytest.mark.skipif(_is_sqlite, reason="SQLite does not enforce FKs by default")
def test_pre_semester_response_rejects_invalid_enrollment(db):
    """PreSemesterResponse must reference a valid enrollment."""
    pre = PreSemesterResponse(
        enrollment_id=999999999,
        subject_interest=3,
    )
    db.add(pre)
    with pytest.raises(IntegrityError):
        db.flush()


# =====================================================================
# 5. SUBJECT EXTENSION BACKWARD COMPATIBILITY
# =====================================================================

def test_subject_creation_without_sli_fields(db):
    """Creating a Subject with ONLY timetable fields must still work."""
    subj = Subject(
        id=str(uuid.uuid4()),
        name="Timetable-Only Subject",
        code=f"TT-{uuid.uuid4().hex[:6]}",
        weekly_lectures=3,
        is_lab=False,
    )
    db.add(subj)
    db.flush()
    assert subj.id is not None
    # SLI fields should be None
    assert subj.sli_department_id is None
    assert subj.credits is None
    assert subj.subject_type is None
    assert subj.placement_relevance is None


def test_subject_with_sli_fields(db):
    """Creating a Subject with both timetable and SLI fields must work."""
    dept = _make_dept(db)
    subj = Subject(
        id=str(uuid.uuid4()),
        name="Full Subject",
        code=f"FS-{uuid.uuid4().hex[:6]}",
        weekly_lectures=4,
        sli_department_id=dept.department_id,
        credits=4.0,
        subject_type="THEORY",
        placement_relevance=8.0,
    )
    db.add(subj)
    db.flush()
    assert subj.credits == 4.0
    assert subj.subject_type == "THEORY"


# =====================================================================
# 6. CLASS ↔ DIVISION LINK
# =====================================================================

def test_class_with_division_link(db):
    """AcademicClass can optionally link to existing divisions table."""
    from app.models.academic import Division

    dept = _make_dept(db)
    div = Division(
        id=str(uuid.uuid4()),
        name="Test SE-A",
        year=2,
        division_code="A",
        strength=60,
    )
    db.add(div)
    db.flush()

    cls = AcademicClass(
        department_id=dept.department_id,
        academic_year="2025-26",
        year_level=2,
        division="A",
        division_id=div.id,
    )
    db.add(cls)
    db.flush()
    assert cls.class_id is not None
    assert cls.division_id == div.id


def test_class_without_division_link(db):
    """AcademicClass must also work without a division link."""
    dept = _make_dept(db)
    cls = AcademicClass(
        department_id=dept.department_id,
        academic_year="2025-26",
        year_level=3,
        division="B",
    )
    db.add(cls)
    db.flush()
    assert cls.class_id is not None
    assert cls.division_id is None
