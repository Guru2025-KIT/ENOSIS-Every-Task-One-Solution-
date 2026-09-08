from datetime import date, datetime
from enum import Enum
from pydantic import BaseModel, ConfigDict


class AttendanceStatus(str, Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    LATE = "LATE"


class StudentAttendanceItemIn(BaseModel):
    enrollment_id: int
    status: AttendanceStatus = AttendanceStatus.PRESENT
    remarks: str | None = None


class StudentAttendanceItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    enrollment_id: int
    student_id: str
    student_name: str
    roll_number: str | None = None
    status: AttendanceStatus
    remarks: str | None = None


class AttendanceSessionSubmitIn(BaseModel):
    timetable_entry_id: str
    session_date: date
    slot_number: int
    topic_taught: str | None = None
    notes: str | None = None
    records: list[StudentAttendanceItemIn]


class AttendanceSessionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: int | None = None
    timetable_entry_id: str
    class_id: int
    subject_id: str
    subject_name: str
    subject_code: str | None = None
    division_name: str
    year_level: int | None = None
    session_date: date
    slot_number: int
    topic_taught: str | None = None
    notes: str | None = None
    total_enrolled: int
    present_count: int
    absent_count: int
    late_count: int
    attendance_percentage: float
    is_recorded: bool = False
    records: list[StudentAttendanceItemOut]
    recorded_at: datetime | None = None


class StudentAttendanceSummaryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    enrollment_id: int
    student_id: str
    student_name: str
    class_id: int
    subject_id: str
    subject_name: str
    total_sessions: int
    attended_sessions: int
    absent_sessions: int
    late_sessions: int
    attendance_percentage: float
