from datetime import datetime
from pydantic import BaseModel, ConfigDict


class AdminDashboardStatsOut(BaseModel):
    total_faculty: int
    active_faculty: int
    allocated_courses_count: int
    attainment_completed_percent: int
    pending_governance_count: int
    department_counts: dict[str, int]


class SubjectAllocationOut(BaseModel):
    id: str
    course_code: str
    course_name: str
    department: str
    year: str
    semester: str
    credits: int
    faculty_id: str
    faculty_name: str
    co_faculty_name: str = "None"
    attainment_status: str = "In Progress"


class SubjectAllocationCreate(BaseModel):
    course_code: str
    course_name: str
    department: str
    year: str
    semester: str
    credits: int = 3
    faculty_id: str
    co_faculty_name: str = "None"


class SubjectReassignRequest(BaseModel):
    faculty_id: str
    co_faculty_name: str | None = "None"


class GovernanceRequestOut(BaseModel):
    id: str
    faculty_id: str
    faculty_name: str
    type: str  # "CAS" | "FDP" | "Leave" | "Publication" | "Certification"
    title: str
    status: str  # "PENDING" | "APPROVED" | "REJECTED"
    submitted_at: datetime
    document_url: str | None = None


class GovernanceActionRequest(BaseModel):
    action: str  # "APPROVE" | "REJECT"
    remarks: str | None = None
