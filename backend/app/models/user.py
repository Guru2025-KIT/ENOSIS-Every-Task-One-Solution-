import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, Enum, Boolean

from app.db.base import Base


class UserRole(str, enum.Enum):
    FACULTY = "faculty"
    ADMIN = "admin"


class User(Base):
    """
    The ONE table every other ENOSIS module will eventually reference —
    attendance records, career achievements, to-do items, timetable
    assignments, etc. will all have a `faculty_id` foreign key pointing
    back to this table. This is exactly why Auth had to come first.
    """
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    employee_id = Column(String(50), unique=True, nullable=True)
    department = Column(String(100), nullable=True)
    role = Column(Enum(UserRole), default=UserRole.FACULTY, nullable=False)

    # Lets an admin delegate "can generate the timetable" to a specific
    # faculty member (e.g. a department's timetable coordinator) without
    # making them a full admin. See app/api/deps.py's require_timetable_manager.
    can_manage_timetable = Column(Boolean, nullable=False, default=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
