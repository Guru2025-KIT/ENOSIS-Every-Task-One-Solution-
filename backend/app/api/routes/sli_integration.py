from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.user import User, UserRole
from app.schemas.sli_integration import SliEndCompetencySummaryExportOut
from app.services import sli_integration_service

router = APIRouter(prefix="/sli/integration", tags=["sli-integration"])


@router.get(
    "/export/end-competency-summary/{class_id}/{subject_id}/{semester_id}",
    response_model=SliEndCompetencySummaryExportOut,
)
def export_end_competency_summary(
    class_id: int,
    subject_id: str,
    semester_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Read-only integration pipeline for external modules (such as the CO-PO Outcome Engine).
    Exports aggregated student competency evidence from frozen SLI END records
    for external indirect outcome derivation without exposing raw student assessment rows.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_integration_service.export_sli_end_competency_summary(
        db=db,
        faculty_id=current_user.id,
        class_id=class_id,
        subject_id=subject_id,
        semester_id=semester_id,
        is_admin=is_admin,
    )
