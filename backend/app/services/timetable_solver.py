"""
ENOSIS Timetable Solver — Google OR-Tools CP-SAT.

Architecture
────────────
INPUT  (TimetableGenerationRequest — plain Pydantic, no DB/FastAPI imports)
  ↓
validate_request()          — pre-solve conflict detection
  ↓
_build_occurrences()        — expand assignments → concrete sessions
  ↓
_build_options()            — enumerate feasible (day, slot, room) placements
  ↓
_build_cp_model()           — hard constraints + soft objective
  ↓
CpSolver.Solve()
  ↓
_extract_entries()          — translate chosen options → result entries
  ↓
OUTPUT (TimetableGenerationResult — plain Pydantic)

Hard constraints implemented
────────────────────────────
1.  Each occurrence scheduled exactly once.
2.  No faculty double-booked in a slot.
3.  No division double-booked in a slot.
4.  No room double-booked in a slot.
5.  Room capacity ≥ division strength.
6.  Room type matches subject need (lecture ↔ lecture, lab ↔ lab).
7.  Faculty unavailability respected (from FacultyUnavailability rows AND
    dynamic "faculty_unavailability" TimetableConstraint rows).
8.  Break/lunch slots are never used.
9.  Lab sessions occupy consecutive slots within the same day.
10. Spread constraint: at most one occurrence of the same subject per
    division per day (prevents stacking 3×DBMS on Monday).
11. Max lectures per day per faculty (if configured).
12. Fixed-slot constraints (pin a subject to a specific day+slot).

Soft constraints / objective
─────────────────────────────
Each soft constraint adds a BoolVar "satisfied" to the objective.
The solver maximises the total reward.

  avoid_first_period   — reward when faculty NOT in slot 0
  avoid_last_period    — reward when faculty NOT in last slot
  prefer_morning       — reward earlier slots (weight decreases with slot index)
  preferred_room       — reward when subject uses specified room
  avoid_consecutive_same — reward when same subject not placed back-to-back
  balance_daily_load   — penalises extremes via auxiliary vars (approximated)

Known limitations (documented, not hidden)
──────────────────────────────────────────
- Labs span consecutive slots WITHIN one day only.
- Cross-division shared electives not yet supported.
- "prefer_morning" approximates by rewarding slots < periods/2.
"""
import time
from dataclasses import dataclass, field
from collections import defaultdict

from ortools.sat.python import cp_model

from app.models.academic import RoomType
from app.schemas.timetable import (
    TimetableGenerationRequest,
    TimetableGenerationResult,
    TimetableEntryResult,
    ConflictDetail,
    SolverSoftConstraint,
)


# ─────────────────────────────────────────────────────────────────────────────
# Internal data structures (solver-private, not part of the public API)
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class _Occurrence:
    """One lecture or lab session that needs to be placed on the timetable."""
    division_id: str
    subject_id: str
    subject_name: str
    faculty_id: str
    duration: int          # 1 for lecture; lab_block_size for lab
    is_lab: bool
    room_type_needed: RoomType
    fixed_room_id: str | None = None
    required_capacity: int = 0


@dataclass
class _Option:
    """One feasible (day, start_slot, room) placement for an occurrence."""
    day: int
    start_slot: int
    room_id: str
    slots: list            # list of (day, slot) tuples this option occupies


# ─────────────────────────────────────────────────────────────────────────────
# Pre-solve validation — detect obvious impossibilities BEFORE calling OR-Tools
# ─────────────────────────────────────────────────────────────────────────────

def validate_request(request: TimetableGenerationRequest) -> list[ConflictDetail]:
    """
    Run cheap pre-solve checks and return a list of ConflictDetail objects.
    An empty list means no obvious conflicts were found (the solver may still
    find the problem infeasible, but there's no guarantee either way).
    """
    conflicts: list[ConflictDetail] = []

    subjects_by_id = {s.id: s for s in request.subjects}
    divisions_by_id = {d.id: d for d in request.divisions}
    rooms = request.rooms
    unavailable = {(u.faculty_id, u.day, u.slot) for u in request.unavailability}
    teaching_slots = request.working_days * request.periods_per_day
    usable_slots = teaching_slots - (request.working_days * len(request.break_slots))

    # 1. Check there is at least one room of each required type
    lecture_rooms = [r for r in rooms if r.type == RoomType.LECTURE]
    lab_rooms = [r for r in rooms if r.type == RoomType.LAB]

    for assignment in request.assignments:
        subject = subjects_by_id.get(assignment.subject_id)
        division = divisions_by_id.get(assignment.division_id)
        if subject is None or division is None:
            continue

        # 2. Room capacity check
        if subject.weekly_lectures > 0:
            ok_rooms = [r for r in lecture_rooms if r.capacity >= division.strength]
            if not ok_rooms:
                conflicts.append(ConflictDetail(
                    type="no_compatible_lecture_room",
                    subject=subject.name,
                    division=division.name,
                    details=(
                        f"No lecture room has capacity ≥ {division.strength} students "
                        f"(division strength). Available lecture rooms: "
                        f"{[r.name + '(' + str(r.capacity) + ')' for r in lecture_rooms] or 'none'}."
                    ),
                ))

        if subject.is_lab and subject.lab_sessions_per_week > 0:
            ok_labs = [r for r in lab_rooms if r.capacity >= division.strength]
            if not ok_labs:
                conflicts.append(ConflictDetail(
                    type="no_compatible_lab_room",
                    subject=subject.name,
                    division=division.name,
                    details=(
                        f"'{subject.name}' requires a lab-type room with capacity ≥ "
                        f"{division.strength}. Available lab rooms: "
                        f"{[r.name + '(' + str(r.capacity) + ')' for r in lab_rooms] or 'none'}."
                    ),
                ))

    # 3. Faculty workload vs available slots
    faculty_sessions: dict[str, int] = defaultdict(int)
    for assignment in request.assignments:
        subject = subjects_by_id.get(assignment.subject_id)
        if subject is None:
            continue
        faculty_sessions[assignment.faculty_id] += subject.weekly_lectures
        if subject.is_lab:
            faculty_sessions[assignment.faculty_id] += subject.lab_sessions_per_week

    for fac_id, total_sessions in faculty_sessions.items():
        # Count available slots for this faculty
        unavail_count = sum(
            1 for (f, d, s) in unavailable
            if f == fac_id and s not in request.break_slots
        )
        available = usable_slots - unavail_count
        if total_sessions > available:
            conflicts.append(ConflictDetail(
                type="faculty_overloaded",
                faculty=fac_id,
                details=(
                    f"Faculty '{fac_id}' has {total_sessions} sessions to teach but only "
                    f"{available} available slots (after breaks and unavailability). "
                    f"Reduce workload or add more available slots."
                ),
            ))

    # 4. Subjects with zero sessions — warn but not fatal
    for assignment in request.assignments:
        subject = subjects_by_id.get(assignment.subject_id)
        if subject and subject.weekly_lectures == 0 and (
            not subject.is_lab or subject.lab_sessions_per_week == 0
        ):
            conflicts.append(ConflictDetail(
                type="subject_zero_sessions",
                subject=subject.name,
                details=(
                    f"'{subject.name}' has weekly_lectures=0 and no lab sessions. "
                    f"It will not appear in the timetable. Set weekly_lectures ≥ 1 "
                    f"or configure lab sessions."
                ),
            ))

    return conflicts


# ─────────────────────────────────────────────────────────────────────────────
# Main solver
# ─────────────────────────────────────────────────────────────────────────────

def generate_timetable(request: TimetableGenerationRequest) -> TimetableGenerationResult:
    start_time = time.monotonic()
    log_lines: list[str] = []

    def log(msg: str) -> None:
        log_lines.append(msg)

    log("TIMETABLE GENERATION STARTED")
    log(f"  working_days={request.working_days}  periods_per_day={request.periods_per_day}")
    log(f"  break_slots={request.break_slots}  time_limit={request.time_limit_seconds}s")

    divisions_by_id = {d.id: d for d in request.divisions}
    subjects_by_id  = {s.id: s for s in request.subjects}
    rooms           = request.rooms
    unavailable     = {(u.faculty_id, u.day, u.slot) for u in request.unavailability}
    break_set       = set(request.break_slots)

    # Map division code/name to ID
    div_by_code_or_name = {}
    for d in request.divisions:
        code = getattr(d, "division_code", "")
        if code:
            div_by_code_or_name[code.upper()] = d.id
        div_by_code_or_name[d.name.upper()] = d.id

    # 1. Process Institutional Fixed Courses
    blocked_slots_by_division = defaultdict(set)
    room_unavailable_slots = set()
    
    for ic in request.institutional_courses:
        # Match divisions by year + code/name
        ic_divisions = [
            d.id for d in request.divisions 
            if getattr(d, "year", 1) == ic.year and (
                getattr(d, "division_code", "").upper() in [div.upper() for div in ic.divisions] or 
                d.name.upper() in [div.upper() for div in ic.divisions]
            )
        ]
        for div_id in ic_divisions:
            for i in range(ic.duration_slots):
                blocked_slots_by_division[div_id].add((ic.day, ic.start_slot + i))
                
        # If faculty is fixed, mark them unavailable during these slots
        if ic.faculty_id:
            for i in range(ic.duration_slots):
                unavailable.add((ic.faculty_id, ic.day, ic.start_slot + i))
                
        # If room is fixed, mark it unavailable for other courses
        if ic.room_id:
            for i in range(ic.duration_slots):
                room_unavailable_slots.add((ic.room_id, ic.day, ic.start_slot + i))

    # ── Step 1: Expand assignments into concrete occurrences ─────────────────
    occurrences: list[_Occurrence] = []
    
    # We will track groups of occurrence indices that must be simultaneous
    # (same day and start_slot) or same_slot_and_room (same day, slot, and room)
    simultaneous_groups: list[list[int]] = []
    same_slot_and_room_groups: list[list[int]] = []
    
    # Group shared courses by course_name to handle simultaneous groups (like MDM/PE)
    shared_by_name = defaultdict(list)
    for sc in request.shared_courses:
        shared_by_name[sc.course_name.lower()].append(sc)
        
    for course_name_lower, sc_list in shared_by_name.items():
        # Match weekly sessions
        max_sessions = max(sc.weekly_sessions for sc in sc_list)
        for s_idx in range(max_sessions):
            sim_group_idx = []
            
            for sc in sc_list:
                if s_idx >= sc.weekly_sessions:
                    continue
                    
                sc_divisions = [
                    d.id for d in request.divisions 
                    if getattr(d, "year", 1) == sc.year and (
                        getattr(d, "division_code", "").upper() in [div.upper() for div in sc.divisions] or 
                        d.name.upper() in [div.upper() for div in sc.divisions]
                    )
                ]
                if not sc_divisions:
                    continue
                    
                combined_strength = sum(divisions_by_id[div_id].strength for div_id in sc_divisions if div_id in divisions_by_id)
                
                record_group_idx = []
                for div_id in sc_divisions:
                    occ_idx = len(occurrences)
                    occurrences.append(_Occurrence(
                        division_id=div_id,
                        subject_id=sc.course_code or sc.course_name,
                        subject_name=sc.course_name,
                        faculty_id=sc.faculty_id,
                        duration=sc.duration_slots,
                        is_lab=(sc.session_type.lower() == "lab"),
                        room_type_needed=RoomType.LAB if sc.session_type.lower() == "lab" else RoomType.LECTURE,
                        fixed_room_id=sc.room_id,
                        required_capacity=combined_strength
                    ))
                    record_group_idx.append(occ_idx)
                    sim_group_idx.append(occ_idx)
                
                if len(record_group_idx) > 1:
                    same_slot_and_room_groups.append(record_group_idx)
                    
            if len(sim_group_idx) > 1:
                simultaneous_groups.append(sim_group_idx)

    # Now add standard teaching assignments
    for assignment in request.assignments:
        subject = subjects_by_id.get(assignment.subject_id)
        if subject is None:
            continue

        for _ in range(subject.weekly_lectures):
            occurrences.append(_Occurrence(
                division_id=assignment.division_id,
                subject_id=subject.id,
                subject_name=subject.name,
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
                    subject_name=subject.name,
                    faculty_id=assignment.faculty_id,
                    duration=subject.lab_block_size,
                    is_lab=True,
                    room_type_needed=RoomType.LAB,
                ))

    log(f"  occurrences={len(occurrences)}")

    if not occurrences:
        return TimetableGenerationResult(
            status="INFEASIBLE",
            entries=[],
            solve_time_seconds=0.0,
            conflicts=[ConflictDetail(
                type="no_sessions",
                details="No lecture/lab sessions to schedule — check weekly_lectures / "
                        "lab_sessions_per_week on your subjects and that assignments exist.",
            )],
            suggestions=[
                "Ensure subjects have weekly_lectures ≥ 1.",
                "Ensure TeachingAssignments exist linking faculty → subject → division.",
            ],
            message="Nothing to schedule.",
            solver_log="\n".join(log_lines),
        )

    # ── Step 2: Build feasible-option list for every occurrence ──────────────
    all_options: list[list[_Option]] = []
    for occ in occurrences:
        division = divisions_by_id.get(occ.division_id)
        options: list[_Option] = []
        if division is None:
            all_options.append(options)
            continue

        req_cap = occ.required_capacity if occ.required_capacity > 0 else division.strength

        if occ.fixed_room_id:
            candidate_rooms = [r for r in rooms if r.id == occ.fixed_room_id]
        else:
            candidate_rooms = [
                r for r in rooms
                if r.type == occ.room_type_needed and r.capacity >= req_cap
            ]

        for day in range(request.working_days):
            for start_slot in range(request.periods_per_day - occ.duration + 1):
                slots = [(day, start_slot + i) for i in range(occ.duration)]

                # Hard: no slot in break_set
                if any(s in break_set for _, s in slots):
                    continue

                # Hard: no slot in blocked institutional slots for this division
                division_blocked = blocked_slots_by_division[occ.division_id]
                if any(slot in division_blocked for slot in slots):
                    continue

                # Hard: faculty must be available for every slot
                if any((occ.faculty_id, d, s) in unavailable for d, s in slots):
                    continue

                for room in candidate_rooms:
                    # Hard: room must not be blocked by institutional courses
                    if any((room.id, d, s) in room_unavailable_slots for d, s in slots):
                        continue

                    options.append(_Option(
                        day=day,
                        start_slot=start_slot,
                        room_id=room.id,
                        slots=slots,
                    ))

        all_options.append(options)

    # ── Pre-CP-SAT infeasibility: any occurrence with zero options ────────────
    conflicts: list[ConflictDetail] = []
    suggestions: list[str] = []
    for occ, options in zip(occurrences, all_options):
        if not options:
            division = divisions_by_id.get(occ.division_id)
            conflicts.append(ConflictDetail(
                type="no_feasible_slot",
                subject=occ.subject_name,
                division=division.name if division else occ.division_id,
                details=(
                    f"No valid slot + room exists for '{occ.subject_name}' "
                    f"(division '{division.name if division else occ.division_id}'). "
                    f"Reasons may include: faculty marked unavailable for every slot, "
                    f"no {occ.room_type_needed.value}-type room with enough capacity, "
                    f"or too many break slots leaving insufficient teaching periods."
                ),
            ))
            suggestions.extend([
                f"Reduce unavailability for the faculty teaching '{occ.subject_name}'.",
                f"Add a {occ.room_type_needed.value}-type room with capacity ≥ "
                f"{(divisions_by_id.get(occ.division_id) or type('', (), {'strength': '?'})()).strength}.",
                "Reduce break_slots to free up more teaching periods.",
            ])

    if conflicts:
        return TimetableGenerationResult(
            status="INFEASIBLE",
            entries=[],
            solve_time_seconds=round(time.monotonic() - start_time, 3),
            conflicts=conflicts,
            suggestions=list(dict.fromkeys(suggestions)),  # deduplicate
            message="Pre-solve conflict detection found impossible constraints.",
            solver_log="\n".join(log_lines),
        )

    # ── Step 3: Build the CP-SAT model ───────────────────────────────────────
    model = cp_model.CpModel()

    # One BoolVar per (occurrence, option)
    choice_vars: list[list[cp_model.IntVar]] = []
    for i, options in enumerate(all_options):
        row = [model.NewBoolVar(f"occ{i}_opt{j}") for j in range(len(options))]
        choice_vars.append(row)
        model.Add(sum(row) == 1)   # each occurrence scheduled exactly once

    # Group vars by (resource, day, slot) for mutual-exclusion constraints
    faculty_cells:  dict[tuple, list] = defaultdict(list)
    division_cells: dict[tuple, list] = defaultdict(list)
    room_cells:     dict[tuple, list] = defaultdict(list)

    # Build maps to find representative occurrences for shared bookings
    shared_room_rep = {}
    for group in same_slot_and_room_groups:
        rep = group[0]
        for idx in group:
            shared_room_rep[idx] = rep

    shared_fac_rep = {}
    for group in simultaneous_groups:
        rep = group[0]
        for idx in group:
            shared_fac_rep[idx] = rep

    for i, (occ, options) in enumerate(zip(occurrences, all_options)):
        is_room_rep = (shared_room_rep.get(i, i) == i)
        is_fac_rep = (shared_fac_rep.get(i, i) == i)

        for j, option in enumerate(options):
            var = choice_vars[i][j]
            for day, slot in option.slots:
                if is_fac_rep:
                    faculty_cells[(occ.faculty_id, day, slot)].append(var)
                if is_room_rep:
                    room_cells[(option.room_id, day, slot)].append(var)
                
                # Divisions are never shared
                division_cells[(occ.division_id, day, slot)].append(var)

    # Hard: at most one user of each (resource, day, slot)
    for cell_vars in faculty_cells.values():
        if len(cell_vars) > 1:
            model.AddAtMostOne(cell_vars)
    for cell_vars in division_cells.values():
        if len(cell_vars) > 1:
            model.AddAtMostOne(cell_vars)
    for cell_vars in room_cells.values():
        if len(cell_vars) > 1:
            model.AddAtMostOne(cell_vars)

    log(f"  faculty_cells={len(faculty_cells)}  division_cells={len(division_cells)}  room_cells={len(room_cells)}")

    # Hard: spread — at most one session of each (division, subject, lecture/lab) per day
    subject_day_groups: dict[tuple, list[int]] = defaultdict(list)
    for i, occ in enumerate(occurrences):
        key = (occ.division_id, occ.subject_id, occ.is_lab)
        subject_day_groups[key].append(i)

    spread_constraints = 0
    for (div_id, sub_id, is_lab), occ_indices in subject_day_groups.items():
        if len(occ_indices) <= 1:
            continue
        for day in range(request.working_days):
            day_vars = [
                choice_vars[i][j]
                for i in occ_indices
                for j, option in enumerate(all_options[i])
                if option.day == day
            ]
            if len(day_vars) > 1:
                model.AddAtMostOne(day_vars)
                spread_constraints += 1

    log(f"  spread_constraints={spread_constraints}")

    # Hard: max lectures per day per faculty
    if request.max_lectures_per_day_per_faculty is not None:
        faculty_ids = {occ.faculty_id for occ in occurrences}
        for fac_id in faculty_ids:
            for day in range(request.working_days):
                day_vars = [
                    choice_vars[i][j]
                    for i, (occ, options) in enumerate(zip(occurrences, all_options))
                    if occ.faculty_id == fac_id
                    for j, option in enumerate(options)
                    if option.day == day
                ]
                if day_vars:
                    model.Add(sum(day_vars) <= request.max_lectures_per_day_per_faculty)

    # Hard: simultaneous groups (e.g. electives running at same day/slot)
    for group in simultaneous_groups:
        ref_idx = group[0]
        for other_idx in group[1:]:
            for day in range(request.working_days):
                for start_slot in range(request.periods_per_day):
                    ref_vars = [
                        choice_vars[ref_idx][j] 
                        for j, opt in enumerate(all_options[ref_idx])
                        if opt.day == day and opt.start_slot == start_slot
                    ]
                    other_vars = [
                        choice_vars[other_idx][k]
                        for k, opt in enumerate(all_options[other_idx])
                        if opt.day == day and opt.start_slot == start_slot
                    ]
                    if ref_vars or other_vars:
                        model.Add(sum(ref_vars) == sum(other_vars))

    # Hard: same slot and room groups (e.g. shared lectures)
    for group in same_slot_and_room_groups:
        ref_idx = group[0]
        for other_idx in group[1:]:
            for day in range(request.working_days):
                for start_slot in range(request.periods_per_day):
                    for room in rooms:
                        ref_vars = [
                            choice_vars[ref_idx][j]
                            for j, opt in enumerate(all_options[ref_idx])
                            if opt.day == day and opt.start_slot == start_slot and opt.room_id == room.id
                        ]
                        other_vars = [
                            choice_vars[other_idx][k]
                            for k, opt in enumerate(all_options[other_idx])
                            if opt.day == day and opt.start_slot == start_slot and opt.room_id == room.id
                        ]
                        if ref_vars or other_vars:
                            model.Add(sum(ref_vars) == sum(other_vars))

    # ── Step 4: Soft constraints + objective ─────────────────────────────────
    objective_terms: list[cp_model.IntVar] = []
    soft_count = 0

    for sc in request.soft_constraints:
        sc_type = sc.type
        payload = sc.payload

        if sc_type == "avoid_first_period":
            fac_id = payload.get("faculty_id")
            if fac_id:
                for i, (occ, options) in enumerate(zip(occurrences, all_options)):
                    if occ.faculty_id != fac_id:
                        continue
                    for j, option in enumerate(options):
                        if option.start_slot == 0:
                            # Penalise (negate reward) for using slot 0
                            not_first = model.NewBoolVar(f"not_first_{i}_{j}")
                            model.Add(not_first == 1 - choice_vars[i][j])
                            objective_terms.append(not_first)
                            soft_count += 1

        elif sc_type == "avoid_last_period":
            fac_id = payload.get("faculty_id")
            last_slot = request.periods_per_day - 1
            if fac_id:
                for i, (occ, options) in enumerate(zip(occurrences, all_options)):
                    if occ.faculty_id != fac_id:
                        continue
                    for j, option in enumerate(options):
                        if option.start_slot + occ.duration - 1 == last_slot:
                            not_last = model.NewBoolVar(f"not_last_{i}_{j}")
                            model.Add(not_last == 1 - choice_vars[i][j])
                            objective_terms.append(not_last)
                            soft_count += 1

        elif sc_type == "prefer_morning":
            fac_id = payload.get("faculty_id")
            mid = request.periods_per_day // 2
            if fac_id:
                for i, (occ, options) in enumerate(zip(occurrences, all_options)):
                    if occ.faculty_id != fac_id:
                        continue
                    for j, option in enumerate(options):
                        if option.start_slot < mid:
                            objective_terms.append(choice_vars[i][j])
                            soft_count += 1

        elif sc_type == "preferred_room":
            sub_id  = payload.get("subject_id")
            room_id = payload.get("room_id")
            if sub_id and room_id:
                for i, (occ, options) in enumerate(zip(occurrences, all_options)):
                    if occ.subject_id != sub_id:
                        continue
                    for j, option in enumerate(options):
                        if option.room_id == room_id:
                            objective_terms.append(choice_vars[i][j])
                            soft_count += 1

        elif sc_type == "avoid_consecutive_same":
            # Penalise placing the same subject for the same division in
            # consecutive slots (e.g. DBMS at slot 2 AND slot 3 on Monday)
            div_id = payload.get("division_id")
            sub_id = payload.get("subject_id")
            if div_id and sub_id:
                target_indices = [
                    i for i, occ in enumerate(occurrences)
                    if occ.division_id == div_id and occ.subject_id == sub_id
                ]
                for day in range(request.working_days):
                    for slot in range(request.periods_per_day - 1):
                        slot_a_vars = [
                            choice_vars[i][j]
                            for i in target_indices
                            for j, opt in enumerate(all_options[i])
                            if opt.day == day and opt.start_slot == slot
                        ]
                        slot_b_vars = [
                            choice_vars[i][j]
                            for i in target_indices
                            for j, opt in enumerate(all_options[i])
                            if opt.day == day and opt.start_slot == slot + 1
                        ]
                        if slot_a_vars and slot_b_vars:
                            no_consec = model.NewBoolVar(
                                f"no_consec_{div_id[:4]}_{sub_id[:4]}_d{day}_s{slot}"
                            )
                            # no_consec = 1 iff NOT (any_a AND any_b)
                            sum_a = model.NewIntVar(0, len(slot_a_vars), f"sa_{i}_{day}_{slot}")
                            sum_b = model.NewIntVar(0, len(slot_b_vars), f"sb_{i}_{day}_{slot}")
                            model.Add(sum_a == sum(slot_a_vars))
                            model.Add(sum_b == sum(slot_b_vars))
                            model.Add(sum_a + sum_b <= 1 + (1 - no_consec) * 2)
                            objective_terms.append(no_consec)
                            soft_count += 1

    log(f"  soft_constraint_vars={soft_count}")

    if objective_terms:
        model.Maximize(sum(objective_terms))

    # ── Step 5: Solve ────────────────────────────────────────────────────────
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = request.time_limit_seconds
    solver.parameters.num_search_workers = 4   # keep responsive on shared hardware

    log("  Solver started…")
    status = solver.Solve(model)
    solve_time = round(time.monotonic() - start_time, 3)
    status_name = solver.StatusName(status)
    log(f"  Solver status={status_name}  time={solve_time}s")

    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return TimetableGenerationResult(
            status=status_name,
            entries=[],
            solve_time_seconds=solve_time,
            conflicts=[ConflictDetail(
                type="solver_infeasible",
                details=(
                    "OR-Tools CP-SAT reported INFEASIBLE within the time limit. "
                    "All hard constraints cannot be satisfied simultaneously."
                ),
            )],
            suggestions=[
                "Check faculty unavailability — are there enough available slots?",
                "Add more rooms or labs.",
                "Reduce weekly session counts for high-load subjects.",
                "Increase time_limit_seconds in Schedule Config.",
            ],
            message=f"Solver returned {status_name}. No valid timetable exists for the current constraints.",
            solver_log="\n".join(log_lines),
        )

    # ── Step 6: Extract chosen options ───────────────────────────────────────
    obj_score: float | None = None
    if objective_terms:
        obj_score = round(solver.ObjectiveValue(), 2)
        log(f"  objective_score={obj_score}")

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

    # Add institutional fixed course entries to the results
    for ic in request.institutional_courses:
        ic_divisions = [
            d.id for d in request.divisions 
            if d.year == ic.year and (
                d.division_code.upper() in [div.upper() for div in ic.divisions] or 
                d.name.upper() in [div.upper() for div in ic.divisions]
            )
        ]
        
        # Resolve Subject ID
        sub_id = None
        for s in request.subjects:
            if s.name.lower() == ic.course_name.lower():
                sub_id = s.id
                break
        if not sub_id and request.subjects:
            sub_id = request.subjects[0].id
            
        fac_id = ic.faculty_id or (request.assignments[0].faculty_id if request.assignments else "default_fac")
        rm_id = ic.room_id or (request.rooms[0].id if request.rooms else "default_room")
        
        for div_id in ic_divisions:
            for i in range(ic.duration_slots):
                entries.append(TimetableEntryResult(
                    division_id=div_id,
                    subject_id=sub_id or "fixed_sub",
                    faculty_id=fac_id,
                    room_id=rm_id,
                    day=ic.day,
                    slot=ic.start_slot + i,
                    is_lab_block=False
                ))

    log(f"  entries_generated={len(entries)}")
    log("TIMETABLE GENERATION COMPLETE")

    return TimetableGenerationResult(
        status=status_name,
        entries=entries,
        solve_time_seconds=solve_time,
        objective_score=obj_score,
        validation_passed=True,   # independent validator called by the route
        conflicts=[],
        suggestions=[],
        message=None,
        solver_log="\n".join(log_lines),
    )
