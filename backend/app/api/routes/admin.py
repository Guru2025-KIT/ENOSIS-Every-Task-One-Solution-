from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.db.base import get_db
from app.models.user import User
from app.schemas.admin import (
    AdminDashboardStatsOut,
    AdminProfileUpdate,
    GovernanceActionRequest,
    GovernanceRequestOut,
    SubjectAllocationCreate,
    SubjectAllocationOut,
    SubjectReassignRequest,
)
from app.schemas.user import (
    AdminEmailSettingsOut,
    AdminEmailSettingsUpdate,
    AdminResetPasswordRequest,
    FacultyCreate,
    FacultyImportPayload,
    FacultyOut,
    FacultyUpdate,
    FacultyValidationResult,
    UserOut,
)
from app.services import admin_service

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/dashboard-stats", response_model=AdminDashboardStatsOut)
def get_dashboard_stats(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Returns real-time aggregated metrics directly computed from DB tables.
    """
    return admin_service.get_admin_dashboard_stats(db)


@router.get("/faculty", response_model=list[FacultyOut])
def get_faculty_list(
    department: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Lists all faculty members with live teaching assignment codes.
    """
    return admin_service.list_faculty(db, department=department)


@router.post("/faculty", status_code=status.HTTP_201_CREATED)
def create_faculty(
    payload: FacultyCreate,
    send_email: bool = True,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Creates a new faculty member and optionally sends onboarding credentials
    via email. Returns the created faculty profile plus the temp password
    so the admin can share it manually if email delivery fails.
    """
    try:
        faculty_out, temp_password, email_sent = admin_service.create_single_faculty_with_email(db, payload)
        return {
            "faculty": faculty_out.model_dump(),
            "temp_password": temp_password,
            "email_sent": email_sent,
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/faculty/{faculty_id}", response_model=FacultyOut)
def update_faculty(
    faculty_id: str,
    payload: FacultyUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Updates profile or active status for a faculty member.
    """
    return admin_service.update_single_faculty(db, faculty_id, payload)


@router.delete("/faculty/{faculty_id}")
def delete_faculty(
    faculty_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Soft-deactivates or deletes a faculty member.
    """
    return admin_service.delete_single_faculty(db, faculty_id)


# ─── Password Reset ─────────────────────────────────────────────────────────

@router.post("/faculty/{faculty_id}/reset-password")
def reset_faculty_password(
    faculty_id: str,
    payload: AdminResetPasswordRequest | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Admin-triggered password reset for a faculty member. Generates a new
    temporary password, updates the database, and optionally sends it
    via email. The temp password is always returned in the response so
    the admin can copy it from the UI.
    """
    send_flag = payload.send_email if payload else True
    try:
        return admin_service.reset_faculty_password(db, faculty_id, send_flag)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/faculty/{faculty_id}/send-onboarding")
def send_onboarding_email(
    faculty_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Re-sends the onboarding welcome email. Generates a fresh temp password,
    updates the database, and dispatches the welcome email.
    """
    try:
        result = admin_service.reset_faculty_password(db, faculty_id, send_email_flag=True)
        # Also send the onboarding-style email
        from app.services.email_service import send_onboarding_email as _send
        _send(result["faculty_name"], result["faculty_email"], result["temp_password"])
        result["status"] = "onboarding_resent"
        return result
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ─── Spreadsheet Upload & Import ─────────────────────────────────────────────

@router.post("/faculty/validate-upload", response_model=FacultyValidationResult)
async def validate_faculty_upload(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Pre-import dry-run validation of an uploaded Excel or CSV file.
    Categorizes rows into: Valid, Invalid, Duplicate, and Missing fields.
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="Uploaded file has no filename.")
    content = await file.read()
    return admin_service.validate_faculty_spreadsheet(db, file.filename, content)


@router.post("/faculty/import")
def import_faculty(
    payload: FacultyImportPayload,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Executes atomic database insertion of verified valid rows from pre-import validation.
    """
    return admin_service.bulk_import_faculty(db, payload)


# ─── Subject Allocations ─────────────────────────────────────────────────────

@router.get("/allocations", response_model=list[SubjectAllocationOut])
def get_subject_allocations(
    department: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Lists subject allocations linked to faculty master data.
    """
    return admin_service.list_subject_allocations(db, department=department)


@router.post("/allocations", response_model=SubjectAllocationOut, status_code=status.HTTP_201_CREATED)
def create_subject_allocation(
    payload: SubjectAllocationCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Creates a new subject allocation assigned to a faculty member.
    """
    return admin_service.create_subject_allocation(db, payload)


@router.post("/allocations/{allocation_id}/reassign", response_model=SubjectAllocationOut)
def reassign_subject_allocation(
    allocation_id: str,
    payload: SubjectReassignRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Reassigns a subject allocation to a different faculty member.
    """
    return admin_service.reassign_subject_allocation(db, allocation_id, payload)


# ─── Governance & Approval Requests ──────────────────────────────────────────

@router.get("/governance-requests", response_model=list[GovernanceRequestOut])
def get_governance_requests(
    status_filter: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Lists all governance and CAS advancement approval requests.
    """
    return admin_service.list_governance_requests(db, status_filter=status_filter)


@router.post("/governance-requests/{request_id}/action", response_model=GovernanceRequestOut)
def process_governance_action(
    request_id: str,
    payload: GovernanceActionRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Approves or rejects a governance/advancement request.
    """
    return admin_service.process_governance_action(db, request_id, payload)


# ─── Admin Email Settings ────────────────────────────────────────────────────

@router.get("/settings/email", response_model=AdminEmailSettingsOut)
def get_email_settings(
    _: User = Depends(require_admin),
):
    """
    Returns current admin email / SMTP configuration (passwords masked).
    """
    return admin_service.get_email_settings()


@router.put("/settings/email", response_model=AdminEmailSettingsOut)
def update_email_settings(
    payload: AdminEmailSettingsUpdate,
    _: User = Depends(require_admin),
):
    """
    Updates the admin email / SMTP settings at runtime. This is an in-memory
    update — for persistence, update the .env file as well.
    """
    return admin_service.update_email_settings(payload)


# ─── Faculty Performance & Profile (Admin View) ──────────────────────────────

@router.get("/faculty/{faculty_id}/performance")
def get_faculty_performance(
    faculty_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Returns comprehensive profile and performance metrics for a specific faculty member:
    - User details (designation, department, emp ID, contact)
    - Course allocations & weekly lecture load
    - Career advancement achievements & publications count
    - Student Learning Intelligence (SLI) student counts & feedback
    """
    try:
        return admin_service.get_faculty_performance(db, faculty_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ─── Admin Profile Management ────────────────────────────────────────────────

@router.put("/profile", response_model=UserOut)
def update_admin_profile(
    payload: AdminProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """
    Updates the Admin username (full_name) and Admin email.
    """
    try:
        return admin_service.update_admin_profile(db, current_user, payload)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


