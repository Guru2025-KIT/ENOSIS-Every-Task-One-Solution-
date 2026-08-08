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
    employee_id: str | None
    department: str | None
    role: UserRole
    can_manage_timetable: bool
    created_at: datetime


class Token(BaseModel):
    """Shape returned by POST /auth/login."""
    access_token: str
    token_type: str = "bearer"
