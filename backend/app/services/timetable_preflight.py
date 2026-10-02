"""
Pre-flight Validation Engine (Stage 0).

Runs strictly before any solver stage is invoked.
Performs deterministic, arithmetic, and domain-capacity checks against DB data:
1. Division Period Balance: required weekly teaching periods must match available periods.
2. Faculty Workload vs. Availability: faculty teaching hours <= available slots minus unavailabilities.
3. Lab Room Capacity: sufficient lab rooms to support parallel batches.
4. Placement Window Feasibility: windowed constraints (before_lunch / after_lunch) do not exceed slot capacity.

Returns structured PreflightIssue objects with exact numbers and suggested fixes.
"""
from collections import defaultdict
from typing import Any
from sqlalchemy.orm import Session

from app.models.academic import (
    Division, Subject, Room, RoomType, TeachingAssignment,
    FacultyUnavailability, InstitutionalCourse, SharedCourse
)
from app.models.user import User
from app.models.schedule_config import ScheduleConfig
from app.models.constraints import TimetableConstraint
from app.schemas.timetable import PreflightIssue, ConflictDetail


def run_preflight_checks(
    db: Session,
    config: ScheduleConfig | None = None
) -> tuple[bool, list[PreflightIssue], list[ConflictDetail], list[str], str]:
    """
    Executes Stage 0 preflight checks.
    Returns: (is_valid, issues, legacy_conflicts, suggestions, summary)
    """
    if config is None:
        config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    if not config:
        config = ScheduleConfig(
            id="default",
            working_days=6,
            periods_per_day=8,
            break_slots=[2, 5],
            lecture_duration_minutes=50,
            lab_duration_minutes=100
        )

    divisions = db.query(Division).all()
    subjects = db.query(Subject).all()
    rooms = db.query(Room).filter(Room.is_active == True).all()
    assignments = db.query(TeachingAssignment).all()
    faculty_users = db.query(User).all()
    institutional_courses = db.query(InstitutionalCourse).all()
    shared_courses = db.query(SharedCourse).all()
    constraints = db.query(TimetableConstraint).filter(TimetableConstraint.is_active == True).all()
    unavailabilities = db.query(FacultyUnavailability).all()

    issues: list[PreflightIssue] = []
    conflicts: list[ConflictDetail] = []
    suggestions: list[str] = []

    # Basic entity presence check
    if not divisions:
        issues.append(PreflightIssue(
            reason="No divisions configured",
            numbers={"divisions_count": 0},
            suggested_fix="Create or upload at least one division before generating a timetable."
        ))
        return False, issues, [ConflictDetail(type="missing_data", details="No divisions found")], ["Create divisions"], "No divisions configured."

    if not subjects:
        issues.append(PreflightIssue(
            reason="No subjects configured",
            numbers={"subjects_count": 0},
            suggested_fix="Create or upload subjects before generating a timetable."
        ))
        return False, issues, [ConflictDetail(type="missing_data", details="No subjects found")], ["Create subjects"], "No subjects configured."

    if not rooms:
        issues.append(PreflightIssue(
            reason="No rooms configured",
            numbers={"rooms_count": 0},
            suggested_fix="Add at least one classroom and one lab in Manage Classrooms & Labs."
        ))
        return False, issues, [ConflictDetail(type="missing_data", details="No active rooms found")], ["Add rooms"], "No active rooms configured."

    # Lookups
    subjects_by_id = {s.id: s for s in subjects}
    faculty_by_id = {u.id: u for u in faculty_users}
    divisions_by_id = {d.id: d for d in divisions}

    teaching_slots = config.get_teaching_slots()
    teaching_slots_per_day = len(teaching_slots)
    working_days = config.working_days or 6
    available_periods_per_week = teaching_slots_per_day * working_days
    before_lunch_slots = config.get_before_lunch_slots()
    after_lunch_slots = config.get_after_lunch_slots()
    before_lunch_capacity_weekly = len(before_lunch_slots) * working_days
    after_lunch_capacity_weekly = len(after_lunch_slots) * working_days

    # ---------------------------------------------------------------------------
    # 1. Division Period Balance
    # ---------------------------------------------------------------------------
    # Group assignments by division and track batching
    for div in divisions:
        div_assignments = [a for a in assignments if a.division_id == div.id]
        
        # Categorize: theory vs parallel lab batches
        theory_periods = 0
        lab_groups: dict[str, list[TeachingAssignment]] = defaultdict(list)
        other_periods = 0

        for a in div_assignments:
            sub = subjects_by_id.get(a.subject_id)
            duration = a.duration_slots or (2 if a.session_type == "lab" else 1)
            count = a.weekly_count or (sub.weekly_lectures if sub and a.session_type != "lab" else 1)
            
            if a.session_type == "lab" or (sub and sub.is_lab):
                # Group by subject / lab to identify parallel batches
                group_key = a.subject_id
                lab_groups[group_key].append(a)
            elif a.session_type == "theory":
                theory_periods += (count * duration)
            else:
                other_periods += (count * duration)

        # For labs: parallel batches occupy the same timetable slot block for the division
        lab_periods = 0
        for sub_id, batch_list in lab_groups.items():
            sub = subjects_by_id.get(sub_id)
            dur = max((b.duration_slots or 2) for b in batch_list)
            # If multiple batches run in parallel (Batch 1, Batch 2), division period consumption is duration * sessions
            weekly_sessions = max((b.weekly_count or 1) for b in batch_list)
            lab_periods += dur * weekly_sessions

        # Add fixed institutional courses for this division
        fixed_periods = 0
        for fc in institutional_courses:
            div_match = False
            if fc.divisions:
                for d in fc.divisions:
                    if d.lower() in (div.name.lower(), div.division_code.lower(), f"{div.year}_{div.division_code}".lower()):
                        div_match = True
                        break
            elif fc.year == div.year:
                div_match = True

            if div_match:
                fixed_periods += (fc.duration_slots or 1)

        # Add shared courses for this division
        shared_periods = 0
        for sc in shared_courses:
            div_match = False
            if sc.divisions:
                for d in sc.divisions:
                    if d.lower() in (div.name.lower(), div.division_code.lower()):
                        div_match = True
                        break
            elif sc.year == div.year:
                div_match = True

            if div_match:
                shared_periods += (sc.duration_slots or 1) * (sc.weekly_sessions or 1)

        total_required_periods = theory_periods + lab_periods + other_periods + fixed_periods + shared_periods

        if total_required_periods != available_periods_per_week:
            diff = available_periods_per_week - total_required_periods
            action = f"Add {diff} teaching period(s)" if diff > 0 else f"Reduce {-diff} teaching period(s)"
            issue = PreflightIssue(
                division=div.name,
                reason="Required teaching periods do not match available schedule periods",
                numbers={
                    "required_periods": total_required_periods,
                    "available_periods": available_periods_per_week,
                    "theory_periods": theory_periods,
                    "lab_periods": lab_periods,
                    "fixed_periods": fixed_periods,
                    "shared_periods": shared_periods,
                    "difference": diff
                },
                suggested_fix=f"{action} in workload assignment for {div.name} to fill exactly {available_periods_per_week} periods."
            )
            issues.append(issue)
            conflicts.append(ConflictDetail(
                type="division_period_mismatch",
                division=div.name,
                details=f"Division {div.name} has {total_required_periods} periods assigned but weekly schedule requires {available_periods_per_week}."
            ))
            suggestions.append(f"{div.name}: {action} to match {available_periods_per_week} weekly slots.")

    # ---------------------------------------------------------------------------
    # 2. Faculty Load vs Available Slots (minus unavailabilities)
    # ---------------------------------------------------------------------------
    faculty_periods: dict[str, int] = defaultdict(int)
    # Combined/joint lectures taught jointly by faculty across divisions count ONCE in faculty timetable
    joint_dedup: set[str] = set()

    for a in assignments:
        dur = a.duration_slots or (2 if a.session_type == "lab" else 1)
        count = a.weekly_count or 1
        
        if a.joint_group_id:
            key = f"{a.faculty_id}_{a.joint_group_id}"
            if key in joint_dedup:
                continue
            joint_dedup.add(key)

        faculty_periods[a.faculty_id] += (dur * count)

    for sc in shared_courses:
        dur = sc.duration_slots or 1
        sessions = sc.weekly_sessions or 1
        faculty_periods[sc.faculty_id] += (dur * sessions)

    for fc in institutional_courses:
        if fc.faculty_id:
            faculty_periods[fc.faculty_id] += (fc.duration_slots or 1)

    # Faculty Unavailability slots
    unavail_slots: dict[str, set[tuple[int, int]]] = defaultdict(set)
    break_set = set(config.get_break_slots())

    for u in unavailabilities:
        if u.slot not in break_set:
            unavail_slots[u.faculty_id].add((u.day, u.slot))

    for c in constraints:
        payload = c.payload or {}
        rule_type = payload.get("rule_type", c.constraint_type)
        if rule_type == "faculty_unavailable":
            scope = payload.get("scope", {})
            params = payload.get("params", {})
            fac_list = scope.get("faculty", [])
            day = params.get("day")
            slot = params.get("slot")
            if day is not None and slot is not None and slot not in break_set:
                for f_id in fac_list:
                    unavail_slots[f_id].add((int(day), int(slot)))

    for fac_id, total_periods in faculty_periods.items():
        fac_user = faculty_by_id.get(fac_id)
        fac_name = fac_user.full_name if fac_user else fac_id
        blocked_count = len(unavail_slots.get(fac_id, set()))
        available_for_faculty = available_periods_per_week - blocked_count

        if total_periods > available_for_faculty:
            excess = total_periods - available_for_faculty
            issue = PreflightIssue(
                faculty=fac_name,
                reason="Faculty workload exceeds available teaching slots after subtracting unavailabilities",
                numbers={
                    "assigned_periods": total_periods,
                    "available_slots": available_for_faculty,
                    "blocked_unavailabilities": blocked_count,
                    "excess_periods": excess
                },
                suggested_fix=f"Reassign {excess} period(s) from {fac_name} to another faculty or remove unavailabilities."
            )
            issues.append(issue)
            conflicts.append(ConflictDetail(
                type="faculty_overloaded",
                faculty=fac_name,
                details=f"{fac_name} requires {total_periods} teaching periods but only {available_for_faculty} are free."
            ))
            suggestions.append(f"Reduce teaching load of {fac_name} by {excess} slots.")

    # ---------------------------------------------------------------------------
    # 3. Lab Rooms vs Parallel Batches
    # ---------------------------------------------------------------------------
    lab_rooms = [r for r in rooms if r.type == RoomType.LAB or str(r.type).lower() == "lab"]
    total_lab_rooms = len(lab_rooms)

    for div in divisions:
        div_assignments = [a for a in assignments if a.division_id == div.id and a.session_type == "lab"]
        batch_names = {a.batch_name for a in div_assignments if a.batch_name and a.batch_name not in ("-", "All")}
        num_parallel_batches = len(batch_names)

        if num_parallel_batches > total_lab_rooms:
            issue = PreflightIssue(
                division=div.name,
                reason="Not enough active lab rooms for parallel batch lab sessions",
                numbers={
                    "parallel_batches_needed": num_parallel_batches,
                    "active_lab_rooms_available": total_lab_rooms
                },
                suggested_fix=f"Add at least {num_parallel_batches - total_lab_rooms} more lab room(s) in Room Management or run batches sequentially."
            )
            issues.append(issue)
            conflicts.append(ConflictDetail(
                type="insufficient_lab_rooms",
                division=div.name,
                details=f"Division {div.name} has {num_parallel_batches} batches running in parallel but only {total_lab_rooms} lab rooms exist."
            ))
            suggestions.append(f"Add {num_parallel_batches - total_lab_rooms} lab room(s).")

    # ---------------------------------------------------------------------------
    # 4. Placement Window Feasibility (before_lunch / after_lunch)
    # ---------------------------------------------------------------------------
    for div in divisions:
        after_lunch_demands = 0
        before_lunch_demands = 0

        # Check constraints targeted at this division or its subjects
        for c in constraints:
            payload = c.payload or {}
            rule_type = payload.get("rule_type", c.constraint_type)
            if rule_type != "placement_window":
                continue

            scope = payload.get("scope", {})
            params = payload.get("params", {})
            div_scope = scope.get("divisions", [])
            window = params.get("window", "").lower()

            if not div_scope or div.id in div_scope or div.name in div_scope:
                # Calculate constrained periods for this rule
                sub_scope = set(scope.get("subjects", []))
                for a in assignments:
                    if a.division_id == div.id and (not sub_scope or a.subject_id in sub_scope):
                        dur = a.duration_slots or 1
                        cnt = a.weekly_count or 1
                        if window == "after_lunch":
                            after_lunch_demands += (dur * cnt)
                        elif window == "before_lunch":
                            before_lunch_demands += (dur * cnt)

        if after_lunch_demands > after_lunch_capacity_weekly:
            excess = after_lunch_demands - after_lunch_capacity_weekly
            issues.append(PreflightIssue(
                division=div.name,
                reason="More sessions constrained to after-lunch window than afternoon periods exist in the week",
                numbers={
                    "constrained_after_lunch": after_lunch_demands,
                    "weekly_after_lunch_capacity": after_lunch_capacity_weekly,
                    "excess": excess
                },
                suggested_fix=f"Relax afternoon constraints on {excess} period(s) for division {div.name}."
            ))
            conflicts.append(ConflictDetail(
                type="placement_window_oversubscribed",
                division=div.name,
                details=f"Division {div.name} has {after_lunch_demands} afternoon-only periods but only {after_lunch_capacity_weekly} are available."
            ))

        if before_lunch_demands > before_lunch_capacity_weekly:
            excess = before_lunch_demands - before_lunch_capacity_weekly
            issues.append(PreflightIssue(
                division=div.name,
                reason="More sessions constrained to before-lunch window than morning periods exist in the week",
                numbers={
                    "constrained_before_lunch": before_lunch_demands,
                    "weekly_before_lunch_capacity": before_lunch_capacity_weekly,
                    "excess": excess
                },
                suggested_fix=f"Relax morning constraints on {excess} period(s) for division {div.name}."
            ))
            conflicts.append(ConflictDetail(
                type="placement_window_oversubscribed",
                division=div.name,
                details=f"Division {div.name} has {before_lunch_demands} morning-only periods but only {before_lunch_capacity_weekly} are available."
            ))

    is_valid = len(issues) == 0 and len(conflicts) == 0
    summary = "Pre-flight validation passed successfully! All periods, rooms, faculty, and windows are feasible." if is_valid else f"Pre-flight detected {len(issues)} structural scheduling bottleneck(s)."

    return is_valid, issues, conflicts, list(set(suggestions)), summary
