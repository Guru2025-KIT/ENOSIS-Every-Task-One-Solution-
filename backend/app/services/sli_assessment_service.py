from datetime import datetime, timezone
import re
import secrets
from typing import Any
import uuid

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.academic import Division, Subject
from app.models.sli import (
    AcademicClass, Assessment, EndSemesterResponse, Enrollment,
    MidSemesterResponse, PreSemesterResponse, QuestionBank, Semester,
    Student, StudentTopicFeedback, Topic,
)
from app.schemas.sli import (
    AllowedLearningFormat, AssessmentCreateRequest, AssessmentOut,
    AssessmentStatusUpdateRequest, LearningBarrier, QuestionBankItemCreate,
    QuestionBankUpdate, SkillProgressItem, SkillProgressStatus,
    StudentAssessmentPortalOut, StudentAssessmentPortalStudentItem,
    StudentPortalSubmissionRequest, TeachingPace, TopicProgressStatus,
)
from app.services.sli_pre_service import authorize_faculty_teaching_assignment


# ---------------------------------------------------------------------------
# Helper: Division Normalization
# ---------------------------------------------------------------------------

def normalize_division(div_str: str | None) -> str:
    """
    Normalizes division representations so 'Div A', 'TY CSE Div A', 'Division-A', 'A' all resolve to 'A'.
    """
    if not div_str:
        return ""
    cleaned = div_str.strip().upper()
    # Remove common words like DIVISION, DIV, YEAR, SEMESTER, TY, SY, FY, CSE, IT, etc.
    cleaned = re.sub(r'(?i)\b(division|div|year|semester|sem|ty|sy|fy|be|btech|cse|it|entc|mech|civil)\b', '', cleaned)
    cleaned = re.sub(r'[^A-Z0-9]', '', cleaned)
    return cleaned if cleaned else div_str.strip().upper()


# ---------------------------------------------------------------------------
MIN_ASSESSMENT_QUESTIONS = 15
MAX_ASSESSMENT_QUESTIONS = 20


def derive_skill_id(topic_name: str | None, default_skill: str = "CORE_THEORY") -> str:
    """
    Deterministically transforms topic/section names into standardized, ML-ready feature skill identifiers.
    e.g. 'Relational Data Model & ER Diagrams' -> 'RELATIONAL_DATA_MODEL_ER_DIAG'
    """
    if not topic_name:
        return default_skill
    cleaned = re.sub(r'[^A-Z0-9_]', '', topic_name.strip().upper().replace(' ', '_').replace('-', '_').replace('&', 'AND'))
    return cleaned[:32] if cleaned else default_skill


def ensure_subject_topics(db: Session, subject: Subject) -> list[Topic]:
    """
    Ensures that at least 5 structured course topics exist in the database for the subject.
    If fewer than 5 exist, generates subject-aligned module topics and persists them.
    """
    topics = db.query(Topic).filter(Topic.subject_id == subject.id).order_by(Topic.topic_id.asc()).all()
    if len(topics) >= 5:
        return topics

    # Standard subject-aligned module templates if subject has < 5 topics
    sub_name_upper = subject.name.upper()
    if "AUTOMATA" in sub_name_upper or "COMPUT" in sub_name_upper:
        default_names = [
            "Finite Automata & Regular Languages",
            "Context-Free Grammars & Pushdown Automata",
            "Turing Machines & Decidability",
            "Chomsky Hierarchy & Parsing",
            "Computability & Computational Complexity",
        ]
    elif "MANUFACTURING" in sub_name_upper or "SMART" in sub_name_upper or "ROBOT" in sub_name_upper:
        default_names = [
            "Industrial IoT & Sensor Data Acquisition",
            "Predictive Maintenance & Digital Twins",
            "Robotics, Automation & Motion Control",
            "Automated Visual Inspection & Quality AI",
            "Smart Factory Operations & Supply Optimization",
        ]
    elif "DATABASE" in sub_name_upper or "DBMS" in sub_name_upper or "SQL" in sub_name_upper:
        default_names = [
            "Relational Data Modeling & ER Diagrams",
            "Relational Algebra & SQL Query Optimization",
            "Functional Dependencies & Normalization",
            "Transaction Management, Concurrency & ACID",
            "Database Indexing, B+ Trees & Storage Engine",
        ]
    elif "AI" in sub_name_upper or "INTELLIGENCE" in sub_name_upper or "MACHINE" in sub_name_upper:
        default_names = [
            "Feature Engineering & Data Preprocessing",
            "Supervised Learning Algorithms & Regression",
            "Classification & Model Evaluation Metrics",
            "Neural Networks & Deep Learning Foundations",
            "Model Deployment & Production ML Pipelines",
        ]
    elif "MATH" in sub_name_upper or "ALGEBRA" in sub_name_upper or "CALCULUS" in sub_name_upper:
        default_names = [
            "Linear Algebra & Matrix Transformations",
            "Differential Equations & Dynamic Systems",
            "Probability Distributions & Random Variables",
            "Numerical Analysis & Optimization Methods",
            "Statistical Inference & Hypothesis Testing",
        ]
    elif "CLOUD" in sub_name_upper or "NETWORK" in sub_name_upper:
        default_names = [
            "Cloud Infrastructure & Virtualization",
            "Microservices Architecture & API Design",
            "Containerization & Kubernetes Orchestration",
            "Cloud Security, IAM & Compliance",
            "Distributed Storage & Scalability Systems",
        ]
    else:
        default_names = [
            f"{subject.name} Core Principles & Foundations",
            f"{subject.name} Architecture & Design Patterns",
            f"{subject.name} Problem Analysis & Algorithmic Methods",
            f"{subject.name} Practical Implementation & Tooling",
            f"{subject.name} Optimization, Scaling & Real-World Systems",
        ]

    existing_names = {t.topic_name.strip().lower() for t in topics}
    for name in default_names:
        if name.strip().lower() not in existing_names:
            new_top = Topic(
                subject_id=subject.id,
                topic_name=name,
            )
            db.add(new_top)
            topics.append(new_top)

    db.commit()
    return db.query(Topic).filter(Topic.subject_id == subject.id).order_by(Topic.topic_id.asc()).all()


# ---------------------------------------------------------------------------
# Helper: Subject-Aligned Question Blueprint Generator (15 - 20 Questions)
# ---------------------------------------------------------------------------

def generate_subject_aligned_questions(
    db: Session,
    subject: Subject,
    assessment_type: str,
    question_count: int | None = None,
) -> list[dict[str, Any]]:
    """
    Dynamically generates subject-aligned questions based on the Subject name,
    code, and its database-configured Topics and active QuestionBank items.
    Strictly guarantees a standardized 15 to 20 question blueprint designed for ML.
    Attaches standardized metadata (question_id, subject_id, topic_id, skill_id,
    difficulty, question_type, marks, assessment_stage) to every question.
    """
    type_upper = assessment_type.upper()
    topics = ensure_subject_topics(db, subject)
    major_skills = topics[:5]

    desired_count = question_count if question_count is not None else MAX_ASSESSMENT_QUESTIONS
    desired_count = min(max(desired_count, MIN_ASSESSMENT_QUESTIONS), MAX_ASSESSMENT_QUESTIONS)

    questions: list[dict[str, Any]] = []

    # ═══════════════════════════════════════════════════════════════════════
    # 1. QUESTIONS 1–5: SKILL CONFIDENCE (1 per major subject skill)
    # ═══════════════════════════════════════════════════════════════════════
    for idx, skill in enumerate(major_skills, start=1):
        skill_id = derive_skill_id(skill.topic_name)
        questions.append({
            "question_id": f"{type_upper}_{subject.code or 'SUB'}_{idx:02d}",
            "subject_id": subject.id,
            "topic_id": skill.topic_id,
            "skill_id": skill_id,
            "difficulty": 2 if type_upper == "PRE" else (3 if type_upper == "MID" else 4),
            "marks": 1,
            "assessment_stage": type_upper,
            "section": f"Skill Confidence: {skill.topic_name}",
            "title": f"Conceptual Confidence in {skill.topic_name}",
            "description": f"How confident are you in understanding the fundamental concepts and theoretical principles of {skill.topic_name}?",
            "type": "LIKERT_1_5",
            "dimension": "self_reported_confidence",
        })

    # ═══════════════════════════════════════════════════════════════════════
    # 2. QUESTIONS 6–10: SKILL APPLICATION (1 per major subject skill)
    # ═══════════════════════════════════════════════════════════════════════
    for idx, skill in enumerate(major_skills, start=6):
        skill_id = derive_skill_id(skill.topic_name)
        questions.append({
            "question_id": f"{type_upper}_{subject.code or 'SUB'}_{idx:02d}",
            "subject_id": subject.id,
            "topic_id": skill.topic_id,
            "skill_id": skill_id,
            "difficulty": 3 if type_upper == "PRE" else (4 if type_upper == "MID" else 5),
            "marks": 1,
            "assessment_stage": type_upper,
            "section": f"Practical Application: {skill.topic_name}",
            "title": f"Application & Problem Solving: {skill.topic_name}",
            "description": f"How effectively can you apply {skill.topic_name} principles to design solutions and solve practical problems?",
            "type": "LIKERT_1_5",
            "dimension": "application_ability",
        })

    # ═══════════════════════════════════════════════════════════════════════
    # 3. QUESTIONS 11–13: SKILL DIFFICULTY (Perceived difficulty for skills 1..3)
    # ═══════════════════════════════════════════════════════════════════════
    for idx, skill in enumerate(major_skills[:3], start=11):
        skill_id = derive_skill_id(skill.topic_name)
        questions.append({
            "question_id": f"{type_upper}_{subject.code or 'SUB'}_{idx:02d}",
            "subject_id": subject.id,
            "topic_id": skill.topic_id,
            "skill_id": skill_id,
            "difficulty": 3,
            "marks": 1,
            "assessment_stage": type_upper,
            "section": f"Perceived Difficulty: {skill.topic_name}",
            "title": f"Concept Complexity: {skill.topic_name}",
            "description": f"Rate the perceived difficulty and conceptual complexity you experience with {skill.topic_name}.",
            "type": "LIKERT_1_5",
            "dimension": "perceived_difficulty",
        })

    # ═══════════════════════════════════════════════════════════════════════
    # 4. QUESTION 14: LEARNING BARRIER
    # ═══════════════════════════════════════════════════════════════════════
    questions.append({
        "question_id": f"{type_upper}_{subject.code or 'SUB'}_14",
        "subject_id": subject.id,
        "topic_id": major_skills[0].topic_id,
        "skill_id": "LEARNING_BARRIERS",
        "difficulty": 2,
        "marks": 1,
        "assessment_stage": type_upper,
        "section": "Learning Barriers & Challenges",
        "title": f"Primary Learning Challenge in {subject.name}",
        "description": f"What is the biggest difficulty you are currently facing while learning {subject.name}?",
        "type": "BARRIERS_AND_SKILLS",
        "dimension": "learning_barriers",
    })

    # ═══════════════════════════════════════════════════════════════════════
    # 5. QUESTION 15: BARRIER FREQUENCY
    # ═══════════════════════════════════════════════════════════════════════
    questions.append({
        "question_id": f"{type_upper}_{subject.code or 'SUB'}_15",
        "subject_id": subject.id,
        "topic_id": major_skills[0].topic_id,
        "skill_id": "BARRIER_FREQUENCY",
        "difficulty": 2,
        "marks": 1,
        "assessment_stage": type_upper,
        "section": "Challenge Frequency & Impact",
        "title": "Frequency of Learning Disruptions",
        "description": f"How frequently does this difficulty affect your learning progress and conceptual retention in {subject.name}?",
        "type": "LIKERT_1_5",
        "dimension": "barrier_frequency",
    })

    # ═══════════════════════════════════════════════════════════════════════
    # 6. QUESTION 16: OVERALL SUBJECT CONFIDENCE
    # ═══════════════════════════════════════════════════════════════════════
    questions.append({
        "question_id": f"{type_upper}_{subject.code or 'SUB'}_16",
        "subject_id": subject.id,
        "topic_id": major_skills[0].topic_id,
        "skill_id": "OVERALL_CONFIDENCE",
        "difficulty": 3,
        "marks": 1,
        "assessment_stage": type_upper,
        "section": "Comprehensive Subject Confidence",
        "title": f"Overall Clarity in {subject.name}",
        "description": f"Rate your overall conceptual clarity and confidence in achieving learning outcomes for {subject.name}.",
        "type": "LIKERT_1_5",
        "dimension": "overall_confidence",
    })

    # ═══════════════════════════════════════════════════════════════════════
    # 7. QUESTION 17: UNFAMILIAR PROBLEM-SOLVING CONFIDENCE
    # ═══════════════════════════════════════════════════════════════════════
    questions.append({
        "question_id": f"{type_upper}_{subject.code or 'SUB'}_17",
        "subject_id": subject.id,
        "topic_id": major_skills[1].topic_id,
        "skill_id": "PROBLEM_SOLVING",
        "difficulty": 4,
        "marks": 1,
        "assessment_stage": type_upper,
        "section": "Analytical & Problem Solving Competence",
        "title": "Unfamiliar Problem Solving",
        "description": f"How confident are you in independently analyzing and solving novel, unseen technical problems in {subject.name}?",
        "type": "LIKERT_1_5",
        "dimension": "problem_solving",
    })

    # ═══════════════════════════════════════════════════════════════════════
    # 8. QUESTION 18: INDEPENDENT LEARNING CONFIDENCE
    # ═══════════════════════════════════════════════════════════════════════
    questions.append({
        "question_id": f"{type_upper}_{subject.code or 'SUB'}_18",
        "subject_id": subject.id,
        "topic_id": major_skills[2].topic_id,
        "skill_id": "INDEPENDENT_LEARNING",
        "difficulty": 3,
        "marks": 1,
        "assessment_stage": type_upper,
        "section": "Autonomous & Independent Learning",
        "title": "Independent Technical Learning",
        "description": f"How confident are you in learning advanced topics in {subject.name} using documentation, textbooks, and self-study?",
        "type": "LIKERT_1_5",
        "dimension": "independent_learning",
    })

    # ═══════════════════════════════════════════════════════════════════════
    # 9. QUESTION 19: LEARNING PACE
    # ═══════════════════════════════════════════════════════════════════════
    questions.append({
        "question_id": f"{type_upper}_{subject.code or 'SUB'}_19",
        "subject_id": subject.id,
        "topic_id": major_skills[3].topic_id,
        "skill_id": "LEARNING_PACE",
        "difficulty": 2,
        "marks": 1,
        "assessment_stage": type_upper,
        "section": "Instructional Pacing & Delivery",
        "title": "Course Delivery Pace Alignment",
        "description": f"How would you evaluate the instructional pace and delivery speed of {subject.name} relative to your comprehension?",
        "type": "PEDAGOGY",
        "dimension": "learning_pace",
    })

    # ═══════════════════════════════════════════════════════════════════════
    # 10. QUESTION 20: REQUIRED SUPPORT
    # ═══════════════════════════════════════════════════════════════════════
    questions.append({
        "question_id": f"{type_upper}_{subject.code or 'SUB'}_20",
        "subject_id": subject.id,
        "topic_id": major_skills[4].topic_id,
        "skill_id": "REQUIRED_SUPPORT",
        "difficulty": 1,
        "marks": 1,
        "assessment_stage": type_upper,
        "section": "Academic Support & Remediation",
        "title": "Desired Instructional Support",
        "description": f"What type of academic support, lab mentoring, or practice sessions would best accelerate your mastery in {subject.name}?",
        "type": "PREFERENCES",
        "dimension": "required_support",
    })

    # Fetch custom/saved active questions from QuestionBank strictly for this subject
    bank_questions = db.query(QuestionBank).filter(
        QuestionBank.subject_id == subject.id,
        QuestionBank.is_active == True,
        QuestionBank.assessment_type.in_([type_upper, "ALL"]),
    ).all()

    # Blend active QuestionBank questions strictly for this subject
    if bank_questions:
        bank_list: list[dict[str, Any]] = []
        for bq in bank_questions:
            q_id = f"BANK_{bq.question_id}"
            bank_list.append({
                "question_id": q_id,
                "subject_id": subject.id,
                "topic_id": bq.topic_id or major_skills[0].topic_id,
                "skill_id": bq.skill_id or derive_skill_id(bq.dimension or bq.section or bq.competency),
                "difficulty": bq.difficulty or 3,
                "marks": bq.marks or 1,
                "assessment_stage": type_upper,
                "section": bq.section or f"{subject.name} Question Bank",
                "title": bq.question_title or bq.question_text[:60],
                "description": bq.question_text,
                "type": bq.question_type or "LIKERT_1_5",
                "dimension": bq.dimension,
                "competency": bq.competency,
                "options": bq.options,
            })
        # Include bank questions up to 5, adjusting base questions to maintain desired_count
        num_bank = min(len(bank_list), 5)
        base_slice = max(desired_count - num_bank, 10)
        questions = questions[:base_slice] + bank_list[:num_bank]

    # Return exactly desired_count (15 to 20 questions)
    return questions[:desired_count]


# ---------------------------------------------------------------------------
# Faculty Question Bank CRUD Operations
# ---------------------------------------------------------------------------

def get_question_bank_items(
    db: Session,
    subject_id: str,
    assessment_type: str | None = None,
) -> list[QuestionBank]:
    """Retrieves all active QuestionBank items for a subject."""
    query = db.query(QuestionBank).filter(
        QuestionBank.subject_id == subject_id,
        QuestionBank.is_active == True,
    )
    if assessment_type:
        query = query.filter(QuestionBank.assessment_type.in_([assessment_type.upper(), "ALL"]))
    return query.order_by(QuestionBank.created_at.asc()).all()


def add_question_bank_item(
    db: Session,
    faculty_id: str,
    payload: QuestionBankItemCreate,
) -> QuestionBank:
    """Adds a custom question to the subject's question bank."""
    subject = db.query(Subject).filter(Subject.id == payload.subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found.")

    item = QuestionBank(
        subject_id=payload.subject_id,
        topic_id=payload.topic_id,
        assessment_type=payload.assessment_type.upper(),
        question_title=payload.question_title or payload.question_text[:60],
        question_text=payload.question_text,
        question_type=payload.question_type,
        section=payload.section,
        dimension=payload.dimension,
        competency=payload.competency,
        skill_id=payload.skill_id or derive_skill_id(payload.dimension or payload.section or payload.competency),
        difficulty=payload.difficulty or 3,
        marks=payload.marks or 1,
        options=payload.options,
        is_active=True,
        created_by=faculty_id,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def update_question_bank_item(
    db: Session,
    faculty_id: str,
    question_id: int,
    payload: QuestionBankUpdate,
) -> QuestionBank:
    """Updates an existing question in the bank."""
    item = db.query(QuestionBank).filter(QuestionBank.question_id == question_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Question bank item not found.")

    if payload.topic_id is not None:
        item.topic_id = payload.topic_id
    if payload.assessment_type is not None:
        item.assessment_type = payload.assessment_type.upper()
    if payload.question_title is not None:
        item.question_title = payload.question_title
    if payload.question_text is not None:
        item.question_text = payload.question_text
    if payload.question_type is not None:
        item.question_type = payload.question_type
    if payload.section is not None:
        item.section = payload.section
    if payload.dimension is not None:
        item.dimension = payload.dimension
    if payload.competency is not None:
        item.competency = payload.competency
    if payload.skill_id is not None:
        item.skill_id = payload.skill_id
    if payload.difficulty is not None:
        item.difficulty = payload.difficulty
    if payload.marks is not None:
        item.marks = payload.marks
    if payload.options is not None:
        item.options = payload.options
    if payload.is_active is not None:
        item.is_active = payload.is_active

    item.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(item)
    return item


def deactivate_question_bank_item(
    db: Session,
    faculty_id: str,
    question_id: int,
) -> dict[str, Any]:
    """Soft-deactivates a question so historical assessments remain immutable."""
    item = db.query(QuestionBank).filter(QuestionBank.question_id == question_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Question bank item not found.")

    item.is_active = False
    item.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {"status": "success", "message": f"Question {question_id} deactivated."}


# ---------------------------------------------------------------------------
# Faculty Assessment Management Operations
# ---------------------------------------------------------------------------

def create_assessment_for_context(
    db: Session,
    faculty_id: str,
    payload: AssessmentCreateRequest,
    is_admin: bool = False,
) -> dict[str, Any]:
    """
    Creates an Assessment in DRAFT status for a valid teaching context.
    Automatically attaches dynamic, subject-aligned questions with snapshot versioning.
    """
    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == payload.class_id).first()
    subject = db.query(Subject).filter(Subject.id == payload.subject_id).first()
    semester = db.query(Semester).filter(Semester.semester_id == payload.semester_id).first()

    if not academic_class or not subject or not semester:
        raise HTTPException(status_code=404, detail="Teaching context records not found.")

    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division_id, is_admin)

    # Check if assessment of this type already exists for this context
    existing = db.query(Assessment).filter(
        Assessment.class_id == payload.class_id,
        Assessment.subject_id == payload.subject_id,
        Assessment.semester_id == payload.semester_id,
        Assessment.assessment_type == payload.assessment_type.upper(),
    ).first()

    if existing:
        return _format_assessment_out(db, existing, subject, academic_class)

    if payload.questions and (len(payload.questions) < MIN_ASSESSMENT_QUESTIONS or len(payload.questions) > MAX_ASSESSMENT_QUESTIONS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Assessment question count must be between {MIN_ASSESSMENT_QUESTIONS} and {MAX_ASSESSMENT_QUESTIONS} (provided {len(payload.questions)}).",
        )
    if payload.question_count and (payload.question_count < MIN_ASSESSMENT_QUESTIONS or payload.question_count > MAX_ASSESSMENT_QUESTIONS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Assessment question count must be between {MIN_ASSESSMENT_QUESTIONS} and {MAX_ASSESSMENT_QUESTIONS} (requested {payload.question_count}).",
        )

    # Use explicitly passed questions or generate subject-specific questions
    if payload.questions and len(payload.questions) > 0:
        questions = payload.questions
    else:
        questions = generate_subject_aligned_questions(
            db, subject, payload.assessment_type.upper(), payload.question_count
        )

    # Generate secure unpredictable access token
    access_token = secrets.token_urlsafe(16)
    name = payload.assessment_name or f"{subject.name} {payload.assessment_type.upper()} Assessment"

    assessment = Assessment(
        subject_id=subject.id,
        semester_id=semester.semester_id,
        class_id=academic_class.class_id,
        faculty_id=faculty_id,
        assessment_name=name,
        assessment_type=payload.assessment_type.upper(),
        status="DRAFT",
        access_token=access_token,
        questions=questions,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(assessment)
    db.commit()
    db.refresh(assessment)

    return _format_assessment_out(db, assessment, subject, academic_class)


def update_assessment_questions(
    db: Session,
    faculty_id: str,
    assessment_id: int,
    questions: list[dict[str, Any]],
    is_admin: bool = False,
) -> dict[str, Any]:
    """
    Updates the question configuration for a DRAFT assessment.
    Enforces the MIN (15) and MAX (20) question limits and standardizes metadata.
    Published or closed assessments reject question mutations to preserve historical snapshots.
    """
    if len(questions) < MIN_ASSESSMENT_QUESTIONS or len(questions) > MAX_ASSESSMENT_QUESTIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Assessment question count must be between {MIN_ASSESSMENT_QUESTIONS} and {MAX_ASSESSMENT_QUESTIONS} (provided {len(questions)}).",
        )

    assessment = db.query(Assessment).filter(Assessment.assessment_id == assessment_id).first()
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found.")

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == assessment.class_id).first()
    division_id = academic_class.division_id if academic_class else None
    authorize_faculty_teaching_assignment(db, faculty_id, assessment.subject_id, division_id, is_admin)

    if assessment.status != "DRAFT":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot edit questions: assessment is currently {assessment.status}. Only DRAFT assessments can be modified.",
        )

    # Standardize metadata on all questions including custom items
    normalized_questions: list[dict[str, Any]] = []
    for idx, q in enumerate(questions):
        q_dict = dict(q)
        if not q_dict.get("question_id"):
            q_dict["question_id"] = f"CUSTOM_{idx+1}_{secrets.token_hex(4)}"
        if not q_dict.get("subject_id"):
            q_dict["subject_id"] = assessment.subject_id
        if not q_dict.get("assessment_stage"):
            q_dict["assessment_stage"] = assessment.assessment_type
        if not q_dict.get("skill_id"):
            q_dict["skill_id"] = derive_skill_id(q_dict.get("section") or q_dict.get("title"))
        if "difficulty" not in q_dict:
            q_dict["difficulty"] = 3
        if "marks" not in q_dict:
            q_dict["marks"] = 1
        if "type" not in q_dict and "question_type" not in q_dict:
            q_dict["type"] = "LIKERT_1_5"
        normalized_questions.append(q_dict)

    assessment.questions = normalized_questions
    assessment.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(assessment)

    subject = db.query(Subject).filter(Subject.id == assessment.subject_id).first()
    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == assessment.class_id).first()
    return _format_assessment_out(db, assessment, subject, academic_class)


def list_assessments_for_context(
    db: Session,
    faculty_id: str,
    class_id: int,
    subject_id: str,
    semester_id: int,
    is_admin: bool = False,
) -> list[dict[str, Any]]:
    """Lists all assessments for a teaching context."""
    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == class_id).first()
    subject = db.query(Subject).filter(Subject.id == subject_id).first()

    if not academic_class or not subject:
        raise HTTPException(status_code=404, detail="Teaching context not found.")

    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division_id, is_admin)

    assessments = db.query(Assessment).filter(
        Assessment.class_id == class_id,
        Assessment.subject_id == subject_id,
        Assessment.semester_id == semester_id,
    ).order_by(Assessment.created_at.desc()).all()

    return [_format_assessment_out(db, a, subject, academic_class) for a in assessments]


def update_assessment_status(
    db: Session,
    faculty_id: str,
    assessment_id: int,
    new_status: str,
    is_admin: bool = False,
) -> dict[str, Any]:
    """Transitions assessment status between DRAFT, PUBLISHED, and CLOSED."""
    valid_statuses = {"DRAFT", "PUBLISHED", "CLOSED"}
    status_upper = new_status.upper()
    if status_upper not in valid_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status '{new_status}'. Allowed values: {valid_statuses}",
        )

    assessment = db.query(Assessment).filter(Assessment.assessment_id == assessment_id).first()
    if not assessment:
        raise HTTPException(status_code=404, detail="Assessment not found.")

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == assessment.class_id).first()
    subject = db.query(Subject).filter(Subject.id == assessment.subject_id).first()
    division_id = academic_class.division_id if academic_class else None
    authorize_faculty_teaching_assignment(db, faculty_id, assessment.subject_id, division_id, is_admin)

    if status_upper == "PUBLISHED":
        q_count = len(assessment.questions or [])
        if q_count < MIN_ASSESSMENT_QUESTIONS or q_count > MAX_ASSESSMENT_QUESTIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot publish assessment: must contain between {MIN_ASSESSMENT_QUESTIONS} and {MAX_ASSESSMENT_QUESTIONS} questions (currently {q_count}).",
            )

    assessment.status = status_upper
    if not assessment.faculty_id:
        assessment.faculty_id = faculty_id
    if not assessment.access_token:
        assessment.access_token = secrets.token_urlsafe(16)
    assessment.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(assessment)

    return _format_assessment_out(db, assessment, subject, academic_class)


def _format_assessment_out(
    db: Session,
    assessment: Assessment,
    subject: Subject | None,
    academic_class: AcademicClass | None,
) -> dict[str, Any]:
    if not subject:
        subject = db.query(Subject).filter(Subject.id == assessment.subject_id).first()
    if not academic_class:
        academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == assessment.class_id).first()

    class_name = f"Year {academic_class.year_level or 1} - Div {academic_class.division or 'A'}" if academic_class else "Class"

    # Count enrollments and submissions
    total_enrolled = 0
    total_submitted = 0

    if academic_class and subject and assessment.semester_id:
        enrollments = db.query(Enrollment).filter(
            Enrollment.class_id == academic_class.class_id,
            Enrollment.subject_id == subject.id,
            Enrollment.semester_id == assessment.semester_id,
        ).all()
        total_enrolled = len(enrollments)
        enrollment_ids = [e.enrollment_id for e in enrollments]

        if enrollment_ids:
            if assessment.assessment_type == "PRE":
                total_submitted = db.query(PreSemesterResponse).filter(
                    PreSemesterResponse.enrollment_id.in_(enrollment_ids)
                ).count()
            elif assessment.assessment_type == "MID":
                total_submitted = db.query(MidSemesterResponse).filter(
                    MidSemesterResponse.enrollment_id.in_(enrollment_ids)
                ).count()
            elif assessment.assessment_type == "END":
                total_submitted = db.query(EndSemesterResponse).filter(
                    EndSemesterResponse.enrollment_id.in_(enrollment_ids)
                ).count()

    share_url = f"{settings.FRONTEND_APP_BASE_URL}/#/assessment/{assessment.access_token}" if assessment.access_token else None

    return {
        "assessment_id": assessment.assessment_id,
        "subject_id": assessment.subject_id,
        "subject_name": subject.name if subject else "Subject",
        "subject_code": subject.code if subject else None,
        "semester_id": assessment.semester_id,
        "class_id": assessment.class_id,
        "class_name": class_name,
        "assessment_name": assessment.assessment_name or f"{assessment.assessment_type} Assessment",
        "assessment_type": assessment.assessment_type,
        "status": assessment.status,
        "access_token": assessment.access_token,
        "share_url": share_url,
        "questions": assessment.questions or [],
        "total_enrolled": total_enrolled,
        "total_submitted": total_submitted,
        "created_at": assessment.created_at,
        "updated_at": assessment.updated_at,
    }


# ---------------------------------------------------------------------------
# Student Portal Operations (Tokenized / No Student Login Required)
# ---------------------------------------------------------------------------

def get_student_assessment_portal_data(
    db: Session,
    access_token: str,
) -> dict[str, Any]:
    """
    Public tokenized access to a published assessment.
    Returns subject-aligned questions, topics, division metadata, and share URL.
    """
    assessment = db.query(Assessment).filter(Assessment.access_token == access_token).first()
    if not assessment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assessment not found or invalid access token.",
        )

    if assessment.status == "DRAFT":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This assessment is still in DRAFT mode and has not been published yet.",
        )
    if assessment.status == "CLOSED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This assessment has been closed and is no longer accepting submissions.",
        )

    subject = db.query(Subject).filter(Subject.id == assessment.subject_id).first()
    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == assessment.class_id).first()
    semester = db.query(Semester).filter(Semester.semester_id == assessment.semester_id).first()

    if not subject or not academic_class or not semester:
        raise HTTPException(status_code=404, detail="Associated academic context not found.")

    class_name = f"Year {academic_class.year_level or 1} - Div {academic_class.division or 'A'}"

    topics = db.query(Topic).filter(Topic.subject_id == subject.id).order_by(Topic.topic_id.asc()).all()
    topic_items = [{"topic_id": t.topic_id, "topic_name": t.topic_name} for t in topics]

    share_url = f"{settings.FRONTEND_APP_BASE_URL}/#/assessment/{assessment.access_token}"

    return {
        "assessment_id": assessment.assessment_id,
        "access_token": assessment.access_token,
        "assessment_name": assessment.assessment_name or f"{subject.name} {assessment.assessment_type}",
        "assessment_type": assessment.assessment_type,
        "status": assessment.status,
        "subject_id": subject.id,
        "subject_name": subject.name,
        "subject_code": subject.code,
        "class_name": class_name,
        "division_name": academic_class.division or "A",
        "expected_division": academic_class.division or "A",
        "academic_year": semester.academic_year,
        "semester_number": semester.semester_number,
        "share_url": share_url,
        "questions": assessment.questions or [],
        "topics": topic_items,
        "students": [],
    }


def submit_student_assessment_response(
    db: Session,
    access_token: str,
    payload: StudentPortalSubmissionRequest,
) -> dict[str, Any]:
    """
    Receives and atomically persists a student's submission via the assessment access token.
    Enforces division validation, auto-registers/resolves student identity & enrollment,
    and prevents duplicate submissions (HTTP 409).
    """
    assessment = db.query(Assessment).filter(Assessment.access_token == access_token).first()
    if not assessment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assessment not found or invalid access token.",
        )

    if assessment.status != "PUBLISHED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Submissions are not allowed because this assessment is {assessment.status}.",
        )

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == assessment.class_id).first()
    subject = db.query(Subject).filter(Subject.id == assessment.subject_id).first()

    if not academic_class or not subject:
        raise HTTPException(status_code=404, detail="Assessment context not found.")

    # 1. Strict Division Normalization & Validation
    expected_norm_div = normalize_division(academic_class.division)
    entered_norm_div = normalize_division(payload.division_code)

    if expected_norm_div and entered_norm_div and expected_norm_div != entered_norm_div:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Division mismatch: This assessment is designated for Division '{academic_class.division}', but you entered '{payload.division_code}'.",
        )

    # 2. Student Identity Lifecycle: Find or Create Student
    clean_student_id = payload.student_id.strip()
    clean_name = payload.full_name.strip()

    if not clean_student_id or not clean_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Student Name and Roll Number / PRN are mandatory.",
        )

    student = db.query(Student).filter(Student.student_id == clean_student_id).first()
    if not student:
        student = Student(
            student_id=clean_student_id,
            name=clean_name,
            division=academic_class.division,
            current_year=academic_class.year_level or 1,
            department_id=academic_class.department_id,
            created_at=datetime.now(timezone.utc),
        )
        db.add(student)
        db.flush()
    else:
        # Update name if previously blank or updated
        if clean_name and (not student.name or student.name.startswith("Student ")):
            student.name = clean_name

    # 3. Enrollment Lifecycle: Find or Create Enrollment
    enrollment = db.query(Enrollment).filter(
        Enrollment.class_id == assessment.class_id,
        Enrollment.subject_id == assessment.subject_id,
        Enrollment.semester_id == assessment.semester_id,
        Enrollment.student_id == student.student_id,
    ).first()

    if not enrollment:
        enrollment = Enrollment(
            student_id=student.student_id,
            class_id=assessment.class_id,
            semester_id=assessment.semester_id,
            subject_id=assessment.subject_id,
        )
        db.add(enrollment)
        db.flush()

    now = datetime.now(timezone.utc)
    stage = assessment.assessment_type.upper()

    try:
        if stage == "PRE":
            existing = db.query(PreSemesterResponse).filter(
                PreSemesterResponse.enrollment_id == enrollment.enrollment_id
            ).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Student '{student.name}' ({student.student_id}) has already submitted the PRE assessment for this course.",
                )

            pre_resp = PreSemesterResponse(
                enrollment_id=enrollment.enrollment_id,
                assessment_id=assessment.assessment_id,
                subject_interest=payload.subject_interest or 4,
                self_assessed_skill=payload.self_assessed_skill or 3,
                learning_confidence=payload.learning_confidence or 4,
                expected_difficulty=payload.expected_difficulty or 3,
                preferred_learning_format=payload.preferred_learning_format or "PRACTICAL_LABS",
                preferred_content_types=payload.preferred_content_types,
                learning_source=payload.learning_source,
                free_vs_paid_preference=payload.free_vs_paid_preference,
                career_interest=payload.career_interest,
                placement_goal=payload.placement_goal,
                skills_to_improve=payload.skills_to_improve or "Core fundamentals",
                submitted_at=now,
                updated_at=now,
            )
            db.add(pre_resp)
            db.flush()

            # Record topic feedback
            topics_count = 0
            for tf in payload.topic_feedback:
                topic_id = tf.get("topic_id")
                if topic_id:
                    fb = StudentTopicFeedback(
                        enrollment_id=enrollment.enrollment_id,
                        topic_id=topic_id,
                        stage="PRE",
                        confidence_level=tf.get("confidence_level", 3),
                        difficulty_level=tf.get("difficulty_level", 3),
                    )
                    db.add(fb)
                    topics_count += 1

            db.commit()
            return {
                "status": "success",
                "message": f"PRE assessment submitted successfully for {student.name}.",
                "response_id": pre_resp.response_id,
                "enrollment_id": enrollment.enrollment_id,
                "student_id": student.student_id,
                "student_name": student.name,
                "subject_name": subject.name if subject else "Subject",
                "assessment_type": "PRE",
                "topics_recorded": topics_count,
                "submitted_at": pre_resp.submitted_at,
            }

        elif stage == "MID":
            existing = db.query(MidSemesterResponse).filter(
                MidSemesterResponse.enrollment_id == enrollment.enrollment_id
            ).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Student '{student.name}' ({student.student_id}) has already submitted the MID assessment for this course.",
                )

            skills_json = [
                {
                    "skill_name": s.skill_name,
                    "confidence_level": s.confidence_level,
                    "progress_status": s.progress_status.value if hasattr(s.progress_status, 'value') else str(s.progress_status),
                }
                for s in payload.skills_progress
            ] if payload.skills_progress else [
                {"skill_name": "Core Principles", "confidence_level": payload.current_confidence or 4, "progress_status": "IMPROVED"}
            ]

            barriers_json = [
                b.value if hasattr(b, 'value') else str(b)
                for b in payload.learning_barriers
            ]

            mid_resp = MidSemesterResponse(
                enrollment_id=enrollment.enrollment_id,
                assessment_id=assessment.assessment_id,
                current_confidence=payload.current_confidence or 4,
                current_interest=payload.current_interest or 4,
                perceived_difficulty=payload.perceived_difficulty or 3,
                understanding_level=payload.understanding_level or 4,
                concept_application_ability=payload.concept_application_ability or 4,
                learning_satisfaction=payload.learning_satisfaction or 4,
                useful_learning_format=payload.useful_learning_format.value if payload.useful_learning_format else "PRACTICAL_LABS",
                resource_effectiveness=payload.resource_effectiveness or 4,
                practical_lab_experience=payload.practical_lab_experience or 4,
                teaching_pace=payload.teaching_pace.value if payload.teaching_pace else "JUST_RIGHT",
                learning_barriers=barriers_json,
                skills_progress=skills_json,
                submitted_at=now,
                updated_at=now,
            )
            db.add(mid_resp)
            db.flush()

            topics_count = 0
            for tf in payload.topic_feedback:
                topic_id = tf.get("topic_id")
                if topic_id:
                    fb = StudentTopicFeedback(
                        enrollment_id=enrollment.enrollment_id,
                        topic_id=topic_id,
                        stage="MID",
                        confidence_level=tf.get("confidence_level", 4),
                        difficulty_level=tf.get("difficulty_level", 3),
                        progress_status=tf.get("progress_status", "IN_PROGRESS"),
                    )
                    db.add(fb)
                    topics_count += 1

            db.commit()
            return {
                "status": "success",
                "message": f"MID assessment submitted successfully for {student.name}.",
                "response_id": mid_resp.response_id,
                "enrollment_id": enrollment.enrollment_id,
                "student_id": student.student_id,
                "student_name": student.name,
                "subject_name": subject.name if subject else "Subject",
                "assessment_type": "MID",
                "topics_recorded": topics_count,
                "skills_recorded": len(skills_json),
                "submitted_at": mid_resp.submitted_at,
            }

        elif stage == "END":
            existing = db.query(EndSemesterResponse).filter(
                EndSemesterResponse.enrollment_id == enrollment.enrollment_id
            ).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Student '{student.name}' ({student.student_id}) has already submitted the END assessment for this course.",
                )

            skills_json = [
                {
                    "skill_name": s.skill_name,
                    "confidence_level": s.confidence_level,
                    "progress_status": s.progress_status.value if hasattr(s.progress_status, 'value') else str(s.progress_status),
                }
                for s in payload.skills_progress
            ] if payload.skills_progress else [
                {"skill_name": "Comprehensive Subject Competency", "confidence_level": payload.final_confidence or 5, "progress_status": "MASTERED"}
            ]

            end_resp = EndSemesterResponse(
                enrollment_id=enrollment.enrollment_id,
                assessment_id=assessment.assessment_id,
                final_confidence=payload.final_confidence or 5,
                final_interest=payload.final_interest or 5,
                perceived_difficulty=payload.perceived_difficulty or 2,
                understanding_level=payload.understanding_level or 5,
                concept_application_ability=payload.concept_application_ability or 5,
                learning_satisfaction=payload.learning_satisfaction or 5,
                core_concepts_mastery=payload.core_concepts_mastery or 5,
                problem_solving_ability=payload.problem_solving_ability or 5,
                practical_lab_competence=payload.practical_lab_competence or 5,
                independent_learning_ability=payload.independent_learning_ability or 4,
                real_world_application=payload.real_world_application or 5,
                effective_learning_format=payload.effective_learning_format.value if payload.effective_learning_format else "HYBRID",
                resource_effectiveness=payload.resource_effectiveness or 5,
                practical_lab_experience=payload.practical_lab_experience or 5,
                teaching_pace=payload.teaching_pace.value if payload.teaching_pace else "JUST_RIGHT",
                overall_learning_experience=payload.overall_learning_experience or 5,
                skills_progress=skills_json,
                submitted_at=now,
                updated_at=now,
            )
            db.add(end_resp)
            db.flush()

            topics_count = 0
            for tf in payload.topic_feedback:
                topic_id = tf.get("topic_id")
                if topic_id:
                    fb = StudentTopicFeedback(
                        enrollment_id=enrollment.enrollment_id,
                        topic_id=topic_id,
                        stage="END",
                        confidence_level=tf.get("confidence_level", 5),
                        difficulty_level=tf.get("difficulty_level", 2),
                        progress_status=tf.get("progress_status", "COMPLETED"),
                    )
                    db.add(fb)
                    topics_count += 1

            db.commit()
            return {
                "status": "success",
                "message": f"END assessment submitted successfully for {student.name}.",
                "response_id": end_resp.response_id,
                "enrollment_id": enrollment.enrollment_id,
                "student_id": student.student_id,
                "student_name": student.name,
                "subject_name": subject.name if subject else "Subject",
                "assessment_type": "END",
                "topics_recorded": topics_count,
                "skills_recorded": len(skills_json),
                "submitted_at": end_resp.submitted_at,
            }
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported assessment stage '{stage}'.",
            )
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred while saving assessment: {str(e)}",
        )
