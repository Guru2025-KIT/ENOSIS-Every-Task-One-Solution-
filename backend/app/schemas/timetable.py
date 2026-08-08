from datetime import datetime

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


class TimetableGenerationRequest(BaseModel):
    """Everything the solver needs, and nothing it doesn't."""
    divisions: list[SolverDivision]
    subjects: list[SolverSubject]
    rooms: list[SolverRoom]
    assignments: list[SolverAssignment]
    unavailability: list[SolverUnavailability] = []
    working_days: int = 6          # Mon-Sat
    periods_per_day: int = 6
    max_lectures_per_day_per_faculty: int | None = None
    time_limit_seconds: int = 20


class TimetableEntryResult(BaseModel):
    division_id: str
    subject_id: str
    faculty_id: str
    room_id: str
    day: int
    slot: int
    is_lab_block: bool = False


class TimetableGenerationResult(BaseModel):
    status: str  # "OPTIMAL" | "FEASIBLE" | "INFEASIBLE" | "UNKNOWN"
    entries: list[TimetableEntryResult]
    solve_time_seconds: float
    message: str | None = None


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
