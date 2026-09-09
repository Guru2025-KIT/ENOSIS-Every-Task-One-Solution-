"""
Student Learning Intelligence (SLI) & Faculty Insight — database models.

These tables form the data foundation for the SLI module, which will
eventually help faculty understand per-student, per-subject, per-semester
learning patterns, gaps, confidence trends, and intervention effectiveness.

PRIMARY ANALYTICAL UNIT:
    ONE Student × ONE Subject × ONE Semester
    Represented by the ``enrollments`` table.

DATA LIFECYCLE:
    PRE  → academic_history, pre_semester_responses
    MID  → mid_semester_responses, assessments, attendance_records
    END  → semester_outcomes, copo_records (ground truth)

IMPORTANT — data leakage prevention:
    - PRE predictions must NEVER use future data (final scores, COPO, etc.)
    - MID predictions use only information available by mid-semester
    - END data is ground truth for evaluation and retraining

FK TYPE RULES:
    - References to existing ``subjects`` (UUID String(36)) → String(36)
    - References to existing ``divisions`` (UUID String(36)) → String(36)
    - References to new SLI tables use their declared PK types
    - Student identity info (name, email, student_id) must NOT be ML features

NOTE ON PK TYPE:
    All auto-increment PKs use ``Integer`` (not ``BigInteger``) because
    SQLite — used for local dev and tests — doesn't support BigInteger
    autoincrement.  MySQL maps ``Integer`` auto-increment to a 4-byte
    signed int, which holds up to ~2 billion rows — more than sufficient.
    If a table is ever expected to exceed that, a migration to BIGINT
    on MySQL is trivial and won't affect the ORM layer.
"""
from sqlalchemy import (
    Column, String, Integer, SmallInteger, Boolean,
    Numeric, Date, DateTime, Text, ForeignKey, UniqueConstraint,
    CheckConstraint, Index, JSON,
)
from sqlalchemy.sql import func

from app.db.base import Base


# ═══════════════════════════════════════════════════════════════════════
# A. DEPARTMENTS
# ═══════════════════════════════════════════════════════════════════════

class Department(Base):
    """Academic departments (e.g. CSE, ECE, MECH)."""
    __tablename__ = "departments"

    department_id = Column(Integer, primary_key=True, autoincrement=True)
    department_name = Column(String(100), nullable=False)
    department_code = Column(String(20), unique=True, nullable=True)


# ═══════════════════════════════════════════════════════════════════════
# B. STUDENTS
# ═══════════════════════════════════════════════════════════════════════

class Student(Base):
    """
    Student master records — separate from the ``users`` table (which
    is faculty/admin only).  Students don't log into the faculty backend;
    their data is imported or collected via forms.

    IMPORTANT: student identity fields (name, email, student_id) must
    NEVER be used as ML features.
    """
    __tablename__ = "students"

    student_id = Column(String(30), primary_key=True)            # roll number
    name = Column(String(100), nullable=False)
    email = Column(String(150), nullable=True)
    department_id = Column(
        Integer,
        ForeignKey("departments.department_id"),
        nullable=True,
        index=True,
    )
    program = Column(String(100), nullable=True)
    admission_year = Column(Integer, nullable=True)
    current_year = Column(Integer, nullable=True)
    current_semester = Column(Integer, nullable=True)
    division = Column(String(20), nullable=True)
    created_at = Column(DateTime, server_default=func.now())


# ═══════════════════════════════════════════════════════════════════════
# C. CLASSES (SLI academic class/division)
# ═══════════════════════════════════════════════════════════════════════

class AcademicClass(Base):
    """
    Academic class/division for SLI analytics.

    ``division_id`` is a NULLABLE FK to the existing timetable
    ``divisions`` table, enabling cross-referencing without tight coupling.
    """
    __tablename__ = "classes"

    class_id = Column(Integer, primary_key=True, autoincrement=True)
    department_id = Column(
        Integer,
        ForeignKey("departments.department_id"),
        nullable=False,
        index=True,
    )
    academic_year = Column(String(20), nullable=True)
    year_level = Column(Integer, nullable=True)
    division = Column(String(20), nullable=True)

    # Optional link to existing timetable divisions
    division_id = Column(
        String(36),
        ForeignKey("divisions.id"),
        nullable=True,
        index=True,
    )


# ═══════════════════════════════════════════════════════════════════════
# D. SEMESTERS
# ═══════════════════════════════════════════════════════════════════════

class Semester(Base):
    """Academic semesters with status tracking."""
    __tablename__ = "semesters"

    semester_id = Column(Integer, primary_key=True, autoincrement=True)
    academic_year = Column(String(20), nullable=True)
    semester_number = Column(Integer, nullable=True)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    status = Column(String(20), nullable=True)  # UPCOMING, ACTIVE, COMPLETED


# ═══════════════════════════════════════════════════════════════════════
# E. ENROLLMENTS  (core analytical unit)
# ═══════════════════════════════════════════════════════════════════════

class Enrollment(Base):
    """
    The PRIMARY ANALYTICAL UNIT:  Student × Class × Semester × Subject.

    Almost every SLI table hangs off enrollment_id — this is the row
    that ties together "who, what, when, where" for a single student's
    experience in one subject during one semester.
    """
    __tablename__ = "enrollments"
    __table_args__ = (
        UniqueConstraint(
            "student_id", "class_id", "semester_id", "subject_id",
            name="uq_enrollment_student_class_semester_subject",
        ),
    )

    enrollment_id = Column(Integer, primary_key=True, autoincrement=True)
    student_id = Column(
        String(30),
        ForeignKey("students.student_id"),
        nullable=False,
        index=True,
    )
    class_id = Column(
        Integer,
        ForeignKey("classes.class_id"),
        nullable=False,
        index=True,
    )
    semester_id = Column(
        Integer,
        ForeignKey("semesters.semester_id"),
        nullable=False,
        index=True,
    )
    # Uses existing subjects table UUID PK
    subject_id = Column(
        String(36),
        ForeignKey("subjects.id"),
        nullable=False,
        index=True,
    )


# ═══════════════════════════════════════════════════════════════════════
# F. PRE-SEMESTER RESPONSES
# ═══════════════════════════════════════════════════════════════════════

class PreSemesterResponse(Base):
    """
    Pre-semester survey data — collected BEFORE teaching begins.

    Scales (1-5):
        subject_interest:    1=Very Low … 5=Very High
        self_assessed_skill: 1=Beginner … 5=Expert
        learning_confidence: 1=Very Low … 5=Very High
        expected_difficulty: 1=Very Easy … 5=Very Difficult
    """
    __tablename__ = "pre_semester_responses"
    __table_args__ = (
        UniqueConstraint("enrollment_id", name="uq_pre_response_enrollment"),
    )

    response_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    assessment_id = Column(
        Integer,
        ForeignKey("assessments.assessment_id"),
        nullable=True,
        index=True,
    )

    # Subject-level ratings (1-5)
    subject_interest = Column(SmallInteger, nullable=True)       # 1-5
    self_assessed_skill = Column(SmallInteger, nullable=True)    # 1-5
    learning_confidence = Column(SmallInteger, nullable=True)    # 1-5
    expected_difficulty = Column(SmallInteger, nullable=True)    # 1-5

    # Learning Preferences
    preferred_content_source = Column(String(50), nullable=True) # backward compat
    preferred_learning_format = Column(String(50), nullable=True)
    preferred_content_types = Column(JSON, nullable=True)        # e.g. ["VIDEO", "PRACTICAL", "CONCEPTUAL"]
    learning_source = Column(String(100), nullable=True)         # e.g. "YouTube, Documentation"
    free_vs_paid_preference = Column(String(30), nullable=True)  # e.g. "FREE", "PAID", "BOTH"

    # Career / Placement
    career_interest = Column(String(100), nullable=True)
    placement_goal = Column(String(100), nullable=True)
    skills_to_improve = Column(String(255), nullable=True)

    # Timestamps (submitted_at = first creation, updated_at = last edit)
    submitted_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)


# ═══════════════════════════════════════════════════════════════════════
# G. ACADEMIC HISTORY
# ═══════════════════════════════════════════════════════════════════════

class AcademicHistory(Base):
    """Historical academic performance available before/during a semester."""
    __tablename__ = "academic_history"

    history_id = Column(Integer, primary_key=True, autoincrement=True)
    student_id = Column(
        String(30),
        ForeignKey("students.student_id"),
        nullable=False,
        index=True,
    )
    semester_id = Column(
        Integer,
        ForeignKey("semesters.semester_id"),
        nullable=True,
        index=True,
    )
    sgpa = Column(Numeric(4, 2), nullable=True)
    cgpa = Column(Numeric(4, 2), nullable=True)
    backlog_count = Column(Integer, nullable=True, default=0)
    attendance_percentage = Column(Numeric(5, 2), nullable=True)


# ═══════════════════════════════════════════════════════════════════════
# H. SUBJECT HISTORY
# ═══════════════════════════════════════════════════════════════════════

class SubjectHistory(Base):
    """Per-subject historical performance for ML trend analysis."""
    __tablename__ = "subject_history"

    history_id = Column(Integer, primary_key=True, autoincrement=True)
    student_id = Column(
        String(30),
        ForeignKey("students.student_id"),
        nullable=True,
        index=True,
    )
    # Uses existing subjects table UUID PK
    subject_id = Column(
        String(36),
        ForeignKey("subjects.id"),
        nullable=True,
        index=True,
    )
    semester_id = Column(
        Integer,
        ForeignKey("semesters.semester_id"),
        nullable=True,
        index=True,
    )
    score = Column(Numeric(6, 2), nullable=True)
    grade = Column(String(10), nullable=True)


# ═══════════════════════════════════════════════════════════════════════
# I. MID-SEMESTER RESPONSES
# ═══════════════════════════════════════════════════════════════════════

class MidSemesterResponse(Base):
    """
    Mid-semester survey data — collected DURING the active semester.
    Anchored uniquely to an enrollment_id (Student × Subject × Semester × Class).
    """
    __tablename__ = "mid_semester_responses"
    __table_args__ = (
        UniqueConstraint("enrollment_id", name="uq_mid_response_enrollment"),
    )

    response_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    assessment_id = Column(
        Integer,
        ForeignKey("assessments.assessment_id"),
        nullable=True,
        index=True,
    )

    # 1. Current Subject Understanding & Perception (1 to 5)
    current_confidence = Column(SmallInteger, nullable=True)          # 1-5 (Evolution of PRE learning_confidence)
    current_interest = Column(SmallInteger, nullable=True)            # 1-5 (Evolution of PRE subject_interest)
    perceived_difficulty = Column(SmallInteger, nullable=True)        # 1-5 (Actual experienced difficulty vs PRE expected_difficulty)
    understanding_level = Column(SmallInteger, nullable=True)         # 1-5 (Current conceptual grasp)
    concept_application_ability = Column(SmallInteger, nullable=True) # 1-5 (Problem solving / practical application)
    learning_satisfaction = Column(SmallInteger, nullable=True)       # 1-5 (Satisfaction with progress)

    # 2. Learning Experience (Controlled values)
    useful_learning_format = Column(String(50), nullable=True)        # Controlled string enum (e.g. 'PRACTICAL_LABS')
    resource_effectiveness = Column(SmallInteger, nullable=True)      # 1-5 (Rating of course materials / notes)
    practical_lab_experience = Column(SmallInteger, nullable=True)    # 1-5 (Hands-on / lab session clarity)
    teaching_pace = Column(String(30), nullable=True)                 # Controlled: 'TOO_SLOW', 'JUST_RIGHT', 'TOO_FAST'

    # 3. Learning Barriers (Controlled multi-select JSON array)
    learning_barriers = Column(JSON, nullable=True)

    # 4. Structured Skills Progress (Structured JSON array)
    # Measures progress against the target skills identified during PRE
    # Structure: [{"skill_name": "SQL", "confidence_level": 4, "progress_status": "IMPROVED"}, ...]
    skills_progress = Column(JSON, nullable=True)

    # 5. Timestamps
    submitted_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)


class EndSemesterResponse(Base):
    """
    End-semester evaluation data — collected at the culmination of the semester.
    Anchored uniquely to an enrollment_id (Student × Subject × Semester × Class).
    """
    __tablename__ = "end_semester_responses"
    __table_args__ = (
        UniqueConstraint("enrollment_id", name="uq_end_response_enrollment"),
    )

    response_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    assessment_id = Column(
        Integer,
        ForeignKey("assessments.assessment_id"),
        nullable=True,
        index=True,
    )

    # 1. Final Subject Understanding & Perception (1 to 5)
    final_confidence = Column(SmallInteger, nullable=True)             # 1-5 (Evolution of PRE learning_confidence & MID current_confidence)
    final_interest = Column(SmallInteger, nullable=True)               # 1-5 (Evolution of PRE subject_interest & MID current_interest)
    perceived_difficulty = Column(SmallInteger, nullable=True)         # 1-5 (Retrospective perceived difficulty after course completion)
    understanding_level = Column(SmallInteger, nullable=True)          # 1-5 (Comprehensive grasp across syllabus)
    concept_application_ability = Column(SmallInteger, nullable=True)  # 1-5 (Problem solving / practical mastery)
    learning_satisfaction = Column(SmallInteger, nullable=True)        # 1-5 (Final satisfaction with course outcomes)

    # 2. Final Competency & Application (1 to 5)
    core_concepts_mastery = Column(SmallInteger, nullable=True)        # 1-5 (Core theory mastery)
    problem_solving_ability = Column(SmallInteger, nullable=True)      # 1-5 (Analytical problem solving)
    practical_lab_competence = Column(SmallInteger, nullable=True)     # 1-5 (Hands-on lab / coding execution)
    independent_learning_ability = Column(SmallInteger, nullable=True) # 1-5 (Self-study & research capability)
    real_world_application = Column(SmallInteger, nullable=True)       # 1-5 (Connecting concepts to industrial cases)

    # 3. Overall Learning Experience (Controlled Vocabularies)
    effective_learning_format = Column(String(50), nullable=True)      # Controlled string enum (AllowedLearningFormat)
    resource_effectiveness = Column(SmallInteger, nullable=True)       # 1-5 (Quality of notes / materials)
    practical_lab_experience = Column(SmallInteger, nullable=True)     # 1-5 (Lab guidance / clarity)
    teaching_pace = Column(String(30), nullable=True)                  # Controlled: 'TOO_SLOW', 'JUST_RIGHT', 'TOO_FAST'
    overall_learning_experience = Column(SmallInteger, nullable=True)  # 1-5 (Overall course delivery rating)

    # 4. Structured Final Skills Progress (Structured JSON array)
    # Measures final outcome against PRE skills_to_improve & MID skills_progress
    # Structure: [{"skill_name": "SQL", "confidence_level": 5, "progress_status": "MASTERED"}, ...]
    skills_progress = Column(JSON, nullable=True)

    # 5. Timestamps
    submitted_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now(), nullable=False)


# ═══════════════════════════════════════════════════════════════════════
# J. TOPICS
# ═══════════════════════════════════════════════════════════════════════

class Topic(Base):
    """Subject topics — used for topic-level feedback granularity."""
    __tablename__ = "topics"

    topic_id = Column(Integer, primary_key=True, autoincrement=True)
    # Uses existing subjects table UUID PK
    subject_id = Column(
        String(36),
        ForeignKey("subjects.id"),
        nullable=False,
        index=True,
    )
    topic_name = Column(String(150), nullable=True)


# ═══════════════════════════════════════════════════════════════════════
# K. STUDENT TOPIC FEEDBACK
# ═══════════════════════════════════════════════════════════════════════

class StudentTopicFeedback(Base):
    """
    Per-topic difficulty and confidence at a given stage.

    ``stage``: 'PRE', 'MID', or 'END' — constrained via CHECK.
    """
    __tablename__ = "student_topic_feedback"
    __table_args__ = (
        CheckConstraint("stage IN ('PRE', 'MID', 'END')", name="ck_topic_feedback_stage"),
        UniqueConstraint("enrollment_id", "topic_id", "stage", name="uq_topic_feedback_enrollment_topic_stage"),
    )

    feedback_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    topic_id = Column(
        Integer,
        ForeignKey("topics.topic_id"),
        nullable=False,
        index=True,
    )
    stage = Column(String(10), nullable=True)            # PRE, MID
    difficulty_level = Column(SmallInteger, nullable=True)  # 1-5
    confidence_level = Column(SmallInteger, nullable=True)  # 1-5
    progress_status = Column(String(20), nullable=True)     # NOT_STARTED, IN_PROGRESS, COMPLETED


# ═══════════════════════════════════════════════════════════════════════
# L. ASSESSMENTS
# ═══════════════════════════════════════════════════════════════════════

class Assessment(Base):
    """
    Assessment definitions — PRE, MID, END, INTERNAL, ASSIGNMENT, PRACTICAL, QUIZ,
    PROJECT, VIVA, EXAM.
    """
    __tablename__ = "assessments"

    assessment_id = Column(Integer, primary_key=True, autoincrement=True)
    subject_id = Column(
        String(36),
        ForeignKey("subjects.id"),
        nullable=True,
        index=True,
    )
    semester_id = Column(
        Integer,
        ForeignKey("semesters.semester_id"),
        nullable=True,
        index=True,
    )
    class_id = Column(
        Integer,
        ForeignKey("classes.class_id"),
        nullable=True,
        index=True,
    )
    faculty_id = Column(
        String(36),
        ForeignKey("users.id"),
        nullable=True,
        index=True,
    )
    assessment_name = Column(String(100), nullable=True)
    assessment_type = Column(String(50), nullable=True)  # PRE, MID, END, INTERNAL, etc.
    status = Column(String(20), nullable=False, default="DRAFT")  # DRAFT, PUBLISHED, CLOSED
    access_token = Column(String(64), unique=True, nullable=True, index=True)
    questions = Column(JSON, nullable=True)
    max_score = Column(Numeric(6, 2), nullable=True)
    assessment_date = Column(Date, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


# ═══════════════════════════════════════════════════════════════════════
# M. STUDENT ASSESSMENT SCORES
# ═══════════════════════════════════════════════════════════════════════

class StudentAssessmentScore(Base):
    """Individual student scores on assessments."""
    __tablename__ = "student_assessment_scores"

    score_id = Column(Integer, primary_key=True, autoincrement=True)
    assessment_id = Column(
        Integer,
        ForeignKey("assessments.assessment_id"),
        nullable=False,
        index=True,
    )
    student_id = Column(
        String(30),
        ForeignKey("students.student_id"),
        nullable=False,
        index=True,
    )
    score = Column(Numeric(6, 2), nullable=True)


# ═══════════════════════════════════════════════════════════════════════
# N. ATTENDANCE RECORDS
# ═══════════════════════════════════════════════════════════════════════

class AttendanceRecord(Base):
    """Enrollment-level attendance tracking."""
    __tablename__ = "attendance_records"

    attendance_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    total_classes = Column(Integer, nullable=True)
    attended_classes = Column(Integer, nullable=True)
    attendance_percentage = Column(Numeric(5, 2), nullable=True)
    recorded_date = Column(Date, nullable=True)


# ═══════════════════════════════════════════════════════════════════════
# O. COPO RECORDS
# ═══════════════════════════════════════════════════════════════════════

class CopoRecord(Base):
    """
    CO-PO attainment — primarily available at END of semester.

    IMPORTANT: COPO is ground-truth / outcome data.  Do NOT use as an
    input feature for PRE-semester prediction (data leakage).
    """
    __tablename__ = "copo_records"

    copo_record_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    co_code = Column(String(20), nullable=True)
    po_code = Column(String(20), nullable=True)
    pso_code = Column(String(20), nullable=True)
    attainment_score = Column(Numeric(5, 2), nullable=True)
    attainment_percentage = Column(Numeric(5, 2), nullable=True)
    recorded_at = Column(DateTime, server_default=func.now())


# ═══════════════════════════════════════════════════════════════════════
# P. SEMESTER OUTCOMES
# ═══════════════════════════════════════════════════════════════════════

class SemesterOutcome(Base):
    """Final verified outcome for one enrollment (ground truth)."""
    __tablename__ = "semester_outcomes"

    outcome_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    final_score = Column(Numeric(6, 2), nullable=True)
    final_grade = Column(String(10), nullable=True)
    final_attendance = Column(Numeric(5, 2), nullable=True)
    backlog_status = Column(Boolean, nullable=True)
    outcome_date = Column(Date, nullable=True)


# ═══════════════════════════════════════════════════════════════════════
# Q. ML PREDICTIONS
# ═══════════════════════════════════════════════════════════════════════

class MlPrediction(Base):
    """
    ML model predictions at PRE / MID / END stages.

    ``prediction_stage``: PRE, MID, END.
    END predictions may not be needed in V1.
    """
    __tablename__ = "ml_predictions"

    prediction_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    model_version = Column(String(50), nullable=True)
    prediction_stage = Column(String(20), nullable=True)   # PRE, MID, END
    predicted_learning_profile = Column(String(100), nullable=True)
    predicted_gap_level = Column(String(30), nullable=True)
    predicted_score = Column(Numeric(6, 2), nullable=True)
    confidence = Column(Numeric(6, 5), nullable=True)
    prediction_date = Column(DateTime, server_default=func.now())


# ═══════════════════════════════════════════════════════════════════════
# R. ML RECOMMENDATIONS
# ═══════════════════════════════════════════════════════════════════════

class MlRecommendation(Base):
    """Explainable faculty recommendations from ML + rules."""
    __tablename__ = "ml_recommendations"

    recommendation_id = Column(Integer, primary_key=True, autoincrement=True)
    prediction_id = Column(
        Integer,
        ForeignKey("ml_predictions.prediction_id"),
        nullable=False,
        index=True,
    )
    recommendation_type = Column(String(50), nullable=True)
    priority = Column(String(20), nullable=True)
    what_to_teach = Column(Text, nullable=True)
    how_to_teach = Column(Text, nullable=True)
    recommended_depth = Column(String(50), nullable=True)
    generated_at = Column(DateTime, server_default=func.now())


# ═══════════════════════════════════════════════════════════════════════
# S. INTERVENTIONS
# ═══════════════════════════════════════════════════════════════════════

class Intervention(Base):
    """
    Faculty interventions taken in response to recommendations.

    Examples: extra tutorial, practical session, revision session,
    guided problem solving, additional assignment, advanced activity.
    """
    __tablename__ = "interventions"

    intervention_id = Column(Integer, primary_key=True, autoincrement=True)
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=True,
        index=True,
    )
    recommendation_id = Column(
        Integer,
        ForeignKey("ml_recommendations.recommendation_id"),
        nullable=True,
        index=True,
    )
    faculty_id = Column(
        String(36),
        ForeignKey("users.id"),
        nullable=True,
        index=True,
    )
    intervention_type = Column(String(100), nullable=False)
    status = Column(String(30), nullable=False, default="COMPLETED")  # COMPLETED, PLANNED, IN_PROGRESS
    implemented = Column(Boolean, nullable=True, default=True)
    implementation_date = Column(Date, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


# ═══════════════════════════════════════════════════════════════════════
# T. INTERVENTION OUTCOMES
# ═══════════════════════════════════════════════════════════════════════

class InterventionOutcome(Base):
    """
    Measured effectiveness of an intervention — feedback signal for
    future model improvement.

    Recommendation → Intervention → Outcome → Effectiveness

    V1 uses this as a simple feedback record; reinforcement learning
    will NOT be implemented yet.
    """
    __tablename__ = "intervention_outcomes"

    outcome_id = Column(Integer, primary_key=True, autoincrement=True)
    intervention_id = Column(
        Integer,
        ForeignKey("interventions.intervention_id"),
        nullable=False,
        index=True,
    )
    interest_change = Column(Numeric(5, 2), nullable=True)
    performance_change = Column(Numeric(5, 2), nullable=True)
    confidence_change = Column(Numeric(5, 2), nullable=True)
    copo_change = Column(Numeric(5, 2), nullable=True)
    effectiveness = Column(String(30), nullable=True)
    evaluated_at = Column(DateTime, server_default=func.now())


# ═══════════════════════════════════════════════════════════════════════
# U. QUESTION BANK (Faculty-managed subject questions repository)
# ═══════════════════════════════════════════════════════════════════════

class QuestionBank(Base):
    """
    Subject-aligned question repository.
    Enables faculty to create, customize, and maintain question pools for
    PRE, MID, and END assessments across specific course topics and competencies.
    """
    __tablename__ = "question_bank"

    question_id = Column(Integer, primary_key=True, autoincrement=True)
    subject_id = Column(
        String(36),
        ForeignKey("subjects.id"),
        nullable=False,
        index=True,
    )
    topic_id = Column(
        Integer,
        ForeignKey("topics.topic_id"),
        nullable=True,
        index=True,
    )
    assessment_type = Column(String(20), nullable=False, default="ALL")  # PRE, MID, END, ALL
    question_title = Column(String(255), nullable=True)
    question_text = Column(Text, nullable=False)
    question_type = Column(String(50), nullable=False, default="LIKERT_1_5")  # LIKERT_1_5, TOPIC_RATING_MATRIX, PEDAGOGY, BARRIERS_AND_SKILLS, COMPETENCIES_MATRIX, RETROSPECTIVE, TEXT, MULTI_SELECT
    section = Column(String(100), nullable=True)
    dimension = Column(String(100), nullable=True)
    competency = Column(String(100), nullable=True)
    skill_id = Column(String(100), nullable=True)
    difficulty = Column(SmallInteger, nullable=True, default=3)
    marks = Column(Integer, nullable=True, default=1)
    options = Column(JSON, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_by = Column(
        String(36),
        ForeignKey("users.id"),
        nullable=True,
    )
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

