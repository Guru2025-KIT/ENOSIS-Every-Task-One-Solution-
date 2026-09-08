from datetime import date
from pydantic import BaseModel, ConfigDict


class TodayScheduleSlotOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    timetable_entry_id: str
    slot_number: int
    time_range: str
    subject_id: str
    subject_name: str
    subject_code: str | None = None
    division_name: str
    room_name: str
    is_lab: bool = False
    class_id: int | None = None
    semester_id: int | None = None
    status: str  # 'COMPLETED', 'IN_PROGRESS', 'UPCOMING'
    attendance_recorded: bool = False
    session_id: int | None = None


class DashboardSummaryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    faculty_id: str
    faculty_name: str
    faculty_email: str
    department_name: str | None = None
    today_date: date
    day_name: str
    classes_today_count: int
    classes_completed_count: int
    classes_upcoming_count: int
    pending_tasks_count: int
    high_priority_tasks_count: int
    sli_attention_students_count: int
    sli_critical_students_count: int
    verified_achievements_count: int
    today_schedule: list[TodayScheduleSlotOut]
