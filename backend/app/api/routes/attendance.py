from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.user import User, UserRole
from app.schemas.attendance import (
    AttendanceSessionOut,
    AttendanceSessionSubmitIn,
    StudentAttendanceSummaryOut,
)
from app.services import attendance_service

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.get(
    "/session/{timetable_entry_id}/{session_date}",
    response_model=AttendanceSessionOut,
)
def get_attendance_session(
    timetable_entry_id: str,
    session_date: date,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves or initializes the student roster and attendance status for
    a scheduled timetable entry and date.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return attendance_service.get_attendance_session_for_slot(
        db=db,
        faculty_id=current_user.id,
        timetable_entry_id=timetable_entry_id,
        session_date=session_date,
        is_admin=is_admin,
    )


@router.post(
    "/session",
    response_model=AttendanceSessionOut,
)
def submit_attendance_session(
    payload: AttendanceSessionSubmitIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Idempotently submits or updates attendance records for a lecture session.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return attendance_service.submit_lecture_attendance(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


@router.get(
    "/student/{enrollment_id}",
    response_model=StudentAttendanceSummaryOut,
)
def get_student_attendance_summary(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves derived cumulative attendance percentage and stats for a student enrollment.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return attendance_service.get_student_attendance_summary(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )
