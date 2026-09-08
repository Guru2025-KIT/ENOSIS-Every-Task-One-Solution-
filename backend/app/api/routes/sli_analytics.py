from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.user import User, UserRole
from app.schemas.sli_analytics import (
    ContextAnalyticsOut,
    ContextAttentionRosterOut,
    StudentLongitudinalAnalyticsOut,
)
from app.services import sli_analytics_service

router = APIRouter(prefix="/sli/faculty/analytics", tags=["sli-analytics"])


@router.get(
    "/context/{class_id}/{subject_id}/{semester_id}",
    response_model=ContextAnalyticsOut,
)
def get_context_analytics(
    class_id: int,
    subject_id: str,
    semester_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves aggregated cohort analytics, trajectories, topic progression matrix,
    skill milestone breakdown, learning experience distributions, and deterministic
    risk findings for an authorized teaching context.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_analytics_service.get_context_analytics(
        db=db,
        faculty_id=current_user.id,
        class_id=class_id,
        subject_id=subject_id,
        semester_id=semester_id,
        is_admin=is_admin,
    )


@router.get(
    "/student/{enrollment_id}",
    response_model=StudentLongitudinalAnalyticsOut,
)
def get_student_analytics(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves 360° longitudinal student analytics (PRE baseline → MID progress → END outcome),
    topic progression, skills progression, and flagged risk areas for an authorized student enrollment.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_analytics_service.get_student_longitudinal_analytics(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.get(
    "/context/{class_id}/{subject_id}/{semester_id}/attention-roster",
    response_model=ContextAttentionRosterOut,
)
def get_context_attention_roster(
    class_id: int,
    subject_id: str,
    semester_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves prioritized list of students requiring attention within the authorized context,
    categorized by risk severity (CRITICAL vs ATTENTION).
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_analytics_service.get_context_attention_roster(
        db=db,
        faculty_id=current_user.id,
        class_id=class_id,
        subject_id=subject_id,
        semester_id=semester_id,
        is_admin=is_admin,
    )
