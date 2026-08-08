import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_timetable_manager
from app.core.config import settings
from app.db.base import get_db
from app.models.academic import Division, Subject, Room, TeachingAssignment, FacultyUnavailability
from app.models.timetable import TimetableEntry
from app.models.user import User
from app.schemas.timetable import (
    DivisionCreate, DivisionOut,
    SubjectCreate, SubjectOut,
    RoomCreate, RoomOut,
    TeachingAssignmentCreate, TeachingAssignmentOut,
    FacultyUnavailabilityCreate,
    TimetableGenerationRequest, SolverDivision, SolverSubject, SolverRoom,
    SolverAssignment, SolverUnavailability,
    TimetableEntryOut, CollegeInfo,
)
from app.services.timetable_solver import generate_timetable

router = APIRouter(prefix="/timetable", tags=["timetable"])


@router.get("/college-info", response_model=CollegeInfo)
def college_info():
    """
    Public (no auth) — the app's splash/login/timetable screens display
    the institution's name. Kept as simple server-side config for now
    (COLLEGE_NAME in .env) rather than a full "Institution Settings"
    admin screen, which would be over-engineering for a single string
    at this stage.
    """
    return CollegeInfo(college_name=settings.COLLEGE_NAME)


# ---------------------------------------------------------------------------
# Setup data (admin-only to create; any logged-in user can list, since
# faculty may want to see e.g. what rooms/subjects exist)
# ---------------------------------------------------------------------------

@router.post("/divisions", response_model=DivisionOut, status_code=status.HTTP_201_CREATED)
def create_division(payload: DivisionCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    division = Division(**payload.model_dump())
    db.add(division)
    db.commit()
    db.refresh(division)
    return division


@router.get("/divisions", response_model=list[DivisionOut])
def list_divisions(
    year: int | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """List all divisions, or filter to one year (1-4) for the UI's Year picker."""
    query = db.query(Division)
    if year is not None:
        query = query.filter(Division.year == year)
    return query.order_by(Division.year, Division.division_code).all()


@router.post("/subjects", response_model=SubjectOut, status_code=status.HTTP_201_CREATED)
def create_subject(payload: SubjectCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    subject = Subject(**payload.model_dump())
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return subject


@router.get("/subjects", response_model=list[SubjectOut])
def list_subjects(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(Subject).all()


@router.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room(payload: RoomCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    room = Room(**payload.model_dump())
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


@router.get("/rooms", response_model=list[RoomOut])
def list_rooms(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(Room).all()


@router.post("/assignments", response_model=TeachingAssignmentOut, status_code=status.HTTP_201_CREATED)
def create_assignment(payload: TeachingAssignmentCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    # Basic referential sanity checks — give a clear 404 instead of a raw DB error
    for model, field_id, label in [
        (User, payload.faculty_id, "faculty"),
        (Subject, payload.subject_id, "subject"),
        (Division, payload.division_id, "division"),
    ]:
        if db.query(model).filter(model.id == field_id).first() is None:
            raise HTTPException(status_code=404, detail=f"No {label} found with id {field_id}")

    assignment = TeachingAssignment(**payload.model_dump())
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    return assignment


@router.get("/assignments", response_model=list[TeachingAssignmentOut])
def list_assignments(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(TeachingAssignment).all()


@router.post("/unavailability", status_code=status.HTTP_201_CREATED)
def create_unavailability(payload: FacultyUnavailabilityCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    entry = FacultyUnavailability(**payload.model_dump())
    db.add(entry)
    db.commit()
    return {"status": "created"}


# ---------------------------------------------------------------------------
# Generation — admin-only. This is the "Web workflow" per the project plan;
# Android never calls this, it only calls the read endpoints below.
# ---------------------------------------------------------------------------

@router.post("/generate")
def generate(
    time_limit_seconds: int = 20,
    max_lectures_per_day_per_faculty: int | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager),
):
    """
    Loads all current divisions/subjects/rooms/assignments/unavailability
    from the database, runs the CP-SAT solver (see
    app/services/timetable_solver.py), and — if a valid timetable was
    found — replaces any previously generated entries with the new ones.

    Returns a summary, not the full entry list — use GET /timetable/division/{id}
    or GET /timetable/me to actually view the generated schedule.
    """
    divisions = db.query(Division).all()
    subjects = db.query(Subject).all()
    rooms = db.query(Room).all()
    assignments = db.query(TeachingAssignment).all()
    unavailability = db.query(FacultyUnavailability).all()

    request = TimetableGenerationRequest(
        divisions=[SolverDivision(id=d.id, name=d.name, strength=d.strength) for d in divisions],
        subjects=[
            SolverSubject(
                id=s.id, name=s.name, weekly_lectures=s.weekly_lectures,
                is_lab=s.is_lab, lab_sessions_per_week=s.lab_sessions_per_week,
                lab_block_size=s.lab_block_size,
            ) for s in subjects
        ],
        rooms=[SolverRoom(id=r.id, name=r.name, type=r.type, capacity=r.capacity) for r in rooms],
        assignments=[
            SolverAssignment(faculty_id=a.faculty_id, subject_id=a.subject_id, division_id=a.division_id)
            for a in assignments
        ],
        unavailability=[
            SolverUnavailability(faculty_id=u.faculty_id, day=u.day, slot=u.slot)
            for u in unavailability
        ],
        time_limit_seconds=time_limit_seconds,
        max_lectures_per_day_per_faculty=max_lectures_per_day_per_faculty,
    )

    result = generate_timetable(request)

    if result.status not in ("OPTIMAL", "FEASIBLE"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"status": result.status, "message": result.message},
        )

    # Replace any previous generation with this new one.
    db.query(TimetableEntry).delete()

    batch_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    for entry in result.entries:
        db.add(TimetableEntry(
            batch_id=batch_id,
            division_id=entry.division_id,
            subject_id=entry.subject_id,
            faculty_id=entry.faculty_id,
            room_id=entry.room_id,
            day=entry.day,
            slot=entry.slot,
            is_lab_block=entry.is_lab_block,
            generated_at=now,
        ))
    db.commit()

    return {
        "batch_id": batch_id,
        "status": result.status,
        "total_entries": len(result.entries),
        "solve_time_seconds": result.solve_time_seconds,
    }


# ---------------------------------------------------------------------------
# Read-only viewing — this is what Android actually calls. Faculty view
# their own timetable or a division's timetable; nobody on mobile ever
# triggers generation.
# ---------------------------------------------------------------------------

def _to_entry_out(entry: TimetableEntry) -> TimetableEntryOut:
    return TimetableEntryOut(
        id=entry.id,
        batch_id=entry.batch_id,
        day=entry.day,
        slot=entry.slot,
        is_lab_block=entry.is_lab_block,
        division_name=entry.division.name,
        division_year=entry.division.year,
        division_code=entry.division.division_code,
        subject_name=entry.subject.name,
        faculty_name=entry.faculty.full_name,
        room_name=entry.room.name,
        generated_at=entry.generated_at,
    )


@router.get("/me", response_model=list[TimetableEntryOut])
def my_timetable(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """The logged-in faculty member's own generated timetable."""
    entries = db.query(TimetableEntry).filter(TimetableEntry.faculty_id == current_user.id).all()
    return [_to_entry_out(e) for e in entries]


@router.get("/division/{division_id}", response_model=list[TimetableEntryOut])
def division_timetable(division_id: str, db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    """A whole division's generated timetable (e.g. for a class rep / admin to view)."""
    division = db.query(Division).filter(Division.id == division_id).first()
    if division is None:
        raise HTTPException(status_code=404, detail="Division not found")

    entries = db.query(TimetableEntry).filter(TimetableEntry.division_id == division_id).all()
    return [_to_entry_out(e) for e in entries]


@router.get("/year/{year}", response_model=list[TimetableEntryOut])
def year_timetable(year: int, db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    """
    Every division's generated timetable for a given year (1-4) — e.g. a
    department head viewing all of Year 2's divisions (A, B, C, ...) at once.
    """
    division_ids = [d.id for d in db.query(Division).filter(Division.year == year).all()]
    if not division_ids:
        return []

    entries = db.query(TimetableEntry).filter(TimetableEntry.division_id.in_(division_ids)).all()
    return [_to_entry_out(e) for e in entries]
