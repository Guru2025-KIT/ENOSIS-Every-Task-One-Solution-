from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.db.base import get_db
from app.models.user import User
from app.schemas.admin import (
    AdminDashboardStatsOut,
    GovernanceActionRequest,
    GovernanceRequestOut,
    SubjectAllocationCreate,
    SubjectAllocationOut,
    SubjectReassignRequest,
)
from app.schemas.user import (
    FacultyCreate,
    FacultyImportPayload,
    FacultyOut,
    FacultyUpdate,
    FacultyValidationResult,
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


@router.post("/faculty", response_model=FacultyOut, status_code=status.HTTP_201_CREATED)
def create_faculty(
    payload: FacultyCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """
    Manually creates a new faculty member in Central Master Data.
    """
    return admin_service.create_single_faculty(db, payload)


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
