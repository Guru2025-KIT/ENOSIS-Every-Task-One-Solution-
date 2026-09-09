from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.academic import Division, Subject, TeachingAssignment
from app.models.generation_history import GenerationRun
from app.models.sli import (
    AcademicClass, Assessment, Department, EndSemesterResponse, Enrollment, MidSemesterResponse, PreSemesterResponse,
    Semester, Student, StudentTopicFeedback, Topic,
)
from app.models.timetable import TimetableEntry
from app.schemas.sli import PreAssessmentSubmissionRequest


def get_active_timetable_batch_id(db: Session) -> str | None:
    """
    Returns the batch_id of the most recent valid generation run, if generation history exists.
    """
    latest_run = db.query(GenerationRun).filter(
        GenerationRun.validation_passed == True
    ).order_by(GenerationRun.generated_at.desc()).first()
    return latest_run.id if latest_run else None


# ---------------------------------------------------------------------------
# 1. Faculty Teaching Context Resolution
# ---------------------------------------------------------------------------

def get_faculty_teaching_contexts(
    db: Session,
    faculty_id: str,
    is_admin: bool = False,
) -> list[dict]:
    """
    Resolves the active teaching contexts for a logged-in faculty directly
    from the published/active timetable (`timetable_entries`), explicit
    `teaching_assignments`, and faculty-created `assessments`.
    """
    active_batch_id = get_active_timetable_batch_id(db)

    assigned_pairs_set: set[tuple[str, str]] = set()

    # 1. Timetable entries for faculty
    query = db.query(
        TimetableEntry.subject_id,
        TimetableEntry.division_id,
    )
    if not is_admin:
        query = query.filter(TimetableEntry.faculty_id == faculty_id)
    if active_batch_id:
        query = query.filter(TimetableEntry.batch_id == active_batch_id)

    for pair in query.distinct().all():
        if pair[0] and pair[1]:
            assigned_pairs_set.add((pair[0], pair[1]))

    # 2. Explicit teaching assignments for faculty
    ta_query = db.query(
        TeachingAssignment.subject_id,
        TeachingAssignment.division_id,
    )
    if not is_admin:
        ta_query = ta_query.filter(TeachingAssignment.faculty_id == faculty_id)
    for pair in ta_query.distinct().all():
        if pair[0] and pair[1]:
            assigned_pairs_set.add((pair[0], pair[1]))

    # 3. Explicit assessments created by faculty
    assessments_query = db.query(Assessment.subject_id, Assessment.class_id)
    if not is_admin:
        assessments_query = assessments_query.filter(Assessment.faculty_id == faculty_id)
    for sub_id, cls_id in assessments_query.distinct().all():
        if sub_id and cls_id:
            ac = db.query(AcademicClass).filter(AcademicClass.class_id == cls_id).first()
            if ac:
                div = db.query(Division).filter(Division.id == ac.division_id).first() if ac.division_id else None
                if not div:
                    div = db.query(Division).filter(
                        Division.year == ac.year_level,
                        Division.division_code == ac.division,
                    ).first()
                if div:
                    assigned_pairs_set.add((sub_id, div.id))

    assigned_pairs = list(assigned_pairs_set)

    contexts = []

    for subject_id, division_id in assigned_pairs:
        subject = db.query(Subject).filter(Subject.id == subject_id).first()
        division = db.query(Division).filter(Division.id == division_id).first()

        if not subject or not division:
            continue

        # Resolve AcademicClass from division
        academic_class = db.query(AcademicClass).filter(
            AcademicClass.division_id == division.id
        ).first()

        if not academic_class:
            academic_class = db.query(AcademicClass).filter(
                AcademicClass.year_level == division.year,
                AcademicClass.division == division.division_code,
            ).first()

        class_id = academic_class.class_id if academic_class else None

        # Resolve appropriate semester for context
        matched_semester = None
        if class_id:
            enrollment_sem_ids = [
                r[0] for r in db.query(Enrollment.semester_id).filter(
                    Enrollment.class_id == class_id,
                    Enrollment.subject_id == subject.id,
                ).distinct().all()
            ]
            if enrollment_sem_ids:
                matched_semester = db.query(Semester).filter(
                    Semester.semester_id.in_(enrollment_sem_ids),
                    Semester.status.in_(["ACTIVE", "UPCOMING"]),
                ).order_by(Semester.status.asc()).first()

        if not matched_semester:
            matched_semester = db.query(Semester).filter(
                Semester.status == "ACTIVE"
            ).first() or db.query(Semester).filter(
                Semester.status == "UPCOMING"
            ).first()

        semester_id = matched_semester.semester_id if matched_semester else None
        semester_number = matched_semester.semester_number if matched_semester else None
        academic_year = matched_semester.academic_year if matched_semester else None

        # Count total enrolled vs assessed students
        total_students = 0
        assessed_students = 0
        mid_assessed_students = 0
        end_assessed_students = 0

        if class_id and semester_id:
            enrollments_query = db.query(Enrollment).filter(
                Enrollment.class_id == class_id,
                Enrollment.subject_id == subject.id,
                Enrollment.semester_id == semester_id,
            )
            total_students = enrollments_query.count()

            assessed_students = enrollments_query.join(
                PreSemesterResponse,
                Enrollment.enrollment_id == PreSemesterResponse.enrollment_id,
            ).count()

            mid_assessed_students = enrollments_query.join(
                MidSemesterResponse,
                Enrollment.enrollment_id == MidSemesterResponse.enrollment_id,
            ).count()

            end_assessed_students = enrollments_query.join(
                EndSemesterResponse,
                Enrollment.enrollment_id == EndSemesterResponse.enrollment_id,
            ).count()

        contexts.append({
            "subject_id": subject.id,
            "subject_name": subject.name,
            "subject_code": subject.code,
            "division_id": division.id,
            "division_name": division.name,
            "year_level": division.year,
            "division_code": division.division_code,
            "class_id": class_id,
            "semester_id": semester_id,
            "semester_number": semester_number,
            "academic_year": academic_year,
            "total_students": total_students,
            "assessed_students": assessed_students,
            "mid_assessed_students": mid_assessed_students,
            "end_assessed_students": end_assessed_students,
        })

    return contexts


# ---------------------------------------------------------------------------
# 2. Authorization Helper
# ---------------------------------------------------------------------------

def authorize_faculty_teaching_assignment(
    db: Session,
    faculty_id: str,
    subject_id: str,
    division_id: str | None,
    is_admin: bool = False,
) -> None:
    """
    Verifies that the faculty member is assigned to teach the given subject
    and division in the active published timetable or explicit teaching assignments.
    """
    if is_admin:
        return

    active_batch_id = get_active_timetable_batch_id(db)

    query = db.query(TimetableEntry).filter(
        TimetableEntry.faculty_id == faculty_id,
        TimetableEntry.subject_id == subject_id,
    )
    if division_id:
        query = query.filter(TimetableEntry.division_id == division_id)
    if active_batch_id:
        query = query.filter(TimetableEntry.batch_id == active_batch_id)

    assignment_exists = query.first() is not None

    if not assignment_exists:
        ta_query = db.query(TeachingAssignment).filter(
            TeachingAssignment.faculty_id == faculty_id,
            TeachingAssignment.subject_id == subject_id,
        )
        if division_id:
            ta_query = ta_query.filter(TeachingAssignment.division_id == division_id)
        assignment_exists = ta_query.first() is not None

    if not assignment_exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not assigned to teach this subject and division in the active timetable.",
        )


# ---------------------------------------------------------------------------
# 2B. Manual / Dynamic Faculty Teaching Assignment & Options
# ---------------------------------------------------------------------------

def get_available_teaching_options(db: Session) -> dict[str, Any]:
    """
    Returns available subjects, divisions, and active semesters for explicit
    assignment selection when no timetable assignment exists.
    """
    subjects = db.query(Subject).order_by(Subject.name.asc()).all()
    divisions = db.query(Division).order_by(Division.year.asc(), Division.division_code.asc()).all()
    semesters = db.query(Semester).order_by(Semester.semester_number.asc()).all()

    return {
        "subjects": [
            {
                "subject_id": s.id,
                "subject_name": s.name,
                "subject_code": s.code,
            }
            for s in subjects
        ],
        "divisions": [
            {
                "division_id": d.id,
                "division_name": d.name,
                "year_level": d.year,
                "division_code": d.division_code,
            }
            for d in divisions
        ],
        "semesters": [
            {
                "semester_id": sem.semester_id,
                "semester_number": sem.semester_number,
                "academic_year": sem.academic_year,
                "status": sem.status,
            }
            for sem in semesters
        ],
    }


def assign_faculty_teaching_context(
    db: Session,
    faculty_id: str,
    subject_id: str,
    division_id: str,
    semester_id: int | None = None,
) -> dict[str, Any]:
    """
    Explicitly assigns a teaching context (subject + division) to the faculty member.
    Saves/ensures a TeachingAssignment record and AcademicClass association exists.
    """
    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found.")

    division = db.query(Division).filter(Division.id == division_id).first()
    if not division:
        raise HTTPException(status_code=404, detail="Division not found.")

    # 1. Upsert TeachingAssignment
    ta = db.query(TeachingAssignment).filter(
        TeachingAssignment.faculty_id == faculty_id,
        TeachingAssignment.subject_id == subject_id,
        TeachingAssignment.division_id == division_id,
    ).first()
    if not ta:
        ta = TeachingAssignment(
            faculty_id=faculty_id,
            subject_id=subject_id,
            division_id=division_id,
        )
        db.add(ta)
        db.commit()

    # 2. Find or create AcademicClass
    academic_class = db.query(AcademicClass).filter(
        AcademicClass.division_id == division.id
    ).first()
    if not academic_class:
        academic_class = db.query(AcademicClass).filter(
            AcademicClass.year_level == division.year,
            AcademicClass.division == division.division_code,
        ).first()

    if not academic_class:
        dept = db.query(Department).first()
        dept_id = dept.department_id if dept else 1
        academic_class = AcademicClass(
            department_id=dept_id,
            year_level=division.year,
            division=division.division_code,
            division_id=division.id,
            academic_year="2025-26",
        )
        db.add(academic_class)
        db.commit()
        db.refresh(academic_class)

    # 3. Resolve semester
    matched_semester = None
    if semester_id:
        matched_semester = db.query(Semester).filter(Semester.semester_id == semester_id).first()
    if not matched_semester:
        matched_semester = db.query(Semester).filter(Semester.status == "ACTIVE").first() or db.query(Semester).filter(Semester.status == "UPCOMING").first()

    sem_id = matched_semester.semester_id if matched_semester else None
    sem_num = matched_semester.semester_number if matched_semester else None
    acad_yr = matched_semester.academic_year if matched_semester else None

    # Count enrollments
    total_students = 0
    assessed_students = 0
    mid_assessed_students = 0
    end_assessed_students = 0

    if academic_class.class_id and sem_id:
        eq = db.query(Enrollment).filter(
            Enrollment.class_id == academic_class.class_id,
            Enrollment.subject_id == subject.id,
            Enrollment.semester_id == sem_id,
        )
        total_students = eq.count()
        assessed_students = eq.join(PreSemesterResponse, Enrollment.enrollment_id == PreSemesterResponse.enrollment_id).count()
        mid_assessed_students = eq.join(MidSemesterResponse, Enrollment.enrollment_id == MidSemesterResponse.enrollment_id).count()
        end_assessed_students = eq.join(EndSemesterResponse, Enrollment.enrollment_id == EndSemesterResponse.enrollment_id).count()

    return {
        "subject_id": subject.id,
        "subject_name": subject.name,
        "subject_code": subject.code,
        "division_id": division.id,
        "division_name": division.name,
        "year_level": division.year,
        "division_code": division.division_code,
        "class_id": academic_class.class_id,
        "semester_id": sem_id,
        "semester_number": sem_num,
        "academic_year": acad_yr,
        "total_students": total_students,
        "assessed_students": assessed_students,
        "mid_assessed_students": mid_assessed_students,
        "end_assessed_students": end_assessed_students,
    }



# ---------------------------------------------------------------------------
# 3. Student Roster for Teaching Context
# ---------------------------------------------------------------------------

def get_students_for_context(
    db: Session,
    faculty_id: str,
    class_id: int,
    subject_id: str,
    semester_id: int,
    is_admin: bool = False,
) -> list[dict]:
    """
    Retrieves student roster with PRE and MID assessment status for an authorized teaching context.
    """
    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == class_id).first()
    if not academic_class:
        raise HTTPException(status_code=404, detail="Class not found.")

    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found.")

    semester = db.query(Semester).filter(Semester.semester_id == semester_id).first()
    if not semester:
        raise HTTPException(status_code=404, detail="Semester not found.")

    # Validate semester lifecycle (ACTIVE or UPCOMING)
    if semester.status not in ("ACTIVE", "UPCOMING"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Teaching context roster is only open for UPCOMING or ACTIVE semesters (Current: {semester.status}).",
        )

    # Check timetable authorization
    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject_id, division_id, is_admin)

    # Fetch enrolled students
    records = db.query(
        Enrollment.enrollment_id,
        Student.student_id,
        Student.name,
        Student.email,
        Student.current_year,
        Student.division,
        PreSemesterResponse.response_id.isnot(None).label("is_pre_assessed"),
        MidSemesterResponse.response_id.isnot(None).label("is_mid_assessed"),
        EndSemesterResponse.response_id.isnot(None).label("is_end_assessed"),
        PreSemesterResponse.submitted_at.label("pre_submitted_at"),
        PreSemesterResponse.updated_at.label("pre_updated_at"),
        MidSemesterResponse.submitted_at.label("mid_submitted_at"),
        MidSemesterResponse.updated_at.label("mid_updated_at"),
        EndSemesterResponse.submitted_at.label("end_submitted_at"),
        EndSemesterResponse.updated_at.label("end_updated_at"),
    ).join(
        Student, Enrollment.student_id == Student.student_id
    ).outerjoin(
        PreSemesterResponse, Enrollment.enrollment_id == PreSemesterResponse.enrollment_id
    ).outerjoin(
        MidSemesterResponse, Enrollment.enrollment_id == MidSemesterResponse.enrollment_id
    ).outerjoin(
        EndSemesterResponse, Enrollment.enrollment_id == EndSemesterResponse.enrollment_id
    ).filter(
        Enrollment.class_id == class_id,
        Enrollment.subject_id == subject_id,
        Enrollment.semester_id == semester_id,
    ).order_by(Student.student_id.asc()).all()

    return [
        {
            "enrollment_id": r.enrollment_id,
            "student_id": r.student_id,
            "name": r.name,
            "email": r.email,
            "current_year": r.current_year,
            "division": r.division,
            "is_assessed": bool(r.is_pre_assessed or r.is_mid_assessed or r.is_end_assessed),
            "is_pre_assessed": bool(r.is_pre_assessed),
            "is_mid_assessed": bool(r.is_mid_assessed),
            "is_end_assessed": bool(r.is_end_assessed),
            "submitted_at": r.pre_submitted_at,
            "updated_at": r.pre_updated_at,
        }
        for r in records
    ]


# ---------------------------------------------------------------------------
# 4. PRE Assessment Form Details
# ---------------------------------------------------------------------------

def get_pre_assessment_form(
    db: Session,
    faculty_id: str,
    enrollment_id: int,
    is_admin: bool = False,
) -> dict:
    """
    Loads PRE assessment form data, student details, topics, and existing responses for an enrollment.
    """
    enrollment = db.query(Enrollment).filter(Enrollment.enrollment_id == enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == enrollment.class_id).first()
    subject = db.query(Subject).filter(Subject.id == enrollment.subject_id).first()
    semester = db.query(Semester).filter(Semester.semester_id == enrollment.semester_id).first()
    student = db.query(Student).filter(Student.student_id == enrollment.student_id).first()

    if not academic_class or not subject or not semester or not student:
        raise HTTPException(status_code=404, detail="Associated academic records not found.")

    if semester.status not in ("ACTIVE", "UPCOMING"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"PRE assessment is only open for UPCOMING or ACTIVE semesters (Current: {semester.status}).",
        )

    # Timetable authorization
    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division_id, is_admin)

    # Topics for subject
    topics = db.query(Topic).filter(Topic.subject_id == subject.id).all()

    # Existing pre-semester response
    pre_resp = db.query(PreSemesterResponse).filter(
        PreSemesterResponse.enrollment_id == enrollment.enrollment_id
    ).first()

    # Existing topic feedbacks
    topic_feedbacks = db.query(StudentTopicFeedback).filter(
        StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
        StudentTopicFeedback.stage == "PRE",
    ).all()
    feedback_map = {f.topic_id: f for f in topic_feedbacks}

    topic_items = []
    for t in topics:
        f = feedback_map.get(t.topic_id)
        topic_items.append({
            "topic_id": t.topic_id,
            "topic_name": t.topic_name,
            "confidence_level": f.confidence_level if f else None,
            "difficulty_level": f.difficulty_level if f else None,
        })

    class_display_name = f"Year {academic_class.year_level} - {academic_class.division or ''}".strip()

    return {
        "enrollment_id": enrollment.enrollment_id,
        "student_id": student.student_id,
        "student_name": student.name,
        "subject_id": subject.id,
        "subject_name": subject.name,
        "subject_code": subject.code,
        "class_id": academic_class.class_id,
        "class_name": class_display_name,
        "year_level": academic_class.year_level or 1,
        "division": academic_class.division or "A",
        "semester_id": semester.semester_id,
        "semester_number": semester.semester_number or 1,
        "academic_year": semester.academic_year,
        "semester_status": semester.status or "ACTIVE",
        "is_submitted": pre_resp is not None,
        "subject_interest": pre_resp.subject_interest if pre_resp else None,
        "self_assessed_skill": pre_resp.self_assessed_skill if pre_resp else None,
        "learning_confidence": pre_resp.learning_confidence if pre_resp else None,
        "expected_difficulty": pre_resp.expected_difficulty if pre_resp else None,
        "preferred_learning_format": pre_resp.preferred_learning_format if pre_resp else None,
        "preferred_content_types": pre_resp.preferred_content_types if pre_resp else None,
        "learning_source": pre_resp.learning_source if pre_resp else None,
        "free_vs_paid_preference": pre_resp.free_vs_paid_preference if pre_resp else None,
        "career_interest": pre_resp.career_interest if pre_resp else None,
        "placement_goal": pre_resp.placement_goal if pre_resp else None,
        "skills_to_improve": pre_resp.skills_to_improve if pre_resp else None,
        "submitted_at": pre_resp.submitted_at if pre_resp else None,
        "updated_at": pre_resp.updated_at if pre_resp else None,
        "topics": topic_items,
    }


# ---------------------------------------------------------------------------
# 5. Atomic PRE Assessment Submission / Upsert
# ---------------------------------------------------------------------------

def save_pre_assessment(
    db: Session,
    faculty_id: str,
    payload: PreAssessmentSubmissionRequest,
    is_admin: bool = False,
) -> dict:
    """
    Atomically records or updates a student's PRE assessment responses and topic feedback.
    """
    enrollment = db.query(Enrollment).filter(
        Enrollment.enrollment_id == payload.enrollment_id
    ).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == enrollment.class_id).first()
    subject = db.query(Subject).filter(Subject.id == enrollment.subject_id).first()
    semester = db.query(Semester).filter(Semester.semester_id == enrollment.semester_id).first()
    student = db.query(Student).filter(Student.student_id == enrollment.student_id).first()

    if not academic_class or not subject or not semester or not student:
        raise HTTPException(status_code=404, detail="Associated academic records not found.")

    if semester.status not in ("ACTIVE", "UPCOMING"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"PRE assessment is only open for UPCOMING or ACTIVE semesters (Current: {semester.status}).",
        )

    # Timetable authorization
    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division_id, is_admin)

    # Validate all topic IDs belong to the enrolled subject
    valid_topic_ids = {
        t.topic_id for t in db.query(Topic.topic_id).filter(Topic.subject_id == subject.id).all()
    }
    for item in payload.topic_feedback:
        if item.topic_id not in valid_topic_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Topic ID {item.topic_id} does not belong to subject '{subject.name}'.",
            )

    now = datetime.now(timezone.utc)

    try:
        # Upsert PreSemesterResponse
        pre_resp = db.query(PreSemesterResponse).filter(
            PreSemesterResponse.enrollment_id == enrollment.enrollment_id
        ).first()

        if not pre_resp:
            pre_resp = PreSemesterResponse(
                enrollment_id=enrollment.enrollment_id,
                subject_interest=payload.subject_interest,
                self_assessed_skill=payload.self_assessed_skill,
                learning_confidence=payload.learning_confidence,
                expected_difficulty=payload.expected_difficulty,
                preferred_learning_format=payload.preferred_learning_format,
                preferred_content_types=payload.preferred_content_types,
                learning_source=payload.learning_source,
                free_vs_paid_preference=payload.free_vs_paid_preference,
                career_interest=payload.career_interest,
                placement_goal=payload.placement_goal,
                skills_to_improve=payload.skills_to_improve,
                submitted_at=now,
                updated_at=now,
            )
            db.add(pre_resp)
            db.flush()
        else:
            pre_resp.subject_interest = payload.subject_interest
            pre_resp.self_assessed_skill = payload.self_assessed_skill
            pre_resp.learning_confidence = payload.learning_confidence
            pre_resp.expected_difficulty = payload.expected_difficulty
            pre_resp.preferred_learning_format = payload.preferred_learning_format
            pre_resp.preferred_content_types = payload.preferred_content_types
            pre_resp.learning_source = payload.learning_source
            pre_resp.free_vs_paid_preference = payload.free_vs_paid_preference
            pre_resp.career_interest = payload.career_interest
            pre_resp.placement_goal = payload.placement_goal
            pre_resp.skills_to_improve = payload.skills_to_improve
            pre_resp.updated_at = now

        # Upsert Topic Feedbacks
        topics_count = 0
        for item in payload.topic_feedback:
            fb = db.query(StudentTopicFeedback).filter(
                StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
                StudentTopicFeedback.topic_id == item.topic_id,
                StudentTopicFeedback.stage == "PRE",
            ).first()

            if not fb:
                fb = StudentTopicFeedback(
                    enrollment_id=enrollment.enrollment_id,
                    topic_id=item.topic_id,
                    stage="PRE",
                    confidence_level=item.confidence_level,
                    difficulty_level=item.difficulty_level,
                )
                db.add(fb)
            else:
                fb.confidence_level = item.confidence_level
                fb.difficulty_level = item.difficulty_level

            topics_count += 1

        db.commit()
        db.refresh(pre_resp)
    except Exception:
        db.rollback()
        raise

    return {
        "status": "success",
        "message": f"PRE-semester assessment saved successfully for student {student.student_id}.",
        "response_id": pre_resp.response_id,
        "enrollment_id": enrollment.enrollment_id,
        "student_id": student.student_id,
        "student_name": student.name,
        "subject_name": subject.name,
        "topics_recorded": topics_count,
        "submitted_at": pre_resp.submitted_at,
        "updated_at": pre_resp.updated_at,
    }
