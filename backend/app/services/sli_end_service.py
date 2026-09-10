from datetime import datetime, timezone
import re
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.academic import Division, Subject
from app.models.sli import (
    AcademicClass, EndSemesterResponse, Enrollment, MidSemesterResponse,
    PreSemesterResponse, Semester, Student, StudentTopicFeedback, Topic,
)
from app.schemas.sli import (
    AllowedLearningFormat, EndAssessmentSubmissionRequest,
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


def get_end_assessment_form(
    db: Session,
    faculty_id: str,
    enrollment_id: int,
    is_admin: bool = False,
) -> dict:
    """
    Loads END assessment form data, student details, topics with complete PRE baseline vs MID vs END history,
    target skills progression, and existing END responses for an enrollment.
    Permits read access during ACTIVE and COMPLETED semesters.
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

    # END GET lifecycle: Allowed for all historical semesters (ACTIVE, COMPLETED, ARCHIVED, CANCELLED)
    allowed_statuses = {"ACTIVE", "COMPLETED", "ARCHIVED", "CANCELLED"}
    if semester.status not in allowed_statuses:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"END assessment view is not available for semester status '{semester.status}'.",
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

    # 2. Fetch MID baseline / checkpoint
    mid_resp = db.query(MidSemesterResponse).filter(
        MidSemesterResponse.enrollment_id == enrollment.enrollment_id
    ).first()

    mid_topic_feedbacks = db.query(StudentTopicFeedback).filter(
        StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
        StudentTopicFeedback.stage == "MID",
    ).all()
    mid_topic_map = {f.topic_id: f for f in mid_topic_feedbacks}

    mid_format_enum = None
    if mid_resp and mid_resp.useful_learning_format:
        try:
            mid_format_enum = AllowedLearningFormat(mid_resp.useful_learning_format)
        except ValueError:
            mid_format_enum = None

    mid_pace_enum = None
    if mid_resp and mid_resp.teaching_pace:
        try:
            mid_pace_enum = TeachingPace(mid_resp.teaching_pace)
        except ValueError:
            mid_pace_enum = None

    mid_baseline_data = {
        "has_mid_assessment": mid_resp is not None,
        "current_confidence": mid_resp.current_confidence if mid_resp else None,
        "current_interest": mid_resp.current_interest if mid_resp else None,
        "perceived_difficulty": mid_resp.perceived_difficulty if mid_resp else None,
        "understanding_level": mid_resp.understanding_level if mid_resp else None,
        "concept_application_ability": mid_resp.concept_application_ability if mid_resp else None,
        "learning_satisfaction": mid_resp.learning_satisfaction if mid_resp else None,
        "useful_learning_format": mid_format_enum,
        "teaching_pace": mid_pace_enum,
    }

    # 3. Fetch existing END responses
    end_resp = db.query(EndSemesterResponse).filter(
        EndSemesterResponse.enrollment_id == enrollment.enrollment_id
    ).first()

    end_topic_feedbacks = db.query(StudentTopicFeedback).filter(
        StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
        StudentTopicFeedback.stage == "END",
    ).all()
    end_topic_map = {f.topic_id: f for f in end_topic_feedbacks}

    # 4. Determine Skills Progression:
    # Preference: Existing END -> Existing MID structured list -> PRE skills_to_improve -> Empty list
    skills_progress_list: list[dict[str, Any]] = []
    if end_resp and end_resp.skills_progress:
        for s in end_resp.skills_progress:
            skills_progress_list.append({
                "skill_name": s.get("skill_name", ""),
                "confidence_level": s.get("confidence_level", 3),
                "progress_status": s.get("progress_status", SkillProgressStatus.IN_PROGRESS.value),
            })
    elif mid_resp and mid_resp.skills_progress:
        for s in mid_resp.skills_progress:
            skills_progress_list.append({
                "skill_name": s.get("skill_name", ""),
                "confidence_level": s.get("confidence_level", 3),
                "progress_status": s.get("progress_status", SkillProgressStatus.IN_PROGRESS.value),
            })
    elif pre_resp and pre_resp.skills_to_improve:
        skill_names = _parse_pre_skills(pre_resp.skills_to_improve)
        for name in skill_names:
            skills_progress_list.append({
                "skill_name": name,
                "confidence_level": 3,
                "progress_status": SkillProgressStatus.IN_PROGRESS.value,
            })

    # 5. Build merged topics list with PRE vs MID vs END history
    topics = db.query(Topic).filter(Topic.subject_id == subject.id).order_by(Topic.topic_id.asc()).all()
    topics_out = []
    for t in topics:
        pre_f = pre_topic_map.get(t.topic_id)
        mid_f = mid_topic_map.get(t.topic_id)
        end_f = end_topic_map.get(t.topic_id)

        mid_status_enum = None
        if mid_f and mid_f.progress_status:
            try:
                mid_status_enum = TopicProgressStatus(mid_f.progress_status)
            except ValueError:
                mid_status_enum = None

        end_status_enum = None
        if end_f and end_f.progress_status:
            try:
                end_status_enum = TopicProgressStatus(end_f.progress_status)
            except ValueError:
                end_status_enum = None

        topics_out.append({
            "topic_id": t.topic_id,
            "topic_name": t.topic_name or f"Topic {t.topic_id}",
            "pre_confidence": pre_f.confidence_level if pre_f else None,
            "pre_difficulty": pre_f.difficulty_level if pre_f else None,
            "mid_confidence": mid_f.confidence_level if mid_f else None,
            "mid_difficulty": mid_f.difficulty_level if mid_f else None,
            "mid_progress_status": mid_status_enum,
            "end_confidence": end_f.confidence_level if end_f else None,
            "end_difficulty": end_f.difficulty_level if end_f else None,
            "end_progress_status": end_status_enum,
        })

    end_format_enum = None
    if end_resp and end_resp.effective_learning_format:
        try:
            end_format_enum = AllowedLearningFormat(end_resp.effective_learning_format)
        except ValueError:
            end_format_enum = None

    end_pace_enum = None
    if end_resp and end_resp.teaching_pace:
        try:
            end_pace_enum = TeachingPace(end_resp.teaching_pace)
        except ValueError:
            end_pace_enum = None

    class_display_name = f"Year {academic_class.year_level or 1} - Div {academic_class.division or 'A'}"

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
        "division_name": academic_class.division or "A",
        "semester_id": semester.semester_id,
        "semester_number": semester.semester_number or 1,
        "academic_year": semester.academic_year or "",
        "semester_status": semester.status or "ACTIVE",
        "is_submitted": end_resp is not None,
        "pre_baseline": pre_baseline_data,
        "mid_baseline": mid_baseline_data,
        # 1. Final Subject Understanding
        "final_confidence": end_resp.final_confidence if end_resp else None,
        "final_interest": end_resp.final_interest if end_resp else None,
        "perceived_difficulty": end_resp.perceived_difficulty if end_resp else None,
        "understanding_level": end_resp.understanding_level if end_resp else None,
        "concept_application_ability": end_resp.concept_application_ability if end_resp else None,
        "learning_satisfaction": end_resp.learning_satisfaction if end_resp else None,
        # 2. Final Competency & Application
        "core_concepts_mastery": end_resp.core_concepts_mastery if end_resp else None,
        "problem_solving_ability": end_resp.problem_solving_ability if end_resp else None,
        "practical_lab_competence": end_resp.practical_lab_competence if end_resp else None,
        "independent_learning_ability": end_resp.independent_learning_ability if end_resp else None,
        "real_world_application": end_resp.real_world_application if end_resp else None,
        # 3. Overall Learning Experience
        "effective_learning_format": end_format_enum,
        "resource_effectiveness": end_resp.resource_effectiveness if end_resp else None,
        "practical_lab_experience": end_resp.practical_lab_experience if end_resp else None,
        "teaching_pace": end_pace_enum,
        "overall_learning_experience": end_resp.overall_learning_experience if end_resp else None,
        # 4. Target Skills Progression
        "skills_progress": skills_progress_list,
        # 5. Timestamps & Topics
        "submitted_at": end_resp.submitted_at if end_resp else None,
        "updated_at": end_resp.updated_at if end_resp else None,
        "topics": topics_out,
    }


def save_end_assessment(
    db: Session,
    faculty_id: str,
    payload: EndAssessmentSubmissionRequest,
    is_admin: bool = False,
) -> dict:
    """
    Atomically saves or updates an END-semester assessment response,
    skills progression, and topic-level feedback for an authorized enrollment.
    STRICT LIFECYCLE: Submissions are ONLY allowed during ACTIVE semesters.
    """
    enrollment = db.query(Enrollment).filter(Enrollment.enrollment_id == payload.enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == enrollment.class_id).first()
    subject = db.query(Subject).filter(Subject.id == enrollment.subject_id).first()
    semester = db.query(Semester).filter(Semester.semester_id == enrollment.semester_id).first()
    student = db.query(Student).filter(Student.student_id == enrollment.student_id).first()

    if not academic_class or not subject or not semester or not student:
        raise HTTPException(status_code=404, detail="Associated academic records not found.")

    # Strict END POST lifecycle rule: ONLY allowed while semester is ACTIVE
    if semester.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"END assessment submissions are only allowed during ACTIVE semesters (Current: {semester.status}).",
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

    # Convert structured skills to serializable JSON dicts
    skills_json = [
        {
            "skill_name": s.skill_name.strip(),
            "confidence_level": s.confidence_level,
            "progress_status": s.progress_status.value if isinstance(s.progress_status, SkillProgressStatus) else str(s.progress_status),
        }
        for s in payload.skills_progress
        if s.skill_name and s.skill_name.strip()
    ]

    format_val = payload.effective_learning_format.value if payload.effective_learning_format else None
    pace_val = payload.teaching_pace.value if payload.teaching_pace else None

    now = datetime.now(timezone.utc)

    try:
        # 1. Upsert EndSemesterResponse
        end_resp = db.query(EndSemesterResponse).filter(
            EndSemesterResponse.enrollment_id == enrollment.enrollment_id
        ).first()

        if not end_resp:
            end_resp = EndSemesterResponse(
                enrollment_id=enrollment.enrollment_id,
                final_confidence=payload.final_confidence,
                final_interest=payload.final_interest,
                perceived_difficulty=payload.perceived_difficulty,
                understanding_level=payload.understanding_level,
                concept_application_ability=payload.concept_application_ability,
                learning_satisfaction=payload.learning_satisfaction,
                core_concepts_mastery=payload.core_concepts_mastery,
                problem_solving_ability=payload.problem_solving_ability,
                practical_lab_competence=payload.practical_lab_competence,
                independent_learning_ability=payload.independent_learning_ability,
                real_world_application=payload.real_world_application,
                effective_learning_format=format_val,
                resource_effectiveness=payload.resource_effectiveness,
                practical_lab_experience=payload.practical_lab_experience,
                teaching_pace=pace_val,
                overall_learning_experience=payload.overall_learning_experience,
                skills_progress=skills_json,
                submitted_at=now,
                updated_at=now,
            )
            db.add(end_resp)
            db.flush()
        else:
            end_resp.final_confidence = payload.final_confidence
            end_resp.final_interest = payload.final_interest
            end_resp.perceived_difficulty = payload.perceived_difficulty
            end_resp.understanding_level = payload.understanding_level
            end_resp.concept_application_ability = payload.concept_application_ability
            end_resp.learning_satisfaction = payload.learning_satisfaction
            end_resp.core_concepts_mastery = payload.core_concepts_mastery
            end_resp.problem_solving_ability = payload.problem_solving_ability
            end_resp.practical_lab_competence = payload.practical_lab_competence
            end_resp.independent_learning_ability = payload.independent_learning_ability
            end_resp.real_world_application = payload.real_world_application
            end_resp.effective_learning_format = format_val
            end_resp.resource_effectiveness = payload.resource_effectiveness
            end_resp.practical_lab_experience = payload.practical_lab_experience
            end_resp.teaching_pace = pace_val
            end_resp.overall_learning_experience = payload.overall_learning_experience
            end_resp.skills_progress = skills_json
            end_resp.updated_at = now

        # 2. Upsert Topic Feedbacks with stage = 'END'
        topics_count = 0
        valid_topic_ids = {
            t.topic_id for t in db.query(Topic.topic_id).filter(Topic.subject_id == subject.id).all()
        }

        for item in payload.topic_feedback:
            if item.topic_id not in valid_topic_ids:
                raise HTTPException(
                    status_code=400,
                    detail=f"Topic ID {item.topic_id} is not valid for subject '{subject.name}'.",
                )

            topic_status_val = item.progress_status.value if item.progress_status else None

            existing_feedback = db.query(StudentTopicFeedback).filter(
                StudentTopicFeedback.enrollment_id == enrollment.enrollment_id,
                StudentTopicFeedback.topic_id == item.topic_id,
                StudentTopicFeedback.stage == "END",
            ).first()

            if existing_feedback:
                existing_feedback.confidence_level = item.confidence_level
                existing_feedback.difficulty_level = item.difficulty_level
                existing_feedback.progress_status = topic_status_val
            else:
                new_feedback = StudentTopicFeedback(
                    enrollment_id=enrollment.enrollment_id,
                    topic_id=item.topic_id,
                    stage="END",
                    confidence_level=item.confidence_level,
                    difficulty_level=item.difficulty_level,
                    progress_status=topic_status_val,
                )
                db.add(new_feedback)
            topics_count += 1

        db.commit()
        db.refresh(end_resp)

        return {
            "status": "success",
            "message": "END-semester student assessment saved successfully.",
            "response_id": end_resp.response_id,
            "enrollment_id": enrollment.enrollment_id,
            "student_id": student.student_id,
            "student_name": student.name,
            "subject_name": subject.name,
            "topics_recorded": topics_count,
            "skills_recorded": len(skills_json),
            "submitted_at": end_resp.submitted_at,
            "updated_at": end_resp.updated_at,
        }
    except Exception:
        db.rollback()
        raise
