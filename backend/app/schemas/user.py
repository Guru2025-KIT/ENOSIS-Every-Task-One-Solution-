from datetime import datetime

from pydantic import BaseModel, EmailStr, ConfigDict

from app.models.user import UserRole


class UserCreate(BaseModel):
    """Shape of the JSON body expected by POST /auth/signup."""
    email: EmailStr
    password: str
    full_name: str
    employee_id: str | None = None
    department: str | None = None
    designation: str | None = None
    phone: str | None = None


class UserOut(BaseModel):
    """
    Shape of a User as returned to clients. Deliberately does NOT include
    hashed_password — Pydantic only serializes fields listed here, so the
    password hash can never leak out through an API response by accident.
    """
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    full_name: str
    employee_id: str | None = None
    department: str | None = None
    designation: str | None = None
    phone: str | None = None
    is_active: bool = True
    role: UserRole
    can_manage_timetable: bool
    created_at: datetime


class UserUpdate(BaseModel):
    """All fields optional — self-service profile editing via PATCH /auth/me."""
    full_name: str | None = None
    department: str | None = None
    employee_id: str | None = None
    designation: str | None = None
    phone: str | None = None


class FacultyCreate(BaseModel):
    full_name: str
    email: EmailStr
    employee_id: str
    department: str
    designation: str | None = "Assistant Professor"
    phone: str | None = None
    password: str | None = None  # If omitted, a default secure temporary password is assigned


class FacultyUpdate(BaseModel):
    full_name: str | None = None
    email: EmailStr | None = None
    employee_id: str | None = None
    department: str | None = None
    designation: str | None = None
    phone: str | None = None
    is_active: bool | None = None
    can_manage_timetable: bool | None = None


class FacultyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    email: str
    employee_id: str | None = None
    department: str | None = None
    designation: str | None = None
    phone: str | None = None
    is_active: bool = True
    can_manage_timetable: bool = False
    assigned_subject_codes: list[str] = []
    created_at: datetime


class FacultyImportRow(BaseModel):
    row_number: int
    full_name: str
    email: str
    employee_id: str
    department: str
    designation: str = "Assistant Professor"
    phone: str | None = None
    error: str | None = None


class FacultyValidationResult(BaseModel):
    total_rows: int
    valid_count: int
    invalid_count: int
    duplicate_count: int
    missing_fields_count: int
    valid_records: list[FacultyImportRow] = []
    invalid_records: list[FacultyImportRow] = []
    duplicate_records: list[FacultyImportRow] = []
    missing_records: list[FacultyImportRow] = []
    valid_rows: list[FacultyImportRow] = []
    invalid_rows: list[FacultyImportRow] = []
    duplicate_rows: list[FacultyImportRow] = []
    missing_fields_rows: list[FacultyImportRow] = []


class FacultyImportPayload(BaseModel):
    records: list[FacultyImportRow] = []
    rows: list[FacultyImportRow] = []


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class Token(BaseModel):
    """Shape returned by POST /auth/login."""
    access_token: str
    token_type: str = "bearer"
