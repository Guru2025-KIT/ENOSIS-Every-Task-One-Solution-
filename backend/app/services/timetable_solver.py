"""
The actual timetable generation engine — Google OR-Tools CP-SAT.

WHAT THIS IS (beginner explanation): instead of writing "if Monday 9am is
free, put DBMS there" logic by hand, we describe the RULES ("no faculty
teaches two classes at once," "no room hosts two classes at once," "a lab
needs 2 consecutive slots") to a constraint solver, and it searches for an
assignment of subjects -> days -> slots -> rooms that satisfies every rule
simultaneously. This is fundamentally different from CRUD code — it's a
search problem, not a lookup.

DELIBERATELY FRAMEWORK-AGNOSTIC: this file imports nothing from FastAPI or
SQLAlchemy. It takes plain Pydantic objects in, returns plain Pydantic
objects out. That's what let us unit-test it (tests/test_timetable_solver.py)
with zero database or web server involved, and it's what let us build this
module before Auth even existed if we'd wanted to (see the earlier
discussion about module ordering).

CURRENT SCOPE / KNOWN LIMITATIONS (documented on purpose, not hidden):
- Labs are constrained to consecutive slots WITHIN a single day — a lab
  can't span across days, which is standard for timetabling but worth
  stating explicitly.
- "max_lectures_per_day_per_faculty" counts SESSIONS, not slots — a lab
  session counts as 1 even though it occupies 2 slots, since it's one
  teaching commitment.
- No support yet for "preferred slots" or soft constraints (e.g. "faculty
  X prefers mornings") — everything here is a hard constraint. Soft
  constraints (weighted objective) are a natural next enhancement once
  this hard-constraint version is proven.
- No cross-division shared electives yet (one division per occurrence).
"""
import time
from dataclasses import dataclass, field

from ortools.sat.python import cp_model

from app.models.academic import RoomType
from app.schemas.timetable import (
    TimetableGenerationRequest,
    TimetableGenerationResult,
    TimetableEntryResult,
)


@dataclass
class _Occurrence:
    """One lecture or lab session that needs to be placed on the timetable."""
    division_id: str
    subject_id: str
    faculty_id: str
    duration: int  # 1 for a lecture, subject.lab_block_size for a lab
    is_lab: bool
    room_type_needed: RoomType


@dataclass
class _Option:
    """One feasible (day, start_slot, room) placement for an occurrence."""
    day: int
    start_slot: int
    room_id: str
    slots: list  # list of (day, slot) tuples this option occupies


def generate_timetable(request: TimetableGenerationRequest) -> TimetableGenerationResult:
    start_time = time.monotonic()

    divisions_by_id = {d.id: d for d in request.divisions}
    rooms = request.rooms
    unavailable = {(u.faculty_id, u.day, u.slot) for u in request.unavailability}

    # --- Step 1: expand assignments into concrete occurrences -------------
    subjects_by_id = {s.id: s for s in request.subjects}
    occurrences: list[_Occurrence] = []
    for assignment in request.assignments:
        subject = subjects_by_id.get(assignment.subject_id)
        if subject is None:
            continue  # ignore assignments referencing an unknown subject

        for _ in range(subject.weekly_lectures):
            occurrences.append(_Occurrence(
                division_id=assignment.division_id,
                subject_id=subject.id,
                faculty_id=assignment.faculty_id,
                duration=1,
                is_lab=False,
                room_type_needed=RoomType.LECTURE,
            ))

        if subject.is_lab:
            for _ in range(subject.lab_sessions_per_week):
                occurrences.append(_Occurrence(
                    division_id=assignment.division_id,
                    subject_id=subject.id,
                    faculty_id=assignment.faculty_id,
                    duration=subject.lab_block_size,
                    is_lab=True,
                    room_type_needed=RoomType.LAB,
                ))

    if not occurrences:
        return TimetableGenerationResult(
            status="INFEASIBLE",
            entries=[],
            solve_time_seconds=0.0,
            message="No lecture/lab sessions to schedule — check weekly_lectures / "
                    "lab_sessions_per_week on your subjects and that assignments exist.",
        )

    # --- Step 2: build the feasible-option list for every occurrence ------
    all_options: list[list[_Option]] = []
    for occ in occurrences:
        division = divisions_by_id.get(occ.division_id)
        options: list[_Option] = []
        if division is None:
            all_options.append(options)  # empty -> guaranteed infeasible, reported below
            continue

        candidate_rooms = [
            r for r in rooms
            if r.type == occ.room_type_needed and r.capacity >= division.strength
        ]

        for day in range(request.working_days):
            last_valid_start = request.periods_per_day - occ.duration
            for start_slot in range(last_valid_start + 1):
                slots = [(day, start_slot + i) for i in range(occ.duration)]

                if any((occ.faculty_id, d, s) in unavailable for d, s in slots):
                    continue

                for room in candidate_rooms:
                    options.append(_Option(day=day, start_slot=start_slot, room_id=room.id, slots=slots))

        all_options.append(options)

    # If ANY occurrence has zero feasible options, the whole problem is
    # infeasible before we even hand it to the solver — report that clearly
    # instead of making CP-SAT spend time discovering the obvious.
    for occ, options in zip(occurrences, all_options):
        if not options:
            return TimetableGenerationResult(
                status="INFEASIBLE",
                entries=[],
                solve_time_seconds=round(time.monotonic() - start_time, 3),
                message=(
                    f"No feasible slot/room exists for subject {occ.subject_id} "
                    f"(division {occ.division_id}) — check that a compatible room "
                    f"(type={occ.room_type_needed.value}, capacity) exists and that "
                    f"the assigned faculty isn't marked unavailable for every slot."
                ),
            )

    # --- Step 3: build the CP-SAT model ------------------------------------
    model = cp_model.CpModel()

    # one BoolVar per (occurrence, option)
    choice_vars: list[list[cp_model.IntVar]] = []
    for i, options in enumerate(all_options):
        choice_vars.append([model.NewBoolVar(f"occ{i}_opt{j}") for j in range(len(options))])
        model.Add(sum(choice_vars[i]) == 1)  # each occurrence scheduled exactly once

    # Group variables by (resource, day, slot) so we can cap each cell at 1
    faculty_cells: dict[tuple, list[cp_model.IntVar]] = {}
    division_cells: dict[tuple, list[cp_model.IntVar]] = {}
    room_cells: dict[tuple, list[cp_model.IntVar]] = {}

    for i, (occ, options) in enumerate(zip(occurrences, all_options)):
        for j, option in enumerate(options):
            var = choice_vars[i][j]
            for day, slot in option.slots:
                faculty_cells.setdefault((occ.faculty_id, day, slot), []).append(var)
                division_cells.setdefault((occ.division_id, day, slot), []).append(var)
                room_cells.setdefault((option.room_id, day, slot), []).append(var)

    for cell_vars in faculty_cells.values():
        if len(cell_vars) > 1:
            model.AddAtMostOne(cell_vars)
    for cell_vars in division_cells.values():
        if len(cell_vars) > 1:
            model.AddAtMostOne(cell_vars)
    for cell_vars in room_cells.values():
        if len(cell_vars) > 1:
            model.AddAtMostOne(cell_vars)

    # Optional: cap sessions/day per faculty (counts SESSIONS, not slots)
    if request.max_lectures_per_day_per_faculty is not None:
        faculty_ids = {occ.faculty_id for occ in occurrences}
        for faculty_id in faculty_ids:
            for day in range(request.working_days):
                day_vars = [
                    choice_vars[i][j]
                    for i, (occ, options) in enumerate(zip(occurrences, all_options))
                    if occ.faculty_id == faculty_id
                    for j, option in enumerate(options)
                    if option.day == day
                ]
                if day_vars:
                    model.Add(sum(day_vars) <= request.max_lectures_per_day_per_faculty)

    # --- Step 4: solve ------------------------------------------------------
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = request.time_limit_seconds
    solver.parameters.num_search_workers = 8

    status = solver.Solve(model)
    solve_time = round(time.monotonic() - start_time, 3)

    status_name = solver.StatusName(status)  # "OPTIMAL" | "FEASIBLE" | "INFEASIBLE" | ...

    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return TimetableGenerationResult(
            status=status_name,
            entries=[],
            solve_time_seconds=solve_time,
            message="No valid timetable exists for this input within the time limit. "
                    "Try relaxing constraints (more rooms, fewer unavailability entries, "
                    "or a longer time_limit_seconds).",
        )

    # --- Step 5: extract the chosen option for each occurrence -------------
    entries: list[TimetableEntryResult] = []
    for i, (occ, options) in enumerate(zip(occurrences, all_options)):
        for j, option in enumerate(options):
            if solver.Value(choice_vars[i][j]) == 1:
                for day, slot in option.slots:
                    entries.append(TimetableEntryResult(
                        division_id=occ.division_id,
                        subject_id=occ.subject_id,
                        faculty_id=occ.faculty_id,
                        room_id=option.room_id,
                        day=day,
                        slot=slot,
                        is_lab_block=occ.is_lab,
                    ))
                break

    return TimetableGenerationResult(
        status=status_name,
        entries=entries,
        solve_time_seconds=solve_time,
        message=None,
    )
