from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.models.academic import RoomType


# ---------------------------------------------------------------------------
# CRUD schemas for the entities an admin sets up BEFORE generating anything
# ---------------------------------------------------------------------------

class DivisionCreate(BaseModel):
    name: str
    year: int = Field(ge=1, le=4, default=1)
    division_code: str = "A"
    semester: str | None = None
    strength: int = 60


class DivisionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    year: int
    division_code: str
    semester: str | None
    strength: int


class SubjectCreate(BaseModel):
    name: str
    code: str | None = None
    weekly_lectures: int = 0
    is_lab: bool = False
    lab_sessions_per_week: int = 0
    lab_block_size: int = 2


class SubjectOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    code: str | None
    weekly_lectures: int
    is_lab: bool
    lab_sessions_per_week: int
    lab_block_size: int


class RoomCreate(BaseModel):
    name: str
    type: RoomType = RoomType.LECTURE
    capacity: int = 60


class RoomOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    type: RoomType
    capacity: int


class TeachingAssignmentCreate(BaseModel):
    faculty_id: str
    subject_id: str
    division_id: str


class TeachingAssignmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    faculty_id: str
    subject_id: str
    division_id: str


class FacultyUnavailabilityCreate(BaseModel):
    faculty_id: str
    day: int = Field(ge=0, le=6)
    slot: int = Field(ge=0)


# ---------------------------------------------------------------------------
# Schedule Configuration schemas
# ---------------------------------------------------------------------------

class ScheduleConfigCreate(BaseModel):
    working_days: int = Field(ge=1, le=6, default=6)
    day_names: list[str] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    periods_per_day: int = Field(ge=1, le=20, default=8)
    period_duration_minutes: int = Field(ge=15, le=180, default=60)
    lecture_duration_minutes: int = Field(ge=15, le=180, default=60)
    lab_duration_minutes: int = Field(ge=15, le=240, default=120)
    tutorial_duration_minutes: int = Field(ge=15, le=180, default=60)
    start_time: str = "09:00"
    break_slots: list[int] = []
    break_labels: dict[str, str] = {}
    max_lectures_per_day_per_faculty: int | None = None
    college_name: str | None = None
    department_name: str | None = None
    academic_year: str | None = None
    semester: str | None = None
    hod_name: str | None = None
    time_limit_seconds: int = Field(ge=5, le=300, default=30)


class ScheduleConfigOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    working_days: int
    day_names: list[str]
    periods_per_day: int
    period_duration_minutes: int
    lecture_duration_minutes: int
    lab_duration_minutes: int
    tutorial_duration_minutes: int
    start_time: str
    break_slots: list[int]
    break_labels: dict[str, str]
    max_lectures_per_day_per_faculty: int | None
    college_name: str | None
    department_name: str | None
    academic_year: str | None
    semester: str | None
    hod_name: str | None
    time_limit_seconds: int


# ---------------------------------------------------------------------------
# Dynamic constraint schemas
# ---------------------------------------------------------------------------

class ConstraintCreate(BaseModel):
    """
    Generic constraint envelope.  `constraint_type` tells the solver what to
    build; `payload` carries the type-specific data.  `priority` decides
    whether this is a hard constraint (solver must satisfy) or soft
    (objective penalty if violated).

    Examples
    --------
    Hard faculty unavailability:
        {"constraint_type": "faculty_unavailability", "priority": "hard",
         "payload": {"faculty_id": "...", "day": 0, "slot": 2}}

    Soft avoid-first-period:
        {"constraint_type": "avoid_first_period", "priority": "soft",
         "payload": {"faculty_id": "..."}}

    Soft preferred room:
        {"constraint_type": "preferred_room", "priority": "soft",
         "payload": {"subject_id": "...", "room_id": "..."}}
    """
    constraint_type: str
    priority: str = Field(pattern="^(hard|soft)$", default="hard")
    payload: dict[str, Any] = {}
    description: str = ""
    is_active: bool = True


class ConstraintOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    constraint_type: str
    priority: str
    payload: dict[str, Any]
    description: str
    is_active: bool
    created_at: datetime | None = None


# ---------------------------------------------------------------------------
# Solver input/output contract
#
# WHY THIS IS SEPARATE FROM THE DB MODELS ABOVE: the solver
# (app/services/timetable_solver.py) is a pure, framework-agnostic function
# — it doesn't know about SQLAlchemy, FastAPI, or the database. The route
# handler (app/api/routes/timetable.py) is the ONLY thing that translates
# DB rows into these schemas, calls the solver, and translates the result
# back into DB rows. This means the solver itself can be unit tested with
# plain Python objects, no database required.
# ---------------------------------------------------------------------------

class SolverDivision(BaseModel):
    id: str
    name: str
    division_code: str = "A"
    year: int = 1
    strength: int


class SolverSubject(BaseModel):
    id: str
    name: str
    weekly_lectures: int
    is_lab: bool
    lab_sessions_per_week: int
    lab_block_size: int


class SolverRoom(BaseModel):
    id: str
    name: str
    type: RoomType
    capacity: int


class SolverAssignment(BaseModel):
    faculty_id: str
    subject_id: str
    division_id: str


class SolverUnavailability(BaseModel):
    faculty_id: str
    day: int
    slot: int


class SolverSoftConstraint(BaseModel):
    """A soft preference the solver will try to optimise for."""
    type: str          # e.g. "avoid_first_period", "prefer_morning"
    payload: dict[str, Any] = {}


class SolverInstitutionalCourse(BaseModel):
    course_name: str
    course_code: str | None = None
    year: int
    divisions: list[str]
    day: int
    start_slot: int
    duration_slots: int
    faculty_id: str | None = None
    room_id: str | None = None


class SolverSharedCourse(BaseModel):
    id: str
    course_name: str
    course_code: str | None = None
    year: int
    divisions: list[str]
    faculty_id: str
    room_id: str | None = None
    duration_slots: int
    weekly_sessions: int
    session_type: str


class TimetableGenerationRequest(BaseModel):
    """Everything the solver needs, and nothing it doesn't."""
    divisions: list[SolverDivision]
    subjects: list[SolverSubject]
    rooms: list[SolverRoom]
    assignments: list[SolverAssignment]
    unavailability: list[SolverUnavailability] = []
    institutional_courses: list[SolverInstitutionalCourse] = []
    shared_courses: list[SolverSharedCourse] = []
    working_days: int = 6          # Mon-Sat
    periods_per_day: int = 8
    break_slots: list[int] = []    # period indices with NO classes (breaks/lunch)
    max_lectures_per_day_per_faculty: int | None = None
    time_limit_seconds: int = 30
    soft_constraints: list[SolverSoftConstraint] = []


class TimetableEntryResult(BaseModel):
    division_id: str
    subject_id: str
    faculty_id: str
    room_id: str
    day: int
    slot: int
    is_lab_block: bool = False


class ConflictDetail(BaseModel):
    """A structured conflict found before or after solving."""
    type: str            # "no_compatible_room" | "faculty_overloaded" | etc.
    subject: str | None = None
    division: str | None = None
    faculty: str | None = None
    room: str | None = None
    details: str = ""


class TimetableGenerationResult(BaseModel):
    status: str          # "OPTIMAL" | "FEASIBLE" | "INFEASIBLE" | "UNKNOWN"
    entries: list[TimetableEntryResult]
    solve_time_seconds: float
    objective_score: float | None = None
    validation_passed: bool = True
    conflicts: list[ConflictDetail] = []
    suggestions: list[str] = []
    message: str | None = None
    solver_log: str | None = None


# ---------------------------------------------------------------------------
# Generation history schemas
# ---------------------------------------------------------------------------

class GenerationRunOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    generated_at: datetime | None
    status: str
    solve_time_seconds: float | None
    total_entries: int
    objective_score: float | None
    validation_passed: bool | None
    conflicts: list[dict] | None
    suggestions: list[str] | None


# ---------------------------------------------------------------------------
# Pre-validation response
# ---------------------------------------------------------------------------

class ValidationResponse(BaseModel):
    valid: bool
    conflicts: list[ConflictDetail] = []
    suggestions: list[str] = []
    summary: str = ""


# ---------------------------------------------------------------------------
# Read schemas — what Android/Web actually display (joined with names, not
# just raw foreign-key ids, since that's what a screen needs to show)
# ---------------------------------------------------------------------------

class TimetableEntryOut(BaseModel):
    id: str
    batch_id: str
    day: int
    slot: int
    is_lab_block: bool
    division_name: str
    division_year: int
    division_code: str
    subject_name: str
    faculty_name: str
    room_name: str
    generated_at: datetime | None


class CollegeInfo(BaseModel):
    college_name: str


# ---------------------------------------------------------------------------
# Institutional and Shared Course schemas
# ---------------------------------------------------------------------------

class InstitutionalCourseCreate(BaseModel):
    course_name: str
    course_code: str | None = None
    year: int = Field(ge=1, le=4, default=1)
    divisions: list[str] = []
    day: int = Field(ge=0, le=6)
    start_slot: int = Field(ge=0)
    duration_slots: int = Field(ge=1, default=1)
    faculty_id: str | None = None
    room_id: str | None = None


class InstitutionalCourseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    course_name: str
    course_code: str | None
    year: int
    divisions: list[str]
    day: int
    start_slot: int
    duration_slots: int
    faculty_id: str | None
    room_id: str | None


class SharedCourseCreate(BaseModel):
    course_name: str
    course_code: str | None = None
    year: int = Field(ge=1, le=4, default=1)
    divisions: list[str] = []
    faculty_id: str
    room_id: str | None = None
    duration_slots: int = Field(ge=1, default=1)
    weekly_sessions: int = Field(ge=1, default=1)
    session_type: str = "lecture"  # "lecture" or "lab"


class SharedCourseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    course_name: str
    course_code: str | None
    year: int
    divisions: list[str]
    faculty_id: str
    room_id: str | None
    duration_slots: int
    weekly_sessions: int
    session_type: str


# ---------------------------------------------------------------------------
# Voice schemas
# ---------------------------------------------------------------------------

class TtsRequest(BaseModel):
    text: str
    role: str = "assistant"   # "assistant" | "error" | "success" | "conflict"


class ParseConstraintRequest(BaseModel):
    speech_text: str


class ParseConstraintResponse(BaseModel):
    constraint: ConstraintCreate | None = None
    confirmation_message: str
    raw_text: str
    parsed_successfully: bool
