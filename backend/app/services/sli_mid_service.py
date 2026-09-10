from datetime import datetime, timezone
import re
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.academic import Division, Subject
from app.models.sli import (
    AcademicClass, Enrollment, MidSemesterResponse, PreSemesterResponse,
    Semester, Student, StudentTopicFeedback, Topic,
)
from app.schemas.sli import (
    AllowedLearningFormat, LearningBarrier, MidAssessmentSubmissionRequest,
    SkillProgressItem, SkillProgressStatus, TeachingPace, TopicProgressStatus,
)
from app.services.sli_pre_service import (
    authorize_faculty_teaching_assignment,
)


def _parse_pre_skills(skills_text: str | None) -> list[str]:
    """
    Extracts structured skill names from the PRE skills_to_improve text.
    Splits by commas, semicolons, or newlines, trimming whitespace.
    """
    if not skills_text or not skills_text.strip():
        return []
    parts = re.split(r'[,;\n]+', skills_text)
    cleaned = [p.strip() for p in parts if p.strip()]
    return list(dict.fromkeys(cleaned))


def get_mid_assessment_form(
    db: Session,
    faculty_id: str,
    enrollment_id: int,
    is_admin: bool = False,
) -> dict:
    """
    Loads MID assessment form data, student details, topics with PRE baseline vs MID current,
    PRE target skills, and existing MID responses for an enrollment.
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

    # Strict MID lifecycle: ONLY allowed during ACTIVE semester
    if semester.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"MID assessment is only open for ACTIVE semesters (Current: {semester.status}).",
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

    # 1. Fetch PRE baseline
    pre_resp = db.query(PreSemesterResponse).filter(
        PreSemesterResponse.enrollment_id == enrollment.enrollment_id
    ).first()

    pre_topic_feedbacks = db.query(StudentTopicFeedback).filter(
        StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
        StudentTopicFeedback.stage == "PRE",
    ).all()
    pre_topic_map = {f.topic_id: f for f in pre_topic_feedbacks}

    pre_baseline_data = {
        "has_pre_assessment": pre_resp is not None,
        "learning_confidence": pre_resp.learning_confidence if pre_resp else None,
        "subject_interest": pre_resp.subject_interest if pre_resp else None,
        "expected_difficulty": pre_resp.expected_difficulty if pre_resp else None,
        "skills_to_improve": pre_resp.skills_to_improve if pre_resp else None,
        "preferred_learning_format": pre_resp.preferred_learning_format if pre_resp else None,
    }

    # 2. Fetch existing MID responses
    mid_resp = db.query(MidSemesterResponse).filter(
        MidSemesterResponse.enrollment_id == enrollment.enrollment_id
    ).first()

    mid_topic_feedbacks = db.query(StudentTopicFeedback).filter(
        StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
        StudentTopicFeedback.stage == "MID",
    ).all()
    mid_topic_map = {f.topic_id: f for f in mid_topic_feedbacks}

    # 3. Topics with PRE baseline and MID current values
    topics = db.query(Topic).filter(Topic.subject_id == subject.id).all()
    topic_items = []
    for t in topics:
        pre_f = pre_topic_map.get(t.topic_id)
        mid_f = mid_topic_map.get(t.topic_id)
        topic_items.append({
            "topic_id": t.topic_id,
            "topic_name": t.topic_name,
            "pre_confidence": pre_f.confidence_level if pre_f else None,
            "pre_difficulty": pre_f.difficulty_level if pre_f else None,
            "mid_confidence": mid_f.confidence_level if mid_f else None,
            "mid_difficulty": mid_f.difficulty_level if mid_f else None,
            "progress_status": mid_f.progress_status if mid_f else None,
        })

    # 4. PRE-linked Skills Progress
    skills_progress_list = []
    if mid_resp and mid_resp.skills_progress:
        # Existing recorded MID skills progress
        skills_progress_list = mid_resp.skills_progress
    else:
        # Pre-seed skills from PRE baseline
        pre_skills = _parse_pre_skills(pre_resp.skills_to_improve if pre_resp else None)
        for skill in pre_skills:
            skills_progress_list.append({
                "skill_name": skill,
                "confidence_level": 3,
                "progress_status": SkillProgressStatus.IN_PROGRESS.value,
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
        "is_submitted": mid_resp is not None,
        "pre_baseline": pre_baseline_data,
        "current_confidence": mid_resp.current_confidence if mid_resp else None,
        "current_interest": mid_resp.current_interest if mid_resp else None,
        "perceived_difficulty": mid_resp.perceived_difficulty if mid_resp else None,
        "understanding_level": mid_resp.understanding_level if mid_resp else None,
        "concept_application_ability": mid_resp.concept_application_ability if mid_resp else None,
        "learning_satisfaction": mid_resp.learning_satisfaction if mid_resp else None,
        "useful_learning_format": mid_resp.useful_learning_format if mid_resp else None,
        "resource_effectiveness": mid_resp.resource_effectiveness if mid_resp else None,
        "practical_lab_experience": mid_resp.practical_lab_experience if mid_resp else None,
        "teaching_pace": mid_resp.teaching_pace if mid_resp else None,
        "learning_barriers": mid_resp.learning_barriers if mid_resp and mid_resp.learning_barriers else [],
        "skills_progress": skills_progress_list,
        "submitted_at": mid_resp.submitted_at if mid_resp else None,
        "updated_at": mid_resp.updated_at if mid_resp else None,
        "topics": topic_items,
    }


def save_mid_assessment(
    db: Session,
    faculty_id: str,
    payload: MidAssessmentSubmissionRequest,
    is_admin: bool = False,
) -> dict:
    """
    Atomically records or updates a student's MID assessment responses,
    PRE-linked skills progress, and topic feedback.
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

    # Strict MID lifecycle: ONLY allowed during ACTIVE semester
    if semester.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"MID assessment is only open for ACTIVE semesters (Current: {semester.status}).",
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
        # Format skills_progress as JSON list of dicts
        skills_json = [
            {
                "skill_name": s.skill_name,
                "confidence_level": s.confidence_level,
                "progress_status": s.progress_status.value if hasattr(s.progress_status, 'value') else str(s.progress_status),
            }
            for s in payload.skills_progress
        ]

        # Format learning_barriers as JSON list of strings
        barriers_json = [
            b.value if hasattr(b, 'value') else str(b)
            for b in payload.learning_barriers
        ]

        # Upsert MidSemesterResponse
        mid_resp = db.query(MidSemesterResponse).filter(
            MidSemesterResponse.enrollment_id == enrollment.enrollment_id
        ).first()

        format_val = payload.useful_learning_format.value if payload.useful_learning_format else None
        pace_val = payload.teaching_pace.value if payload.teaching_pace else None

        if not mid_resp:
            mid_resp = MidSemesterResponse(
                enrollment_id=enrollment.enrollment_id,
                current_confidence=payload.current_confidence,
                current_interest=payload.current_interest,
                perceived_difficulty=payload.perceived_difficulty,
                understanding_level=payload.understanding_level,
                concept_application_ability=payload.concept_application_ability,
                learning_satisfaction=payload.learning_satisfaction,
                useful_learning_format=format_val,
                resource_effectiveness=payload.resource_effectiveness,
                practical_lab_experience=payload.practical_lab_experience,
                teaching_pace=pace_val,
                learning_barriers=barriers_json,
                skills_progress=skills_json,
                submitted_at=now,
                updated_at=now,
            )
            db.add(mid_resp)
            db.flush()
        else:
            mid_resp.current_confidence = payload.current_confidence
            mid_resp.current_interest = payload.current_interest
            mid_resp.perceived_difficulty = payload.perceived_difficulty
            mid_resp.understanding_level = payload.understanding_level
            mid_resp.concept_application_ability = payload.concept_application_ability
            mid_resp.learning_satisfaction = payload.learning_satisfaction
            mid_resp.useful_learning_format = format_val
            mid_resp.resource_effectiveness = payload.resource_effectiveness
            mid_resp.practical_lab_experience = payload.practical_lab_experience
            mid_resp.teaching_pace = pace_val
            mid_resp.learning_barriers = barriers_json
            mid_resp.skills_progress = skills_json
            mid_resp.updated_at = now

        # Upsert Topic Feedbacks with stage = 'MID'
        topics_count = 0
        for item in payload.topic_feedback:
            status_val = item.progress_status.value if hasattr(item.progress_status, 'value') else str(item.progress_status)
            fb = db.query(StudentTopicFeedback).filter(
                StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
                StudentTopicFeedback.topic_id == item.topic_id,
                StudentTopicFeedback.stage == "MID",
            ).first()

            if not fb:
                fb = StudentTopicFeedback(
                    enrollment_id=enrollment.enrollment_id,
                    topic_id=item.topic_id,
                    stage="MID",
                    confidence_level=item.confidence_level,
                    difficulty_level=item.difficulty_level,
                    progress_status=status_val,
                )
                db.add(fb)
            else:
                fb.confidence_level = item.confidence_level
                fb.difficulty_level = item.difficulty_level
                fb.progress_status = status_val

            topics_count += 1

        db.commit()
        db.refresh(mid_resp)
    except Exception:
        db.rollback()
        raise

    return {
        "status": "success",
        "message": f"MID-semester assessment saved successfully for student {student.student_id}.",
        "response_id": mid_resp.response_id,
        "enrollment_id": enrollment.enrollment_id,
        "student_id": student.student_id,
        "student_name": student.name,
        "subject_name": subject.name,
        "topics_recorded": topics_count,
        "skills_recorded": len(payload.skills_progress),
        "submitted_at": mid_resp.submitted_at,
        "updated_at": mid_resp.updated_at,
    }
