from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.user import User, UserRole
from app.schemas.sli import (
    EndAssessmentFormOut,
    EndAssessmentSubmissionRequest,
    EndAssessmentSubmissionResponse,
    FacultyTeachingContextOut,
    MidAssessmentFormOut,
    MidAssessmentSubmissionRequest,
    MidAssessmentSubmissionResponse,
    PreAssessmentFormOut,
    PreAssessmentSubmissionRequest,
    PreAssessmentSubmissionResponse,
    StudentRosterItemOut,
)
from app.services import sli_end_service, sli_mid_service, sli_pre_service

router = APIRouter(prefix="/sli", tags=["sli"])


# ---------------------------------------------------------------------------
# Teaching Contexts & Roster
# ---------------------------------------------------------------------------

@router.get("/faculty/contexts", response_model=list[FacultyTeachingContextOut])
def get_faculty_contexts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves the teaching contexts assigned to the logged-in faculty in the
    published/active timetable. Includes class, division, subject, active semester,
    total enrolled students, PRE assessment completion count, and MID assessment completion count.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.get_faculty_teaching_contexts(
        db=db,
        faculty_id=current_user.id,
        is_admin=is_admin,
    )


@router.get(
    "/faculty/contexts/{class_id}/{subject_id}/{semester_id}/students",
    response_model=list[StudentRosterItemOut],
)
def get_students_for_context(
    class_id: int,
    subject_id: str,
    semester_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves the student roster for a specific teaching context, including
    enrollment IDs and PRE/MID assessment completion statuses.
    Protected by active timetable authorization.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.get_students_for_context(
        db=db,
        faculty_id=current_user.id,
        class_id=class_id,
        subject_id=subject_id,
        semester_id=semester_id,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# PRE Assessment Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/faculty/pre-assessment/{enrollment_id}",
    response_model=PreAssessmentFormOut,
)
def get_pre_assessment_form(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Loads the PRE-semester assessment form structure, subject metadata,
    configured topics, and existing ratings for a student's enrollment.
    Protected by active timetable authorization.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.get_pre_assessment_form(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.post(
    "/faculty/pre-assessment",
    response_model=PreAssessmentSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_pre_assessment(
    payload: PreAssessmentSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Atomically records or updates a student's PRE-semester assessment responses
    and topic-level feedback for an authorized enrollment.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.save_pre_assessment(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# MID Assessment Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/faculty/mid-assessment/{enrollment_id}",
    response_model=MidAssessmentFormOut,
)
def get_mid_assessment_form(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Loads the MID-semester assessment form structure, student metadata,
    PRE baseline context, topic list with PRE baseline ratings vs MID current,
    and PRE-linked skills progress.
    Protected by active timetable authorization.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_mid_service.get_mid_assessment_form(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.post(
    "/faculty/mid-assessment",
    response_model=MidAssessmentSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_mid_assessment(
    payload: MidAssessmentSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Atomically records or updates a student's MID-semester assessment responses,
    PRE-linked skills progress, and topic-level feedback for an authorized enrollment.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_mid_service.save_mid_assessment(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# END Assessment Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/faculty/end-assessment/{enrollment_id}",
    response_model=EndAssessmentFormOut,
)
def get_end_assessment_form(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Loads the END-semester assessment form structure, student metadata,
    PRE and MID historical baselines, full topic progression history,
    and PRE/MID-linked skills progression.
    Protected by timetable authorization and semester lifecycle (ACTIVE or COMPLETED).
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_end_service.get_end_assessment_form(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.post(
    "/faculty/end-assessment",
    response_model=EndAssessmentSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_end_assessment(
    payload: EndAssessmentSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Atomically records or updates a student's END-semester assessment responses,
    final skills progression, and final topic-level feedback for an authorized enrollment.
    Strictly permitted ONLY during ACTIVE semesters.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_end_service.save_end_assessment(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )

