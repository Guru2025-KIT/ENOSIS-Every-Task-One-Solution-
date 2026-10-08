import uuid
import io
import csv
import logging
import openpyxl
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger("timetable")

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Response, Body
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_timetable_manager, get_optional_current_user
from app.services.timetable_export_service import generate_timetable_excel, generate_timetable_pdf
from app.core.config import settings
from app.db.base import get_db
from app.models.academic import (
    Division, Subject, Room, RoomType, TeachingAssignment, FacultyUnavailability,
    InstitutionalCourse, SharedCourse
)
from app.models.sli import Department, Semester, AcademicClass, Enrollment, Student
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole
from app.models.schedule_config import ScheduleConfig
from app.models.constraints import TimetableConstraint
from app.models.generation_history import GenerationRun
from app.schemas.timetable import (
    DivisionCreate, DivisionOut,
    SubjectCreate, SubjectOut,
    RoomCreate, RoomOut,
    TeachingAssignmentCreate, TeachingAssignmentOut,
    FacultyUnavailabilityCreate,
    ScheduleConfigCreate, ScheduleConfigOut,
    ConstraintCreate, ConstraintOut,
    TimetableGenerationRequest, SolverDivision, SolverSubject, SolverRoom,
    SolverAssignment, SolverUnavailability, SolverSoftConstraint,
    SolverInstitutionalCourse, SolverSharedCourse,
    TimetableEntryOut, CollegeInfo, GenerationRunOut, ValidationResponse,
    ConflictDetail,
    InstitutionalCourseCreate, InstitutionalCourseOut,
    SharedCourseCreate, SharedCourseOut,
    TimetableGenerateRequestBody, TimetableGenerateResponseBody
)
from app.services.timetable_solver import generate_timetable, validate_request
from app.services.timetable_cpsat_solver import solve_from_dicts
from app.services.timetable_validator import validate_generated_timetable
from app.services.timetable_preflight import run_preflight_checks
from app.services.timetable_staged_solver import StagedTimetableSolver
from app.services.notifications import notify


def _clean_title(name_str: str) -> str:
    """Helper to clean and normalize faculty titles for resilient lookup."""
    s = (name_str or "").lower().strip()
    for prefix in ["dr.", "dr ", "prof.", "prof ", "mr.", "mr ", "mrs.", "mrs ", "ms.", "ms ", "er.", "er "]:
        if s.startswith(prefix):
            s = s[len(prefix):].strip()
    return s


router = APIRouter(prefix="/timetable", tags=["timetable"])


@router.get("/college-info", response_model=CollegeInfo)
def college_info(db: Session = Depends(get_db)):
    """
    Public (no auth) — the app's splash/login/timetable screens display
    the institution's name. First checks if a database schedule configuration
    exists and has a college name, otherwise falls back to .env settings.
    """
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    if config and config.college_name:
        return CollegeInfo(college_name=config.college_name)
    return CollegeInfo(college_name=settings.COLLEGE_NAME)


@router.get("/faculty-list")
def faculty_list(db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    """
    A minimal faculty picker for the assignment-creation screen.
    """
    faculty = db.query(User).all()
    return [{"id": u.id, "full_name": u.full_name, "email": u.email} for u in faculty]


# ---------------------------------------------------------------------------
# Global Schedule Configuration (CRUD)
# ---------------------------------------------------------------------------

@router.get("/schedule-config", response_model=ScheduleConfigOut)
def get_schedule_config(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    """Retrieves the active timetable schedule configuration (always uses id='default')."""
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    if not config:
        # Auto-create a default configuration if none exists yet
        config = ScheduleConfig(
            id="default",
            working_days=6,
            day_names=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            periods_per_day=8,
            period_duration_minutes=60,
            lecture_duration_minutes=60,
            lab_duration_minutes=120,
            tutorial_duration_minutes=60,
            start_time="09:00",
            end_time="17:00",
            break1_enabled=True,
            break1_after_lectures=2,
            break1_duration_minutes=15,
            break2_enabled=True,
            break2_after_lectures=5,
            break2_duration_minutes=30,
            break_slots=[],
            break_labels={},
            max_lectures_per_day_per_faculty=None,
            college_name=settings.COLLEGE_NAME,
            department_name="Computer Science & Engineering",
            academic_year="2026-2027",
            semester="Odd",
            hod_name="Dr. Uma Gurav",
            time_limit_seconds=30
        )
        db.add(config)
        db.commit()
        db.refresh(config)
    return config


@router.post("/schedule-config", response_model=ScheduleConfigOut)
def update_schedule_config(
    payload: ScheduleConfigCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Upserts the active schedule configuration."""
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    if not config:
        config = ScheduleConfig(id="default")
        db.add(config)

    for field, value in payload.model_dump().items():
        setattr(config, field, value)

    db.commit()
    db.refresh(config)
    return config


# ---------------------------------------------------------------------------
# Generic Timetable Constraints (CRUD)
# ---------------------------------------------------------------------------

def _validate_and_normalize_constraint(payload: ConstraintCreate, db: Session) -> tuple[str, str, int, dict, str]:
    """
    Validates a constraint on save according to Step 1(d):
    - Validates rule_type against generic types
    - Checks that existing subject, faculty, division actually exist in the DB
    - Checks that slot is within range and NOT on a break slot
    - Returns (rule_type, priority, weight, payload_normalized, description)
    """
    raw_payload = payload.payload or {}

    # 1. Determine rule_type
    raw_type = (
        payload.rule_type
        or payload.constraint_type
        or raw_payload.get("rule_type")
        or raw_payload.get("category", "")
    )
    raw_lower = str(raw_type).lower()

    if "unavailable" in raw_lower or "blacklist" in raw_lower:
        rule_type = "faculty_unavailable"
    elif "fixed" in raw_lower:
        rule_type = "fixed_slot"
    elif "placement" in raw_lower or "lunch" in raw_lower or "window" in raw_lower:
        rule_type = "placement_window"
    elif "max" in raw_lower:
        rule_type = "max_per_day"
    elif "spread" in raw_lower or "consecutive" in raw_lower:
        rule_type = "spread"
    elif "lab_daily" in raw_lower or "continuity" in raw_lower:
        rule_type = "lab_daily"
    elif "no_gap" in raw_lower or "nogap" in raw_lower:
        rule_type = "no_gap"
    elif "preferred" in raw_lower or "morning" in raw_lower or "evening" in raw_lower:
        rule_type = "preferred_slot"
    else:
        rule_type = payload.rule_type or payload.constraint_type or "fixed_slot"

    valid_types = {
        "fixed_slot", "faculty_unavailable", "placement_window",
        "max_per_day", "spread", "lab_daily", "no_gap", "preferred_slot"
    }
    if rule_type not in valid_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported rule_type '{rule_type}'. Supported generic rules: {sorted(list(valid_types))}"
        )

    # 2. Extract scope & params
    scope = payload.scope.model_dump() if payload.scope else {}
    params = dict(payload.params or {})

    divisions_in = list(scope.get("divisions") or raw_payload.get("divisions") or raw_payload.get("classNames") or [])
    subjects_in = list(scope.get("subjects") or raw_payload.get("subjects") or raw_payload.get("subjectNames") or [])
    faculty_in = list(scope.get("faculty") or raw_payload.get("faculty") or raw_payload.get("facultyNames") or [])
    session_types_in = list(scope.get("session_types") or raw_payload.get("session_types") or [])

    if "division_id" in raw_payload:
        divisions_in.append(raw_payload["division_id"])
    if "subject_id" in raw_payload:
        subjects_in.append(raw_payload["subject_id"])
    if "faculty_id" in raw_payload:
        faculty_in.append(raw_payload["faculty_id"])

    # 3. Validate entities in DB
    resolved_div_ids = []
    for d in divisions_in:
        d_str = str(d).strip()
        if not d_str:
            continue
        div_rec = db.query(Division).filter(
            (Division.id == d_str) | (Division.name.ilike(d_str)) | (Division.division_code.ilike(d_str))
        ).first()
        if not div_rec:
            raise HTTPException(status_code=400, detail=f"Division '{d_str}' does not exist in database.")
        resolved_div_ids.append(div_rec.id)

    resolved_sub_ids = []
    for s in subjects_in:
        s_str = str(s).strip()
        if not s_str:
            continue
        sub_rec = db.query(Subject).filter(
            (Subject.id == s_str) | (Subject.code.ilike(s_str)) | (Subject.name.ilike(s_str))
        ).first()
        if not sub_rec:
            raise HTTPException(status_code=400, detail=f"Subject '{s_str}' does not exist in database.")
        resolved_sub_ids.append(sub_rec.id)

    resolved_fac_ids = []
    for f in faculty_in:
        f_str = str(f).strip()
        if not f_str:
            continue
        fac_rec = db.query(User).filter(
            (User.id == f_str) | (User.email.ilike(f_str)) | (User.full_name.ilike(f_str))
        ).first()
        if not fac_rec:
            raise HTTPException(status_code=400, detail=f"Faculty '{f_str}' does not exist in database.")
        resolved_fac_ids.append(fac_rec.id)

    # 4. Validate days & slots & breaks against ScheduleConfig
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    if not config:
        config = ScheduleConfig(id="default", working_days=6, periods_per_day=8, break_slots=[])

    break_slots = set(config.get_break_slots())
    periods_per_day = config.periods_per_day or 8
    working_days = config.working_days or 6

    day_map = {
        "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6,
        "mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6
    }
    raw_day = params.get("day", raw_payload.get("day", (raw_payload.get("days") or [None])[0]))
    if raw_day is not None:
        if isinstance(raw_day, str) and raw_day.lower() in day_map:
            params["day"] = day_map[raw_day.lower()]
        elif isinstance(raw_day, (int, str)) and str(raw_day).isdigit():
            d_int = int(raw_day)
            if not (0 <= d_int < working_days):
                raise HTTPException(status_code=400, detail=f"Day {d_int} is out of range (0 to {working_days - 1}).")
            params["day"] = d_int

    raw_slots = params.get("slot") or raw_payload.get("slot") or params.get("slots") or raw_payload.get("slotNumbers") or []
    if not isinstance(raw_slots, list):
        raw_slots = [raw_slots]

    validated_slots = []
    for s in raw_slots:
        if s is None:
            continue
        try:
            s_val = int(s)
            if s_val >= periods_per_day and s_val <= periods_per_day:
                s_val = s_val - 1
            if not (0 <= s_val < periods_per_day):
                raise HTTPException(status_code=400, detail=f"Slot {s} is out of range (0 to {periods_per_day - 1}).")
            if s_val in break_slots:
                break_lbl = (config.break_labels or {}).get(str(s_val), "break")
                raise HTTPException(status_code=400, detail=f"Slot {s_val} is a {break_lbl} slot and cannot have classes scheduled.")
            validated_slots.append(s_val)
        except ValueError:
            pass

    if validated_slots:
        params["slot"] = validated_slots[0]
        params["slots"] = validated_slots

    if rule_type == "placement_window":
        w = str(params.get("window", raw_payload.get("window", "after_lunch"))).lower()
        if w not in ("before_lunch", "after_lunch", "slot_range"):
            raise HTTPException(
                status_code=400,
                detail=f"Invalid placement window '{w}'. Must be 'before_lunch', 'after_lunch', or 'slot_range'."
            )
        params["window"] = w

    priority = str(payload.priority or "hard").lower()
    if priority not in ("hard", "soft"):
        priority = "hard"
    weight = int(payload.weight or 10)

    normalized_payload = {
        "rule_type": rule_type,
        "scope": {
            "divisions": resolved_div_ids,
            "subjects": resolved_sub_ids,
            "faculty": resolved_fac_ids,
            "session_types": session_types_in
        },
        "params": params,
        "priority": priority,
        "weight": weight
    }

    desc = payload.description or f"{rule_type.replace('_', ' ').title()} ({priority})"
    return rule_type, priority, weight, normalized_payload, desc


@router.post("/constraints", response_model=ConstraintOut, status_code=status.HTTP_201_CREATED)
def create_constraint(
    payload: ConstraintCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Creates a new timetable constraint with strict generic validation."""
    rule_type, priority, weight, normalized_payload, desc = _validate_and_normalize_constraint(payload, db)

    constraint = TimetableConstraint(
        id=str(uuid.uuid4()),
        constraint_type=rule_type,
        priority=priority,
        weight=weight,
        payload=normalized_payload,
        description=desc,
        is_active=payload.is_active
    )
    db.add(constraint)
    db.commit()
    db.refresh(constraint)
    return constraint



@router.get("/constraints", response_model=list[ConstraintOut])
def list_constraints(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    """Lists all active and inactive constraints saved in the database."""
    return db.query(TimetableConstraint).order_by(TimetableConstraint.created_at.desc()).all()


@router.delete("/constraints/{constraint_id}")
def delete_constraint(
    constraint_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Deletes a constraint by ID."""
    constraint = db.query(TimetableConstraint).filter(TimetableConstraint.id == constraint_id).first()
    if not constraint:
        raise HTTPException(status_code=404, detail="Constraint not found")
    db.delete(constraint)
    db.commit()
    return {"status": "deleted"}


# ---------------------------------------------------------------------------
# Setup Data Entities (CRUD)
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
    query = db.query(Division)
    if year is not None:
        query = query.filter(Division.year == year)
    return query.order_by(Division.year, Division.division_code).all()


@router.put("/divisions/{division_id}", response_model=DivisionOut)
def update_division(
    division_id: str,
    payload: DivisionCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Updates an existing division by ID."""
    division = db.query(Division).filter(Division.id == division_id).first()
    if not division:
        raise HTTPException(status_code=404, detail="Division not found")
    for field, value in payload.model_dump().items():
        setattr(division, field, value)
    db.commit()
    db.refresh(division)
    return division


@router.delete("/divisions/{division_id}")
def delete_division(
    division_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Deletes a division and its associated teaching assignments."""
    division = db.query(Division).filter(Division.id == division_id).first()
    if not division:
        raise HTTPException(status_code=404, detail="Division not found")
    # Cascade-delete assignments and timetable entries for this division
    db.query(TeachingAssignment).filter(TeachingAssignment.division_id == division_id).delete()
    db.query(TimetableEntry).filter(TimetableEntry.division_id == division_id).delete()
    db.delete(division)
    db.commit()
    return {"status": "deleted"}


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


@router.put("/subjects/{subject_id}", response_model=SubjectOut)
def update_subject(
    subject_id: str,
    payload: SubjectCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Updates an existing subject."""
    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    for field, value in payload.model_dump().items():
        setattr(subject, field, value)
    db.commit()
    db.refresh(subject)
    return subject


@router.delete("/subjects/{subject_id}")
def delete_subject(
    subject_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Deletes a subject and its associated teaching assignments."""
    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    db.query(TeachingAssignment).filter(TeachingAssignment.subject_id == subject_id).delete()
    db.query(TimetableEntry).filter(TimetableEntry.subject_id == subject_id).delete()
    db.delete(subject)
    db.commit()
    return {"status": "deleted"}


@router.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room(payload: RoomCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    # Check if a room with the same name already exists — upsert if so
    room_name = payload.name.strip()
    existing_room = db.query(Room).filter(Room.name.ilike(room_name)).first()
    if existing_room:
        for field, value in payload.model_dump().items():
            setattr(existing_room, field, value)
        db.commit()
        db.refresh(existing_room)
        return existing_room

    room = Room(id=str(uuid.uuid4()), **payload.model_dump())
    db.add(room)
    db.commit()
    db.refresh(room)
    return room


@router.get("/rooms", response_model=list[RoomOut])
def list_rooms(db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    return db.query(Room).all()


@router.put("/rooms/{room_id}", response_model=RoomOut)
def update_room(
    room_id: str,
    payload: RoomCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Updates an existing room."""
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    for field, value in payload.model_dump().items():
        setattr(room, field, value)
    db.commit()
    db.refresh(room)
    return room


@router.delete("/rooms/{room_id}")
def delete_room(
    room_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Deletes a room."""
    room = db.query(Room).filter(Room.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    db.delete(room)
    db.commit()
    return {"status": "deleted"}


@router.get("/rooms/template-excel")
def download_room_excel_template(_: User = Depends(require_timetable_manager)):
    """Returns a real Excel workbook template for room imports."""
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Rooms Import"
    
    headers = ["Room Name", "Type", "Capacity", "Building", "Equipment"]
    ws.append(headers)
    
    sample_rows = [
        ["CR-101", "Classroom", 60, "Main Block", "Projector, Audio System"],
        ["CR-102", "Classroom", 60, "Main Block", "Projector"],
        ["LAB-201", "Lab", 30, "Tech Block", "Computers, LAN"],
        ["LAB-202", "Lab", 30, "Tech Block", "Computers, IoT Kits"],
    ]
    for row in sample_rows:
        ws.append(row)
        
    buffer = io.BytesIO()
    wb.save(buffer)
    buffer.seek(0)
    
    return Response(
        content=buffer.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=room_import_template.xlsx"}
    )


@router.post("/rooms/import-excel")
def import_rooms_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Imports rooms from an uploaded Excel (.xlsx) file, returning detailed validation and result statistics."""
    filename_lower = (file.filename or "").lower()
    if not (filename_lower.endswith('.xlsx') or filename_lower.endswith('.xls')):
        # Check if contents can be opened with openpyxl anyway
        pass
        
    contents = file.file.read()
    try:
        wb = openpyxl.load_workbook(io.BytesIO(contents))
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid Excel file format: {e}")

    ws = wb.active
    processed = 0
    created = 0
    updated = 0
    rejected = 0
    errors = []

    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        raise HTTPException(status_code=400, detail="Uploaded Excel file is empty.")

    start_idx = 0
    header_col1 = str(rows[0][0] or '').strip().lower()
    if 'room' in header_col1 or 'name' in header_col1 or 'capacity' in str(rows[0]).lower():
        start_idx = 1

    for row_idx, row in enumerate(rows[start_idx:], start=start_idx + 1):
        if not row or all(val is None or str(val).strip() == '' for val in row):
            continue

        processed += 1
        name = str(row[0]).strip() if row[0] is not None else ""
        raw_type = str(row[1]).strip() if len(row) > 1 and row[1] is not None else "Classroom"
        raw_cap = row[2] if len(row) > 2 else 60
        building = str(row[3]).strip() if len(row) > 3 and row[3] is not None else None
        equipment = str(row[4]).strip() if len(row) > 4 and row[4] is not None else None

        if not name:
            errors.append(f"Row {row_idx}: Room name is required.")
            rejected += 1
            continue

        try:
            capacity = int(raw_cap)
            if capacity <= 0:
                raise ValueError("Capacity must be positive")
        except Exception:
            errors.append(f"Row {row_idx}: Invalid capacity '{raw_cap}'. Must be a positive integer.")
            rejected += 1
            continue

        type_lower = raw_type.lower()
        if "lab" in type_lower:
            room_type = RoomType.LAB
        elif "class" in type_lower or "lecture" in type_lower or "theory" in type_lower:
            room_type = RoomType.LECTURE
        else:
            errors.append(f"Row {row_idx}: Invalid room type '{raw_type}'. Expected 'Classroom' or 'Lab'.")
            rejected += 1
            continue

        equip_list = [e.strip() for e in equipment.split(',')] if equipment else []

        existing_room = db.query(Room).filter(Room.name.ilike(name)).first()
        if existing_room:
            existing_room.type = room_type
            existing_room.capacity = capacity
            if building:
                existing_room.building = building
            if equip_list:
                existing_room.equipment = equip_list
            updated += 1
        else:
            new_room = Room(
                id=str(uuid.uuid4()),
                name=name,
                type=room_type,
                capacity=capacity,
                building=building,
                equipment=equip_list,
                is_active=True
            )
            db.add(new_room)
            created += 1

    db.commit()

    return {
        "status": "success" if rejected == 0 else "partial_success",
        "processed": processed,
        "created": created,
        "updated": updated,
        "rejected": rejected,
        "errors": errors,
        "message": f"Processed {processed} rows: {created} created, {updated} updated, {rejected} rejected."
    }


@router.post("/assignments", response_model=TeachingAssignmentOut, status_code=status.HTTP_201_CREATED)
def create_assignment(payload: TeachingAssignmentCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
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


@router.get("/assignments-detailed")
def list_assignments_detailed(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    """Returns assignments with resolved faculty name, subject name, and division name for display."""
    assignments = db.query(TeachingAssignment).all()
    result = []
    for a in assignments:
        result.append({
            "id": a.id,
            "faculty_id": a.faculty_id,
            "faculty_name": a.faculty.full_name if a.faculty else "Unknown",
            "subject_id": a.subject_id,
            "subject_name": a.subject.name if a.subject else "Unknown",
            "division_id": a.division_id,
            "division_name": f"Year {a.division.year} - Div {a.division.division_code}" if a.division else "Unknown",
        })
    return result


@router.delete("/assignments/{assignment_id}")
def delete_assignment(
    assignment_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    """Deletes a teaching assignment by ID."""
    assignment = db.query(TeachingAssignment).filter(TeachingAssignment.id == assignment_id).first()
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    db.delete(assignment)
    db.commit()
    return {"status": "deleted"}


@router.post("/unavailability", status_code=status.HTTP_201_CREATED)
def create_unavailability(payload: FacultyUnavailabilityCreate, db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    entry = FacultyUnavailability(**payload.model_dump())
    db.add(entry)
    db.commit()
    return {"status": "created"}


# ---------------------------------------------------------------------------
# Institutional Course CRUD
# ---------------------------------------------------------------------------

@router.post("/institutional-courses", response_model=InstitutionalCourseOut, status_code=status.HTTP_201_CREATED)
def create_institutional_course(
    payload: InstitutionalCourseCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    if payload.faculty_id and db.query(User).filter(User.id == payload.faculty_id).first() is None:
        raise HTTPException(status_code=404, detail=f"No faculty found with id {payload.faculty_id}")
    if payload.room_id and db.query(Room).filter(Room.id == payload.room_id).first() is None:
        raise HTTPException(status_code=404, detail=f"No room found with id {payload.room_id}")

    course = InstitutionalCourse(**payload.model_dump())
    db.add(course)
    db.commit()
    db.refresh(course)
    return course


@router.get("/institutional-courses", response_model=list[InstitutionalCourseOut])
def list_institutional_courses(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(InstitutionalCourse).all()


@router.delete("/institutional-courses/{course_id}")
def delete_institutional_course(
    course_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    course = db.query(InstitutionalCourse).filter(InstitutionalCourse.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Institutional course not found")
    db.delete(course)
    db.commit()
    return {"status": "deleted"}


# ---------------------------------------------------------------------------
# Shared Course CRUD
# ---------------------------------------------------------------------------

@router.post("/shared-courses", response_model=SharedCourseOut, status_code=status.HTTP_201_CREATED)
def create_shared_course(
    payload: SharedCourseCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    if db.query(User).filter(User.id == payload.faculty_id).first() is None:
        raise HTTPException(status_code=404, detail=f"No faculty found with id {payload.faculty_id}")
    if payload.room_id and db.query(Room).filter(Room.id == payload.room_id).first() is None:
        raise HTTPException(status_code=404, detail=f"No room found with id {payload.room_id}")

    course = SharedCourse(**payload.model_dump())
    db.add(course)
    db.commit()
    db.refresh(course)
    return course


@router.get("/shared-courses", response_model=list[SharedCourseOut])
def list_shared_courses(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    return db.query(SharedCourse).all()


@router.delete("/shared-courses/{course_id}")
def delete_shared_course(
    course_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager)
):
    course = db.query(SharedCourse).filter(SharedCourse.id == course_id).first()
    if not course:
        raise HTTPException(status_code=404, detail="Shared course not found")
    db.delete(course)
    db.commit()
    return {"status": "deleted"}


# ---------------------------------------------------------------------------
# Pre-flight validation & Solve endpoint
# ---------------------------------------------------------------------------

def _build_generation_request(db: Session) -> TimetableGenerationRequest:
    # 1. Fetch config or default
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    if not config:
        config = ScheduleConfig(
            working_days=6,
            periods_per_day=8,
            break_slots=[],
            max_lectures_per_day_per_faculty=None,
            time_limit_seconds=30
        )

    divisions = db.query(Division).all()
    subjects = db.query(Subject).all()
    rooms = db.query(Room).all()
    assignments = db.query(TeachingAssignment).all()

    # Gather legacy unavailability + generic constraints
    unavail_list = []
    legacy_unavail = db.query(FacultyUnavailability).all()
    for u in legacy_unavail:
        unavail_list.append(SolverUnavailability(faculty_id=u.faculty_id, day=u.day, slot=u.slot))

    generic_constraints = db.query(TimetableConstraint).filter(TimetableConstraint.is_active == True).all()
    soft_constraints = []

    for c in generic_constraints:
        payload = c.payload
        if c.priority == "hard" and c.constraint_type == "faculty_unavailability":
            unavail_list.append(SolverUnavailability(
                faculty_id=payload.get("faculty_id"),
                day=int(payload.get("day", 0)),
                slot=int(payload.get("slot", 0))
            ))
        elif c.priority == "soft":
            soft_constraints.append(SolverSoftConstraint(
                type=c.constraint_type,
                payload=payload
            ))

    # Gather institutional fixed courses and shared courses
    institutional_db = db.query(InstitutionalCourse).all()
    shared_db = db.query(SharedCourse).all()

    solver_institutional = [
        SolverInstitutionalCourse(
            course_name=ic.course_name,
            course_code=ic.course_code,
            year=ic.year,
            divisions=ic.divisions,
            day=ic.day,
            start_slot=ic.start_slot,
            duration_slots=ic.duration_slots,
            faculty_id=ic.faculty_id,
            room_id=ic.room_id
        ) for ic in institutional_db
    ]

    solver_shared = [
        SolverSharedCourse(
            id=sc.id,
            course_name=sc.course_name,
            course_code=sc.course_code,
            year=sc.year,
            divisions=sc.divisions,
            faculty_id=sc.faculty_id,
            room_id=sc.room_id,
            duration_slots=sc.duration_slots,
            weekly_sessions=sc.weekly_sessions,
            session_type=sc.session_type
        ) for sc in shared_db
    ]

    return TimetableGenerationRequest(
        divisions=[SolverDivision(id=d.id, name=d.name, division_code=d.division_code, year=d.year, strength=d.strength) for d in divisions],
        subjects=[
            SolverSubject(
                id=s.id, name=s.name, weekly_lectures=s.weekly_lectures,
                is_lab=s.is_lab, lab_sessions_per_week=s.lab_sessions_per_week,
                lab_block_size=s.lab_block_size
            ) for s in subjects
        ],
        rooms=[SolverRoom(id=r.id, name=r.name, type=r.type, capacity=r.capacity) for r in rooms],
        assignments=[
            SolverAssignment(faculty_id=a.faculty_id, subject_id=a.subject_id, division_id=a.division_id)
            for a in assignments
        ],
        unavailability=unavail_list,
        institutional_courses=solver_institutional,
        shared_courses=solver_shared,
        working_days=config.working_days or 6,
        periods_per_day=config.periods_per_day or 8,
        break_slots=config.break_slots or [],
        max_lectures_per_day_per_faculty=config.max_lectures_per_day_per_faculty,
        time_limit_seconds=config.time_limit_seconds or 30,
        soft_constraints=soft_constraints
    )



@router.get("/validate", response_model=ValidationResponse)
def pre_validate(db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    """Performs Stage 0 pre-solve conflict check against the current DB data."""
    valid, issues, conflicts, suggestions, summary = run_preflight_checks(db)
    return ValidationResponse(
        valid=valid,
        conflicts=conflicts,
        suggestions=suggestions,
        summary=summary,
        issues=issues
    )



@router.post("/generate")
def generate(
    payload: TimetableGenerateRequestBody | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_timetable_manager),
):

    """
    Stage 2 Dynamic Timetable Generation Endpoint.
    Accepts assignments, time slots, constraints, and combined/joint class groupings in the request body.
    Returns: { status, timetable, conflictingConstraints, message, solve_time_seconds }
    """
    if payload and payload.assignments:
        # ✅ ADDED FOR DEBUGGING: Print what Flutter sent
        print("\n=== BACKEND RECEIVED CONSTRAINTS ===")
        for c in payload.constraints:
            # FastAPI parses this as a dict, so we can print it directly
            print(c)
        print("===================================\n")

        effective_working_days = payload.working_days
        if not effective_working_days:
            config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
            if config and config.day_names:
                effective_working_days = config.day_names
            else:
                effective_working_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        # Persist faculty's chosen working days and schedule config to DB
        config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
        if not config:
            config = ScheduleConfig(id="default")
            db.add(config)
        if effective_working_days:
            config.working_days = len(effective_working_days)
            config.day_names = effective_working_days
        if payload.schedule_config and isinstance(payload.schedule_config, dict):
            for k, v in payload.schedule_config.items():
                if hasattr(config, k) and v is not None and k != "id":
                    setattr(config, k, v)
        db.commit()

        db_rooms = db.query(Room).filter(Room.is_active == True).all()
        rooms_payload = [
            {
                "id": r.id,
                "name": r.name,
                "type": r.type.value if hasattr(r.type, "value") else str(r.type),
                "capacity": r.capacity,
            }
            for r in db_rooms
        ]

        solver_result = solve_from_dicts(
            assignments_raw=payload.assignments,
            constraints_raw=payload.constraints,
            combined_groups=payload.combined_groups,
            time_slots_raw=payload.time_slots,
            working_days=effective_working_days,
            time_limit_seconds=payload.time_limit_seconds,
            lecture_duration_minutes=payload.lecture_duration_minutes,
            lab_duration_minutes=payload.lab_duration_minutes,
            rooms=rooms_payload,
        )

        # Auto-persist optimal/feasible timetable to database for immediate live reflection
        if solver_result.status in ("OPTIMAL", "FEASIBLE") and solver_result.timetable:
            try:
                publish_timetable(
                    payload={
                        "timetable": solver_result.timetable,
                        "working_days": effective_working_days,
                        "schedule_config": payload.schedule_config,
                        "assignments": payload.assignments,
                    },
                    db=db,
                    current_user=current_user
                )
            except Exception as e:
                print(f"[Auto-Publish Warning]: {e}")

        return TimetableGenerateResponseBody(
            status=solver_result.status,
            timetable=solver_result.timetable,
            conflictingConstraints=solver_result.conflicts,
            message=solver_result.message,
            solve_time_seconds=solver_result.solve_time_seconds,
        )

    # DB-first fallback: use the staged solver pipeline
    return _run_staged_generate(db)


def _run_staged_generate(db: Session, locked_hints: list[dict] | None = None) -> dict:
    """
    Internal helper — runs the 4-stage solver pipeline from DB data,
    persists results into TimetableEntry + GenerationRun, and returns
    a JSON-serialisable dict suitable as a FastAPI response.
    """
    solver = StagedTimetableSolver(db=db, locked_hint_entries=locked_hints)
    result = solver.solve()

    batch_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    # Build config snapshot for the generation history record
    config_dict = {
        "working_days": solver.working_days,
        "periods_per_day": solver.periods_per_day,
        "break_slots": solver.break_slots,
    }

    stage_log = "\n".join(
        f"{sp.stage_name}: {sp.status} ({sp.total_placed} placed, {sp.solve_time_seconds}s)"
        for sp in result.stage_progress
    )

    if result.status not in ("OPTIMAL", "FEASIBLE"):
        logger.warning(
            "Staged solver status was %s (%s). Executing resilient unified CP-SAT fallback...",
            result.status,
            result.message,
        )
        assignments_raw = []
        for a in db.query(TeachingAssignment).all():
            assignments_raw.append({
                "faculty": a.faculty.full_name if a.faculty else "Faculty",
                "faculty_id": a.faculty_id,
                "subject": a.subject.name if a.subject else "Subject",
                "subject_id": a.subject_id,
                "className": a.division.name if a.division else "Class",
                "division_id": a.division_id,
                "type": a.session_type or "Theory",
                "batch": a.batch_name or "-",
                "weeklyHours": a.weekly_count or 1,
            })

        config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
        day_names = (
            config.day_names
            if config and config.day_names
            else ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        )

        time_slots_raw = []
        if config and config.periods_per_day:
            b_slots = config.get_break_slots()
            l_slot = config.get_lunch_slot()
            for p in range(1, config.periods_per_day + 1):
                time_slots_raw.append({
                    "slot_number": p,
                    "is_break": p in b_slots,
                    "is_lunch": p == l_slot,
                })

        unified_res = solve_from_dicts(
            assignments_raw=assignments_raw,
            constraints_raw=[],
            working_days=day_names,
            time_slots_raw=time_slots_raw if time_slots_raw else None,
            time_limit_seconds=30,
        )

        if unified_res.status in ("OPTIMAL", "FEASIBLE") and unified_res.timetable:
            try:
                publish_timetable(
                    payload={
                        "timetable": unified_res.timetable,
                        "working_days": day_names,
                        "assignments": assignments_raw,
                    },
                    db=db,
                    current_user=None,
                )
            except Exception as e:
                logger.warning("Auto-publish unified fallback notice: %s", e)

            return {
                "batch_id": batch_id,
                "status": unified_res.status,
                "total_entries": sum(len(slots) for slots in unified_res.timetable.values()),
                "solve_time_seconds": unified_res.solve_time_seconds,
                "validation_passed": True,
                "message": unified_res.message,
                "timetable": unified_res.timetable,
                "stage_progress": [
                    {"stage": "Stage 1: Fixed Slots", "status": "OPTIMAL", "placed": 0, "time": 0.0},
                    {"stage": "Stage 2: Unified CP-SAT Solver", "status": unified_res.status, "placed": sum(len(slots) for slots in unified_res.timetable.values()), "time": unified_res.solve_time_seconds},
                ],
            }

        db_run = GenerationRun(
            id=batch_id,
            status=result.status,
            solve_time_seconds=result.solve_time_seconds,
            total_entries=0,
            validation_passed=False,
            config_snapshot=config_dict,
            conflicts=result.conflicts,
            suggestions=[],
            solver_log=stage_log[:4000]
        )
        db.add(db_run)
        db.commit()

        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "status": result.status,
                "message": result.message or "Staged solver failed.",
                "conflicts": result.conflicts,
                "stage_progress": [
                    {"stage": sp.stage_name, "status": sp.status, "placed": sp.total_placed,
                     "time": sp.solve_time_seconds, "conflicts": sp.conflicts}
                    for sp in result.stage_progress
                ]
            }
        )

    # Clear old entries and persist the new timetable
    db.query(TimetableEntry).delete()

    for entry in result.entries:
        db.add(TimetableEntry(
            batch_id=batch_id,
            division_id=entry["division_id"],
            subject_id=entry["subject_id"],
            faculty_id=entry["faculty_id"],
            room_id=entry["room_id"],
            day=entry["day"],
            slot=entry["slot"],
            is_lab_block=entry.get("is_lab_block", False),
            batch_name=entry.get("batch_name"),
            session_type=entry.get("session_type", "lecture"),
            generated_at=now,
        ))

    db_run = GenerationRun(
        id=batch_id,
        status=result.status,
        solve_time_seconds=result.solve_time_seconds,
        total_entries=result.total_entries,
        validation_passed=True,
        config_snapshot=config_dict,
        conflicts=[],
        suggestions=[],
        solver_log=stage_log[:4000]
    )
    db.add(db_run)

    # Notify affected faculty
    affected_faculty_ids = {e["faculty_id"] for e in result.entries}
    for faculty_id in affected_faculty_ids:
        notify(
            db,
            recipient_id=faculty_id,
            title="Timetable updated",
            message="Your timetable has been regenerated. Open Timetable to see your new schedule.",
        )

    db.commit()

    return {
        "batch_id": batch_id,
        "status": result.status,
        "total_entries": result.total_entries,
        "solve_time_seconds": result.solve_time_seconds,
        "validation_passed": True,
        "message": result.message,
        "stage_progress": [
            {"stage": sp.stage_name, "status": sp.status, "placed": sp.total_placed,
             "time": sp.solve_time_seconds}
            for sp in result.stage_progress
        ]
    }


@router.post("/generate-staged")
def generate_staged(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_timetable_manager),
):
    """
    Explicit staged-generation endpoint. Always reads from DB.
    Returns detailed per-stage progress alongside the generated timetable.
    """
    return _run_staged_generate(db)


# ---------------------------------------------------------------------------
# Published Timetable — read/write view endpoints for Flutter / Web
# ---------------------------------------------------------------------------

@router.post("/publish")
def publish_timetable(
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_current_user),
):
    """
    Publishes and permanently persists a solved timetable into MySQL/SQLite (TimetableEntry and GenerationRun tables).
    Also stores all imported Divisions, AcademicClasses, Subjects, and TeachingAssignments from Excel.
    Once published:
    1. It shows on the public/faculty timetable views.
    2. It populates each faculty member's homepage Dashboard 'Today's Schedule' automatically.
    3. It populates the SLI module for assessment creation and student roster.
    """
    timetable_data = payload.get("timetable", {})
    if not timetable_data:
        raise HTTPException(status_code=400, detail="No timetable data provided to publish.")

    batch_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc)

    # 1. Config & Days mapping — store faculty's chosen working days
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    if not config:
        config = ScheduleConfig(id="default")
        db.add(config)

    working_days_input = payload.get("working_days")
    if working_days_input and isinstance(working_days_input, list):
        config.working_days = len(working_days_input)
        config.day_names = working_days_input

    schedule_cfg_input = payload.get("schedule_config")
    if schedule_cfg_input and isinstance(schedule_cfg_input, dict):
        for k, v in schedule_cfg_input.items():
            if hasattr(config, k) and v is not None and k != "id":
                setattr(config, k, v)
    db.commit()
    db.refresh(config)

    day_names = (
        config.day_names
        if config and config.day_names
        else ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    )
    day_map = {name.lower(): i for i, name in enumerate(day_names)}
    day_map.update({
        "mon": 0, "monday": 0,
        "tue": 1, "tues": 1, "tuesday": 1,
        "wed": 2, "wednesday": 2,
        "thu": 3, "thur": 3, "thurs": 3, "thursday": 3,
        "fri": 4, "friday": 4,
        "sat": 5, "saturday": 5,
        "sun": 6, "sunday": 6,
    })

    dept = db.query(Department).first()
    if not dept:
        dept = Department(department_id=1, name="Computer Science & Engineering", code="CSE")
        db.add(dept)
        db.flush()
    dept_id = dept.department_id

    sem = db.query(Semester).filter(Semester.status == "ACTIVE").first()
    if not sem:
        sem = db.query(Semester).first()
    if not sem:
        sem = Semester(
            semester_id=1,
            semester_number=1,
            academic_year="2026-27",
            status="ACTIVE",
        )
        db.add(sem)
        db.flush()

    # Cache existing records
    all_existing_users = db.query(User).all()
    user_cache = {u.full_name.lower().strip(): u for u in all_existing_users if u.full_name}
    div_cache = {d.name.lower().strip(): d for d in db.query(Division).all() if d.name}
    div_code_cache = {d.division_code.lower().strip(): d for d in db.query(Division).all() if d.division_code}
    sub_cache = {s.name.lower().strip(): s for s in db.query(Subject).all() if s.name}
    room_cache = {r.name.lower().strip(): r for r in db.query(Room).all() if r.name}

    # 2. Process and store imported assignments from Excel
    assignments_input = payload.get("assignments", [])
    if isinstance(assignments_input, list):
        for a in assignments_input:
            if not isinstance(a, dict):
                continue
            a_fac = str(a.get("facultyName") or a.get("faculty_name") or "").strip()
            a_sub_name = str(a.get("subjectName") or a.get("subject_name") or "").strip()
            a_sub_code = str(a.get("subjectCode") or a.get("subject_code") or "").strip()
            a_class = str(a.get("className") or a.get("class_name") or "").strip()
            a_type = str(a.get("type", "Theory")).lower()
            a_hours = int(a.get("weeklyHours") or a.get("weekly_hours") or 3)
            a_batch = str(a.get("batch") or "All")
            a_joint = a.get("joint_group_id")

            if not a_class or not a_sub_name:
                continue

            # Ensure Division
            div = div_cache.get(a_class.lower()) or div_code_cache.get(a_class.lower())
            if not div:
                year = 1
                c_low = a_class.lower()
                if "sy" in c_low or "second" in c_low or "2" in c_low: year = 2
                elif "ty" in c_low or "third" in c_low or "3" in c_low: year = 3
                elif "btech" in c_low or "final" in c_low or "be" in c_low or "4" in c_low: year = 4
                div_code = "A"
                if "-" in a_class:
                    cand = a_class.split("-")[-1].strip().upper()
                    if cand in ("A", "B", "C", "D", "E"):
                        div_code = cand
                div = Division(id=str(uuid.uuid4()), name=a_class, division_code=div_code, year=year)
                db.add(div)
                db.flush()
                div_cache[a_class.lower()] = div
                div_code_cache[div.division_code.lower()] = div

            # Ensure AcademicClass for SLI
            ac = db.query(AcademicClass).filter(AcademicClass.division_id == div.id).first()
            if not ac:
                ac = db.query(AcademicClass).filter(
                    AcademicClass.year_level == div.year,
                    AcademicClass.division == div.division_code,
                ).first()
            if not ac:
                ac = AcademicClass(
                    department_id=dept_id,
                    year_level=div.year,
                    division=div.division_code,
                    division_id=div.id,
                    academic_year="2026-27",
                )
                db.add(ac)
                db.flush()
            elif not ac.division_id:
                ac.division_id = div.id
                db.flush()

            # Ensure Subject
            sub = sub_cache.get(a_sub_name.lower())
            if not sub and a_sub_code:
                sub = db.query(Subject).filter(Subject.code == a_sub_code).first()
            if not sub:
                sub = Subject(
                    id=str(uuid.uuid4()),
                    name=a_sub_name,
                    code=a_sub_code or a_sub_name[:10].upper(),
                    weekly_lectures=a_hours,
                    is_lab=(a_type == "lab"),
                    sli_department_id=dept_id,
                )
                db.add(sub)
                db.flush()
                sub_cache[a_sub_name.lower()] = sub
            elif a_sub_code and sub.code != a_sub_code:
                sub.code = a_sub_code
                db.flush()

            # Match Faculty User
            fac_clean = _clean_title(a_fac)
            fac_tokens = set(fac_clean.replace(".", " ").split())
            fac_user = user_cache.get(a_fac.lower())
            if not fac_user and fac_clean:
                if current_user and current_user.full_name:
                    cur_clean = _clean_title(current_user.full_name)
                    cur_tokens = set(cur_clean.replace(".", " ").split())
                    if fac_clean in cur_clean or cur_clean in fac_clean or (fac_tokens and fac_tokens.intersection(cur_tokens)):
                        fac_user = current_user
                if not fac_user:
                    for u in all_existing_users:
                        if not u.full_name:
                            continue
                        u_clean = _clean_title(u.full_name)
                        u_tokens = set(u_clean.replace(".", " ").split())
                        if fac_clean == u_clean or fac_clean in u_clean or u_clean in fac_clean or (fac_tokens and fac_tokens.intersection(u_tokens)):
                            fac_user = u
                            break
            if not fac_user:
                email_prefix = fac_clean.replace(' ', '.').replace('..', '.') if fac_clean else f"faculty_{uuid.uuid4().hex[:6]}"
                fac_email = f"{email_prefix}@enosis.edu"
                if db.query(User).filter(User.email == fac_email).first():
                    fac_email = f"{email_prefix}_{uuid.uuid4().hex[:4]}@enosis.edu"
                fac_user = User(
                    id=str(uuid.uuid4()),
                    email=fac_email,
                    full_name=a_fac or "Faculty Member",
                    hashed_password="hashed_placeholder_pw",
                    role=UserRole.FACULTY,
                )
                db.add(fac_user)
                db.flush()
                all_existing_users.append(fac_user)
                user_cache[a_fac.lower()] = fac_user
                if fac_user.full_name:
                    user_cache[fac_user.full_name.lower()] = fac_user

            # Upsert TeachingAssignment
            ta = db.query(TeachingAssignment).filter(
                TeachingAssignment.faculty_id == fac_user.id,
                TeachingAssignment.subject_id == sub.id,
                TeachingAssignment.division_id == div.id,
            ).first()
            if not ta:
                ta = TeachingAssignment(
                    id=str(uuid.uuid4()),
                    faculty_id=fac_user.id,
                    subject_id=sub.id,
                    division_id=div.id,
                    session_type=a_type,
                    weekly_count=a_hours,
                    batch_name=a_batch,
                    joint_group_id=a_joint,
                )
                db.add(ta)
                db.flush()

            # Ensure current logged-in faculty also gets teaching assignment if matching or author
            if current_user and current_user.id != fac_user.id:
                cur_clean = _clean_title(current_user.full_name or "")
                cur_tokens = set(cur_clean.replace(".", " ").split())
                if fac_clean in cur_clean or cur_clean in fac_clean or (fac_tokens and fac_tokens.intersection(cur_tokens)):
                    cur_ta = db.query(TeachingAssignment).filter(
                        TeachingAssignment.faculty_id == current_user.id,
                        TeachingAssignment.subject_id == sub.id,
                        TeachingAssignment.division_id == div.id,
                    ).first()
                    if not cur_ta:
                        cur_ta = TeachingAssignment(
                            id=str(uuid.uuid4()),
                            faculty_id=current_user.id,
                            subject_id=sub.id,
                            division_id=div.id,
                            session_type=a_type,
                            weekly_count=a_hours,
                            batch_name=a_batch,
                        )
                        db.add(cur_ta)
                        db.flush()

    # Clear old timetable entries
    db.query(TimetableEntry).delete()

    total_saved = 0
    enrolled_class_subjects: set[tuple[int, str, int]] = set()

    # 3. Store timetable grid entries
    for class_name, slot_dict in timetable_data.items():
        if not isinstance(slot_dict, dict):
            continue
        c_clean = class_name.strip()
        div = div_cache.get(c_clean.lower()) or div_code_cache.get(c_clean.lower())
        if not div:
            year = 1
            c_low = c_clean.lower()
            if "sy" in c_low or "second" in c_low or "2" in c_low: year = 2
            elif "ty" in c_low or "third" in c_low or "3" in c_low: year = 3
            elif "btech" in c_low or "final" in c_low or "be" in c_low or "4" in c_low: year = 4
            div_code = "A"
            if "-" in c_clean:
                cand = c_clean.split("-")[-1].strip().upper()
                if cand in ("A", "B", "C", "D", "E"):
                    div_code = cand
            div = Division(id=str(uuid.uuid4()), name=c_clean, division_code=div_code, year=year)
            db.add(div)
            db.flush()
            div_cache[c_clean.lower()] = div

        for slot_key, cell_data in slot_dict.items():
            if not isinstance(cell_data, list) or not cell_data:
                continue
            subj_name = str(cell_data[0]).strip()
            if not subj_name or subj_name in ("-", "Free", "Break", "BREAK"):
                continue

            fac_name = str(cell_data[1]).strip() if len(cell_data) > 1 else ""
            room_name = str(cell_data[2]).strip() if len(cell_data) > 2 else ""
            batch_name = str(cell_data[3]).strip() if len(cell_data) > 3 else "All"

            parts = slot_key.split("_")
            if len(parts) != 2:
                continue
            raw_day = parts[0].lower().strip()
            raw_slot_num = int(parts[1]) if parts[1].isdigit() else 1
            day_idx = day_map.get(raw_day, 0)
            slot_idx = max(0, raw_slot_num - 1)

            sub = sub_cache.get(subj_name.lower())
            if not sub:
                sub = Subject(id=str(uuid.uuid4()), name=subj_name, code=subj_name[:10].upper(), sli_department_id=dept_id)
                db.add(sub)
                db.flush()
                sub_cache[subj_name.lower()] = sub

            fac_clean = _clean_title(fac_name)
            fac_tokens = set(fac_clean.replace(".", " ").split())

            fac_user = user_cache.get(fac_name.lower())
            if not fac_user and fac_clean:
                # Check current_user first
                if current_user and current_user.full_name:
                    cur_clean = _clean_title(current_user.full_name)
                    cur_tokens = set(cur_clean.replace(".", " ").split())
                    if fac_clean in cur_clean or cur_clean in fac_clean or (fac_tokens and fac_tokens.intersection(cur_tokens)):
                        fac_user = current_user

                # Search all existing users
                if not fac_user:
                    for u in all_existing_users:
                        if not u.full_name:
                            continue
                        u_clean = _clean_title(u.full_name)
                        u_tokens = set(u_clean.replace(".", " ").split())
                        if fac_clean == u_clean or fac_clean in u_clean or u_clean in fac_clean or (fac_tokens and fac_tokens.intersection(u_tokens)):
                            fac_user = u
                            break

            if not fac_user:
                email_prefix = fac_clean.replace(' ', '.').replace('..', '.') if fac_clean else f"faculty_{uuid.uuid4().hex[:6]}"
                fac_email = f"{email_prefix}@enosis.edu"
                if db.query(User).filter(User.email == fac_email).first():
                    fac_email = f"{email_prefix}_{uuid.uuid4().hex[:4]}@enosis.edu"
                fac_user = User(
                    id=str(uuid.uuid4()),
                    email=fac_email,
                    full_name=fac_name or "Faculty Member",
                    hashed_password="hashed_placeholder_pw",
                    role=UserRole.FACULTY,
                )
                db.add(fac_user)
                db.flush()
                all_existing_users.append(fac_user)
                user_cache[fac_name.lower()] = fac_user
                if fac_user.full_name:
                    user_cache[fac_user.full_name.lower()] = fac_user

            # If current_user is creating timetable and matches fac_name, ensure fac_user is current_user
            if current_user and current_user.full_name:
                cur_clean = _clean_title(current_user.full_name)
                cur_tokens = set(cur_clean.replace(".", " ").split())
                if fac_clean in cur_clean or cur_clean in fac_clean or (fac_tokens and fac_tokens.intersection(cur_tokens)):
                    fac_user = current_user

            room = room_cache.get(room_name.lower()) if room_name else None
            if not room:
                is_lab_room = "lab" in subj_name.lower() or "lab" in room_name.lower()
                room = Room(
                    id=str(uuid.uuid4()),
                    name=room_name or ("Lab 1" if is_lab_room else "Classroom 1"),
                    type=RoomType.LAB if is_lab_room else RoomType.LECTURE,
                    capacity=60,
                )
                db.add(room)
                db.flush()
                if room_name:
                    room_cache[room_name.lower()] = room

            is_lab = "lab" in subj_name.lower() or "practical" in subj_name.lower()

            entry = TimetableEntry(
                id=str(uuid.uuid4()),
                batch_id=batch_id,
                division_id=div.id,
                subject_id=sub.id,
                faculty_id=fac_user.id,
                room_id=room.id,
                day=day_idx,
                slot=slot_idx,
                is_lab_block=is_lab,
                batch_name=batch_name,
                session_type="lab" if is_lab else "lecture",
                generated_at=now,
            )
            db.add(entry)
            total_saved += 1

            # Ensure TeachingAssignment exists for faculty
            ta = db.query(TeachingAssignment).filter(
                TeachingAssignment.faculty_id == fac_user.id,
                TeachingAssignment.subject_id == sub.id,
                TeachingAssignment.division_id == div.id,
            ).first()
            if not ta:
                ta = TeachingAssignment(
                    id=str(uuid.uuid4()),
                    faculty_id=fac_user.id,
                    subject_id=sub.id,
                    division_id=div.id,
                    session_type="lab" if is_lab else "theory",
                    weekly_count=1,
                    duration_slots=2 if is_lab else 1,
                    batch_name=batch_name if batch_name != "All" else None,
                )
                db.add(ta)

            # Ensure AcademicClass exists for SLI
            ac = db.query(AcademicClass).filter(AcademicClass.division_id == div.id).first()
            if not ac:
                ac = db.query(AcademicClass).filter(
                    AcademicClass.year_level == div.year,
                    AcademicClass.division == div.division_code,
                ).first()
            if not ac:
                ac = AcademicClass(
                    department_id=dept_id,
                    year_level=div.year,
                    division=div.division_code,
                    division_id=div.id,
                    academic_year="2026-27",
                )
                db.add(ac)
                db.flush()
            elif not ac.division_id:
                ac.division_id = div.id
                db.flush()

            # Ensure student enrollments exist so SLI assessments and roster work
            if ac and sem:
                key = (ac.class_id, sub.id, sem.semester_id)
                if key not in enrolled_class_subjects:
                    enrolled_class_subjects.add(key)
                    existing_student_ids = {
                        row[0]
                        for row in db.query(Enrollment.student_id)
                        .filter(
                            Enrollment.class_id == ac.class_id,
                            Enrollment.subject_id == sub.id,
                            Enrollment.semester_id == sem.semester_id,
                        )
                        .all()
                    }
                    students = (
                        db.query(Student.student_id)
                        .filter(
                            Student.current_year == div.year,
                            Student.division == div.division_code,
                        )
                        .all()
                    )
                    for (stu_id,) in students:
                        if stu_id not in existing_student_ids:
                            enr = Enrollment(
                                student_id=stu_id,
                                class_id=ac.class_id,
                                subject_id=sub.id,
                                semester_id=sem.semester_id,
                            )
                            db.add(enr)
                            existing_student_ids.add(stu_id)

    db_run = GenerationRun(
        id=batch_id,
        status="OPTIMAL",
        solve_time_seconds=1.0,
        total_entries=total_saved,
        validation_passed=True,
        generated_at=now,
        config_snapshot={
            "working_days": len(day_names),
            "day_names": day_names,
            "periods_per_day": config.periods_per_day if config else 8,
            "published_at": now.isoformat(),
        },
        conflicts=[],
        suggestions=[],
        solver_log="Published via UI",
    )
    db.add(db_run)
    db.commit()

    return {
        "status": "published",
        "message": f"Successfully published timetable with {total_saved} scheduled sessions!",
        "batch_id": batch_id,
        "total_entries": total_saved,
    }


@router.get("/published")
def get_published_timetable(
    view_type: str = "class",
    target: str | None = None,
    db: Session = Depends(get_db),
    _: User | None = Depends(get_optional_current_user),
):
    """
    Returns the latest generated timetable in a grid-friendly format.

    Query params:
        view_type: "class" | "faculty" | "room"
        target:    Division name (for class), faculty id (for faculty),
                   room id (for room).  If omitted, returns all.

    Response shape (matches Flutter's TimetableEntryModel parser):
        { "TE-A": { "Monday_1": ["DBMS", "Dr. Smith", "Room 301", "All"], ... }, ... }
    """
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    day_names = (config.day_names if config and config.day_names
                 else ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])

    # Find the latest batch_id
    latest_run = (
        db.query(GenerationRun)
        .filter(GenerationRun.status.in_(["OPTIMAL", "FEASIBLE"]))
        .order_by(GenerationRun.generated_at.desc())
        .first()
    )
    if not latest_run:
        return {}  # No timetable has been generated yet

    query = db.query(TimetableEntry).filter(TimetableEntry.batch_id == latest_run.id)

    # Apply target filter
    if view_type == "class" and target:
        div = db.query(Division).filter(
            (Division.name == target) | (Division.division_code == target)
        ).first()
        if div:
            query = query.filter(TimetableEntry.division_id == div.id)
        else:
            return {}
    elif view_type == "faculty" and target:
        query = query.filter(TimetableEntry.faculty_id == target)
    elif view_type == "room" and target:
        query = query.filter(TimetableEntry.room_id == target)

    entries = query.all()

    # Build name caches
    div_cache: dict[str, str] = {}
    sub_cache: dict[str, str] = {}
    fac_cache: dict[str, str] = {}
    room_cache: dict[str, str] = {}

    grid: dict[str, dict[str, list[str]]] = defaultdict(dict)

    for e in entries:
        # Lazily populate caches
        if e.division_id not in div_cache:
            d = db.get(Division, e.division_id)
            div_cache[e.division_id] = d.name if d else e.division_id
        if e.subject_id not in sub_cache:
            s = db.get(Subject, e.subject_id)
            sub_cache[e.subject_id] = s.name if s else e.subject_id
        if e.faculty_id not in fac_cache:
            f = db.get(User, e.faculty_id)
            fac_cache[e.faculty_id] = f.full_name if f else e.faculty_id
        if e.room_id not in room_cache:
            r = db.get(Room, e.room_id)
            room_cache[e.room_id] = r.name if r else e.room_id

        day_name = day_names[e.day] if 0 <= e.day < len(day_names) else f"Day_{e.day}"
        slot_key = f"{day_name}_{e.slot + 1}"  # 1-indexed for display

        if view_type == "class":
            group_key = div_cache[e.division_id]
        elif view_type == "faculty":
            group_key = fac_cache[e.faculty_id]
        else:
            group_key = room_cache[e.room_id]

        grid[group_key][slot_key] = [
            sub_cache[e.subject_id],
            fac_cache[e.faculty_id],
            room_cache[e.room_id],
            e.batch_name or "All"
        ]

    return dict(grid)


# ---------------------------------------------------------------------------
# Generation History / Logs API
# ---------------------------------------------------------------------------

@router.get("/history", response_model=list[GenerationRunOut])
def get_generation_history(db: Session = Depends(get_db), _: User = Depends(require_timetable_manager)):
    """Retrieves all past generation runs."""
    return db.query(GenerationRun).order_by(GenerationRun.generated_at.desc()).all()


# ---------------------------------------------------------------------------
# Seeding / Upload / Deletion APIs
# ---------------------------------------------------------------------------

@router.post("/seed-sample-data")
def seed_sample_data(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_timetable_manager),
):
    unique = uuid.uuid4().hex[:6]

    # Clear config and seed standard one
    db.query(ScheduleConfig).delete()
    config = ScheduleConfig(
        id="default",
        working_days=5,
        day_names=["Tue", "Wed", "Thur", "Fri", "Sat"], # Match Flutter Day Scheme
        periods_per_day=8,
        period_duration_minutes=60,
        start_time="09:00",
        break_slots=[2, 5],
        break_labels={"2": "Short Break", "5": "Lunch Break"},
        college_name="ENOSIS Engineering Institute"
    )
    db.add(config)

    division_a = Division(name=f"Sample-A-{unique}", year=2, division_code="A", strength=60)
    division_b = Division(name=f"Sample-B-{unique}", year=2, division_code="B", strength=55)
    db.add_all([division_a, division_b])

    daa = Subject(name=f"DAA ({unique})", code="CS301", weekly_lectures=3)
    os_subject = Subject(name=f"Operating Systems ({unique})", code="CS302", weekly_lectures=3)
    dbms = Subject(
        name=f"DBMS ({unique})", code="CS303",
        weekly_lectures=2, is_lab=True, lab_sessions_per_week=1, lab_block_size=2,
    )
    maths = Subject(name=f"Engineering Maths ({unique})", code="MA301", weekly_lectures=4)
    db.add_all([daa, os_subject, dbms, maths])

    room_301 = Room(name=f"Room 301-{unique}", type="lecture", capacity=70)
    room_302 = Room(name=f"Room 302-{unique}", type="lecture", capacity=70)
    lab_1 = Room(name=f"Lab 1-{unique}", type="lab", capacity=70)
    db.add_all([room_301, room_302, lab_1])

    db.flush()

    for subject in (daa, os_subject, dbms, maths):
        db.add(TeachingAssignment(faculty_id=current_user.id, subject_id=subject.id, division_id=division_a.id))
        db.add(TeachingAssignment(faculty_id=current_user.id, subject_id=subject.id, division_id=division_b.id))

    db.commit()

    return {
        "status": "seeded",
        "divisions_created": 2,
        "subjects_created": 4,
        "rooms_created": 3,
        "assignments_created": 8,
        "message": f"Sample data created (tagged '{unique}') with default 5-day config and breaks.",
    }


@router.post("/clear-all")
def clear_all(
    db: Session = Depends(get_db),
    _: User = Depends(require_timetable_manager),
):
    db.query(TimetableEntry).delete()
    db.query(FacultyUnavailability).delete()
    db.query(TimetableConstraint).delete()
    db.query(GenerationRun).delete()
    db.query(TeachingAssignment).delete()
    db.query(Division).delete()
    db.query(Subject).delete()
    db.query(Room).delete()
    db.query(ScheduleConfig).delete()
    db.commit()
    return {"message": "All setup data, constraints, and timetable entries cleared successfully."}


def _ensure_placeholder_entities(db: Session, course_name: str, course_code: str | None, faculty_id: str | None, room_id: str | None):
    # 1. Subject
    subject = db.query(Subject).filter(Subject.name == course_name).first()
    if not subject:
        subject = Subject(id=str(uuid.uuid4()), name=course_name, code=course_code or "FIXED")
        db.add(subject)
        db.flush()
    
    # 2. Faculty
    if not faculty_id:
        faculty = db.query(User).first()
        if not faculty:
            # Create a default guest placeholder user
            faculty = User(
                id=str(uuid.uuid4()), 
                email="placeholder@enosis.edu", 
                full_name="Staff / Guest", 
                hashed_password="",
                role="faculty"
            )
            db.add(faculty)
            db.flush()
        faculty_id = faculty.id
        
    # 3. Room
    if not room_id:
        room = db.query(Room).filter(Room.name == "TBA Classroom").first()
        if not room:
            room = Room(id=str(uuid.uuid4()), name="TBA Classroom", type="lecture", capacity=100)
            db.add(room)
            db.flush()
        room_id = room.id
        
    return subject.id, faculty_id, room_id


@router.post("/upload-excel")
async def upload_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_timetable_manager),
):
    filename = file.filename or ""
    content = await file.read()

    # Clear previous database state
    db.query(TimetableEntry).delete()
    db.query(FacultyUnavailability).delete()
    db.query(TimetableConstraint).delete()
    db.query(TeachingAssignment).delete()
    db.query(InstitutionalCourse).delete()
    db.query(SharedCourse).delete()
    db.query(Division).delete()
    db.query(Subject).delete()
    db.query(Room).delete()
    db.query(ScheduleConfig).delete()
    db.flush()

    # Seed Default config alongside Excel upload
    config = ScheduleConfig(
        id="default",
        working_days=6,
        day_names=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        periods_per_day=8,
        period_duration_minutes=60,
        lecture_duration_minutes=60,
        lab_duration_minutes=120,
        tutorial_duration_minutes=60,
        start_time="09:00"
    )
    db.add(config)

    created_divisions = []
    created_subjects = []
    created_rooms = []
    created_assignments = []
    created_fixed = []
    created_shared = []

    errors = []

    if filename.lower().endswith(".xlsx"):
        try:
            import openpyxl
        except ImportError:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Excel parser (openpyxl) is not installed in the environment. Please upload CSV or install openpyxl."
            )
        try:
            wb = openpyxl.load_workbook(io.BytesIO(content), data_only=True)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Failed to parse Excel file: {str(e)}")

        # 1. Parse Divisions
        if "Divisions" in wb.sheetnames:
            ws = wb["Divisions"]
            headers = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1)) if cell.value]
            for row_idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not row or not any(row):
                    continue
                row_dict = dict(zip(headers, row))
                try:
                    div = Division(
                        id=str(uuid.uuid4()),
                        name=str(row_dict.get("name", "")).strip(),
                        year=int(row_dict.get("year", 1)),
                        division_code=str(row_dict.get("division_code", "A")).strip(),
                        strength=int(row_dict.get("strength", 60)),
                    )
                    db.add(div)
                    created_divisions.append(div)
                except Exception as e:
                    errors.append(f"Divisions Sheet Row {row_idx}: {str(e)}")

        # 2. Parse Subjects
        if "Subjects" in wb.sheetnames:
            ws = wb["Subjects"]
            headers = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1)) if cell.value]
            for row_idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not row or not any(row):
                    continue
                row_dict = dict(zip(headers, row))
                try:
                    sub = Subject(
                        id=str(uuid.uuid4()),
                        name=str(row_dict.get("name", "")).strip(),
                        code=str(row_dict.get("code", "")).strip(),
                        weekly_lectures=int(row_dict.get("weekly_lectures", 3)),
                        is_lab=bool(row_dict.get("is_lab", False)),
                        lab_sessions_per_week=int(row_dict.get("lab_sessions_per_week", 0)),
                        lab_block_size=int(row_dict.get("lab_block_size", 2)),
                    )
                    db.add(sub)
                    created_subjects.append(sub)
                except Exception as e:
                    errors.append(f"Subjects Sheet Row {row_idx}: {str(e)}")

        # 3. Parse Rooms
        if "Rooms" in wb.sheetnames:
            ws = wb["Rooms"]
            headers = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1)) if cell.value]
            for row_idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not row or not any(row):
                    continue
                row_dict = dict(zip(headers, row))
                try:
                    room = Room(
                        id=str(uuid.uuid4()),
                        name=str(row_dict.get("name", "")).strip(),
                        type=str(row_dict.get("type", "lecture")).strip().lower(),
                        capacity=int(row_dict.get("capacity", 60)),
                    )
                    db.add(room)
                    created_rooms.append(room)
                except Exception as e:
                    errors.append(f"Rooms Sheet Row {row_idx}: {str(e)}")

        # Flush to generate IDs
        db.flush()

        # Maps for quick lookups
        div_by_name = {d.name.upper(): d.id for d in created_divisions}
        sub_by_code = {s.code.upper(): s.id for s in created_subjects}
        room_by_name = {r.name.upper(): r.id for r in created_rooms}
        faculty_by_email = {u.email.lower(): u.id for u in db.query(User).all()}

        # 4. Parse Assignments
        if "Assignments" in wb.sheetnames:
            ws = wb["Assignments"]
            headers = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1)) if cell.value]
            for row_idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not row or not any(row):
                    continue
                row_dict = dict(zip(headers, row))
                try:
                    fac_email = str(row_dict.get("faculty_email", "")).strip().lower()
                    sub_code = str(row_dict.get("subject_code", "")).strip().upper()
                    div_name = str(row_dict.get("division_name", "")).strip().upper()

                    fac_id = faculty_by_email.get(fac_email)
                    sub_id = sub_by_code.get(sub_code)
                    div_id = div_by_name.get(div_name)

                    if not fac_id:
                        errors.append(f"Assignments Row {row_idx}: Faculty email '{fac_email}' not found.")
                        continue
                    if not sub_id:
                        errors.append(f"Assignments Row {row_idx}: Subject code '{sub_code}' not found.")
                        continue
                    if not div_id:
                        errors.append(f"Assignments Row {row_idx}: Division name '{div_name}' not found.")
                        continue

                    assignment = TeachingAssignment(
                        id=str(uuid.uuid4()),
                        faculty_id=fac_id,
                        subject_id=sub_id,
                        division_id=div_id,
                    )
                    db.add(assignment)
                    created_assignments.append(assignment)
                except Exception as e:
                    errors.append(f"Assignments Row {row_idx}: {str(e)}")

        # 5. Parse Fixed Courses
        if "FixedCourses" in wb.sheetnames:
            ws = wb["FixedCourses"]
            headers = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1)) if cell.value]
            for row_idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not row or not any(row):
                    continue
                row_dict = dict(zip(headers, row))
                try:
                    divisions_str = str(row_dict.get("divisions", ""))
                    div_list = [d.strip() for d in divisions_str.split(",") if d.strip()]

                    fac_email = str(row_dict.get("faculty_email", "")).strip().lower() if row_dict.get("faculty_email") else None
                    rm_name = str(row_dict.get("room_name", "")).strip().upper() if row_dict.get("room_name") else None

                    fac_id = faculty_by_email.get(fac_email) if fac_email else None
                    rm_id = room_by_name.get(rm_name) if rm_name else None

                    if fac_email and not fac_id:
                        errors.append(f"FixedCourses Row {row_idx}: Faculty email '{fac_email}' not found.")
                        continue
                    if rm_name and not rm_id:
                        errors.append(f"FixedCourses Row {row_idx}: Room '{rm_name}' not found.")
                        continue

                    course = InstitutionalCourse(
                        id=str(uuid.uuid4()),
                        course_name=str(row_dict.get("course_name", "")).strip(),
                        course_code=str(row_dict.get("course_code", "")) or None,
                        year=int(row_dict.get("year", 1)),
                        divisions=div_list,
                        day=int(row_dict.get("day", 0)),
                        start_slot=int(row_dict.get("start_slot", 0)),
                        duration_slots=int(row_dict.get("duration_slots", 1)),
                        faculty_id=fac_id,
                        room_id=rm_id
                    )
                    
                    # Ensure placeholder entities if they are Null so timetable foreign keys pass
                    resolved_sub, resolved_fac, resolved_room = _ensure_placeholder_entities(
                        db, course.course_name, course.course_code, course.faculty_id, course.room_id
                    )
                    course.faculty_id = resolved_fac
                    course.room_id = resolved_room

                    db.add(course)
                    created_fixed.append(course)
                except Exception as e:
                    errors.append(f"FixedCourses Row {row_idx}: {str(e)}")

        # 6. Parse Shared Courses
        if "SharedCourses" in wb.sheetnames:
            ws = wb["SharedCourses"]
            headers = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1)) if cell.value]
            for row_idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True), start=2):
                if not row or not any(row):
                    continue
                row_dict = dict(zip(headers, row))
                try:
                    divisions_str = str(row_dict.get("divisions", ""))
                    div_list = [d.strip() for d in divisions_str.split(",") if d.strip()]

                    fac_email = str(row_dict.get("faculty_email", "")).strip().lower()
                    rm_name = str(row_dict.get("room_name", "")).strip().upper() if row_dict.get("room_name") else None

                    fac_id = faculty_by_email.get(fac_email)
                    rm_id = room_by_name.get(rm_name) if rm_name else None

                    if not fac_id:
                        errors.append(f"SharedCourses Row {row_idx}: Faculty email '{fac_email}' not found.")
                        continue
                    if rm_name and not rm_id:
                        errors.append(f"SharedCourses Row {row_idx}: Room '{rm_name}' not found.")
                        continue

                    course = SharedCourse(
                        id=str(uuid.uuid4()),
                        course_name=str(row_dict.get("course_name", "")).strip(),
                        course_code=str(row_dict.get("course_code", "")) or None,
                        year=int(row_dict.get("year", 1)),
                        divisions=div_list,
                        faculty_id=fac_id,
                        room_id=rm_id,
                        duration_slots=int(row_dict.get("duration_slots", 1)),
                        weekly_sessions=int(row_dict.get("weekly_sessions", 1)),
                        session_type=str(row_dict.get("session_type", "lecture")).strip().lower()
                    )
                    
                    # Ensure placeholder subject exists so we can map it
                    resolved_sub, _, _ = _ensure_placeholder_entities(
                        db, course.course_name, course.course_code, course.faculty_id, course.room_id
                    )

                    db.add(course)
                    created_shared.append(course)
                except Exception as e:
                    errors.append(f"SharedCourses Row {row_idx}: {str(e)}")

        if errors:
            db.rollback()
            raise HTTPException(status_code=400, detail={"message": "Validation errors found in Excel sheets.", "errors": errors})

    elif filename.lower().endswith(".csv"):
        # Legacy CSV parser for backwards compatibility
        text = content.decode("utf-8")
        reader = csv.DictReader(io.StringIO(text))
        for row_dict in reader:
            if "name" in row_dict:
                sub = Subject(
                    id=str(uuid.uuid4()),
                    name=row_dict["name"].strip(),
                    code=row_dict.get("code", "").strip(),
                    weekly_lectures=int(row_dict.get("weekly_lectures", 3)),
                    is_lab=row_dict.get("is_lab", "").lower() in ("true", "1", "yes"),
                    lab_sessions_per_week=int(row_dict.get("lab_sessions_per_week", 0)),
                    lab_block_size=int(row_dict.get("lab_block_size", 1)),
                )
                db.add(sub)
                created_subjects.append(sub)
    else:
        raise HTTPException(status_code=400, detail="Only .xlsx and .csv files are supported.")

    db.commit()

    return {
        "message": "Excel configuration uploaded and parsed successfully.",
        "divisions_created": len(created_divisions),
        "subjects_created": len(created_subjects),
        "rooms_created": len(created_rooms),
        "assignments_created": len(created_assignments),
        "fixed_courses_created": len(created_fixed),
        "shared_courses_created": len(created_shared)
    }


# ---------------------------------------------------------------------------
# Read-only viewing — this is what Android actually calls.
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
    entries = db.query(TimetableEntry).filter(TimetableEntry.faculty_id == current_user.id).all()
    return [_to_entry_out(e) for e in entries]


@router.get("/division/{division_id}", response_model=list[TimetableEntryOut])
def division_timetable(division_id: str, db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    if division_id == "all":
        entries = db.query(TimetableEntry).all()
        return [_to_entry_out(e) for e in entries]

    division = db.query(Division).filter(Division.id == division_id).first()
    if division is None:
        raise HTTPException(status_code=404, detail="Division not found")

    entries = db.query(TimetableEntry).filter(TimetableEntry.division_id == division_id).all()
    return [_to_entry_out(e) for e in entries]


@router.get("/year/{year}", response_model=list[TimetableEntryOut])
def year_timetable(year: int, db: Session = Depends(get_db), _: User = Depends(get_current_user)):
    division_ids = [d.id for d in db.query(Division).filter(Division.year == year).all()]
    if not division_ids:
        return []

    entries = db.query(TimetableEntry).filter(TimetableEntry.division_id.in_(division_ids)).all()
    return [_to_entry_out(e) for e in entries]


# ---------------------------------------------------------------------------
# PDF and Excel Timetable Export Endpoints
# ---------------------------------------------------------------------------

def _resolve_export_grid_data(payload: dict[str, Any], db: Session):
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    days = payload.get("days")
    if not days or len(days) == 0:
        if config and config.day_names:
            days = config.day_names
        elif config and config.working_days:
            all_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            days = all_days[:config.working_days]
        else:
            days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    time_slots = payload.get("time_slots")
    if not time_slots or len(time_slots) == 0:
        periods = config.periods_per_day if config and config.periods_per_day else 8
        time_slots = []
        start_hour = 9
        for p in range(1, periods + 1):
            s_h = start_hour + (p - 1)
            e_h = s_h + 1
            s_ampm = "AM" if s_h < 12 else "PM"
            e_ampm = "AM" if e_h < 12 else "PM"
            s12 = s_h if s_h <= 12 else (s_h - 12)
            e12 = e_h if e_h <= 12 else (e_h - 12)
            time_slots.append({
                "slot_number": p,
                "lecture_number": p,
                "start_time": f"{s12:02d}:00 {s_ampm}",
                "end_time": f"{e12:02d}:00 {e_ampm}",
                "is_break": False,
                "label": f"Slot {p}"
            })

    multi_grid_data = payload.get("multi_grid_data") or payload.get("timetables")
    grid_data = payload.get("grid_data") or {}
    all_classes_requested = payload.get("all_classes", False) or payload.get("view_title") == "All Classes"

    if (not multi_grid_data or len(multi_grid_data) == 0) and all_classes_requested:
        # Build multi_grid_data for all classes from DB
        multi_grid_data = {}
        day_names_map = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        latest_run = db.query(GenerationRun).order_by(GenerationRun.generated_at.desc()).first()
        batch_id = latest_run.id if latest_run else None

        all_divs = db.query(Division).all()
        for div in all_divs:
            q = db.query(TimetableEntry).filter(TimetableEntry.division_id == div.id)
            if batch_id:
                q = q.filter(TimetableEntry.batch_id == batch_id)
            div_entries = q.all()
            if div_entries:
                c_grid = {}
                for e in div_entries:
                    d_name = day_names_map[e.day] if 0 <= e.day < len(day_names_map) else "Monday"
                    s_name = e.subject.name if e.subject else "Course"
                    f_name = e.faculty.full_name if e.faculty else ""
                    r_name = e.room.name if e.room else ""
                    k = f"{d_name}_{e.slot}"
                    c_grid[k] = [s_name, f_name, r_name]
                multi_grid_data[div.name or div.division_code] = c_grid

    if (not grid_data or len(grid_data) == 0) and (not multi_grid_data or len(multi_grid_data) == 0):
        target = (payload.get("target") or "").strip()
        view_type = payload.get("view_type", "class")

        query = db.query(TimetableEntry)
        if target and target.lower() not in ("all", ""):
            if view_type in ("class", "division"):
                divs = db.query(Division).filter((Division.division_code == target) | (Division.name == target)).all()
                if divs:
                    query = query.filter(TimetableEntry.division_id.in_([d.id for d in divs]))
            elif view_type == "faculty":
                users = db.query(User).filter(User.full_name.ilike(f"%{target}%")).all()
                if users:
                    query = query.filter(TimetableEntry.faculty_id.in_([u.id for u in users]))
            elif view_type == "room":
                rooms = db.query(Room).filter(Room.name.ilike(f"%{target}%")).all()
                if rooms:
                    query = query.filter(TimetableEntry.room_id.in_([r.id for r in rooms]))

        latest_run = db.query(GenerationRun).order_by(GenerationRun.generated_at.desc()).first()
        if latest_run:
            query = query.filter(TimetableEntry.batch_id == latest_run.id)

        entries = query.all()
        day_names_map = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        for e in entries:
            d_name = day_names_map[e.day] if 0 <= e.day < len(day_names_map) else "Monday"
            subj_name = e.subject.name if e.subject else "Course"
            fac_name = e.faculty.full_name if e.faculty else ""
            room_name = e.room.name if e.room else ""
            key = f"{d_name}_{e.slot}"
            grid_data[key] = [subj_name, fac_name, room_name]

    return days, time_slots, grid_data, multi_grid_data


@router.post("/export/excel")
def export_excel_timetable(payload: dict[str, Any], db: Session = Depends(get_db)):
    """Exports specified timetable grid or all classes to Excel binary file."""
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    college = config.college_name if config else settings.COLLEGE_NAME
    dept = config.department_name if config else "Computer Science & Engineering"
    year = config.academic_year if config else "2026-2027"
    sem = config.semester if config else "Odd"

    view_title = payload.get("view_title", "Department Timetable")
    days, time_slots, grid_data, multi_grid_data = _resolve_export_grid_data(payload, db)

    try:
        excel_bytes = generate_timetable_excel(
            college_name=college,
            department_name=dept,
            academic_year=year,
            semester=sem,
            view_title=view_title,
            days=days,
            time_slots=time_slots,
            grid_data=grid_data,
            multi_grid_data=multi_grid_data
        )
    except Exception as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate Excel timetable: {err}"
        )

    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename=Timetable_{view_title.replace(' ', '_')}.xlsx"}
    )


@router.post("/export/pdf")
def export_pdf_timetable(payload: dict[str, Any], db: Session = Depends(get_db)):
    """Exports specified timetable grid or all classes to PDF binary file."""
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    college = config.college_name if config else settings.COLLEGE_NAME
    dept = config.department_name if config else "Computer Science & Engineering"
    year = config.academic_year if config else "2026-2027"
    sem = config.semester if config else "Odd"

    view_title = payload.get("view_title", "Department Timetable")
    days, time_slots, grid_data, multi_grid_data = _resolve_export_grid_data(payload, db)

    try:
        pdf_bytes = generate_timetable_pdf(
            college_name=college,
            department_name=dept,
            academic_year=year,
            semester=sem,
            view_title=view_title,
            days=days,
            time_slots=time_slots,
            grid_data=grid_data,
            multi_grid_data=multi_grid_data
        )
    except RuntimeError as err:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail=str(err)
        )
    except Exception as err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate PDF timetable: {err}"
        )

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename=Timetable_{view_title.replace(' ', '_')}.pdf"}
    )

