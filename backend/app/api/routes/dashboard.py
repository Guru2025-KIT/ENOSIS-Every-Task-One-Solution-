from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.user import User
from app.schemas.dashboard import DashboardSummaryOut
from app.services import dashboard_service

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get(
    "/summary",
    response_model=DashboardSummaryOut,
)
def get_dashboard_summary(
    target_date: date | None = Query(None, description="Optional target date for viewing past/future day schedule"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Composes a live operational dashboard for the authenticated faculty member.
    """
    return dashboard_service.get_faculty_dashboard_summary(
        db=db,
        faculty_user=current_user,
        target_date=target_date,
    )
