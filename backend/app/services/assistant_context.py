"""
assistant_context.py — Retrieve live ENOSIS data to ground the AI assistant.

Design:
1. Intent detection: classify the message into topic buckets (timetable_status,
   schedule_today, schedule_faculty, schedule_subject, schedule_division, tasks,
   attendance, general).
2. Always provide: timetable publication status + basic schedule meta.
3. Precise entity extraction:
   - Faculty: token matching with title stripping, without matching stopwords or short subwords.
   - Divisions: extracts year (FY/FE=1, SY/SE=2, TY/TE=3, BE/BTech=4) and division code (A-E),
     plus specific name match.
   - Subjects: matches code (e.g. UDSC0631, CS302, DAA) or distinct tokens (e.g. Deep Learning),
     preventing spurious substring matches like '%ty%' or '%me%'.
4. Timezone-aware (IST / Asia/Kolkata) day resolution with English & Hindi day support.
5. Smart timetable querying:
   - Resolves target faculty, division, subject, day, and slot.
   - Uses fallback relaxation if strict intersection yields 0 entries but entity has records.
6. Personal ("my/me/I") queries use the logged-in user's identity.
"""

import logging
import re
from datetime import datetime, timezone, timedelta
from typing import Any

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session, joinedload

from app.models.academic import Division, Room, Subject, TeachingAssignment
from app.models.attendance import (
    AttendanceStatus,
    LectureAttendanceRecord,
    LectureAttendanceSession,
)
from app.models.generation_history import GenerationRun
from app.models.schedule_config import ScheduleConfig
from app.models.sli import Department
from app.models.timetable import TimetableEntry
from app.models.todo import Task
from app.models.user import User

logger = logging.getLogger("ai_assistant.context")

# ---------------------------------------------------------------------------
# Constants / term sets
# ---------------------------------------------------------------------------

_STOP_WORDS = {
    "a", "about", "all", "am", "an", "and", "are", "as", "assigned", "at", "be", "by", "can",
    "class", "classes", "course", "courses", "dept", "department", "do", "does", "division", "div",
    "faculty", "for", "from", "give", "has", "have", "help", "he", "she", "i", "in", "is", "it", "me", "my", "of",
    "on", "or", "our", "please", "prof", "professor", "room", "schedule", "section", "sec",
    "show", "sir", "madam", "slot", "slots", "subject", "subjects", "tell",
    "the", "their", "this", "time", "timetable", "to", "today", "tomorrow", "was", "we", "were",
    "what", "when", "where", "which", "who", "will", "with", "year", "years",
    # Hindi / Hinglish stopwords & conversational words
    "ka", "ki", "ke", "ko", "me", "mein", "se", "par", "pe", "kya", "kab", "kaha", "kahan",
    "kisko", "kiska", "kiski", "bata", "batao", "bataiye", "dikhao", "hai", "hain", "karo",
    "karna", "dekhna", "chahiye", "btao", "bhai", "kijiye", "bhi", "aur", "ya", "tha", "thi", "the",
    "wala", "wali", "wale", "kuch", "sab", "sirf", "bhi", "toh", "to"
}

_YEAR_WORDS = {
    "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "sixth": 6,
}

# Timetable-related intent terms
_TIMETABLE_TERMS = {
    "schedule", "timetable", "timetables", "workload", "teaching", "teach",
    "lecture", "lectures", "period", "periods", "slot", "slots", "class",
    "classes", "published", "publish", "live", "release", "released",
    "visible", "see", "view", "current", "today", "tomorrow", "week",
    "weekly", "when", "which", "who", "room", "classroom", "lab",
    "teaching", "assignment", "assigned", "bata", "batao", "dikhao", "kab", "kaha"
}

# Timetable status / publication intent
_STATUS_TERMS = {
    "published", "publish", "live", "release", "released", "visible",
    "available", "active", "current", "status", "updated", "latest",
    "gone", "out", "see", "view", "why", "cant", "can't", "cannot",
    "when", "timetable", "schedule", "hua", "aaya"
}

_SCHEDULE_TERMS = {
    "schedule", "timetable", "workload", "teaching", "teach", "lecture",
    "lectures", "period", "periods", "slot", "slots", "assignment", "assignments",
}
_OWN_COURSE_TERMS = {"class", "classes", "course", "courses", "subject", "subjects"}
_TASK_TERMS = {"task", "tasks", "todo", "todos", "reminder", "reminders", "deadline"}

_DAY_NAMES = {
    "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3,
    "friday": 4, "saturday": 5, "sunday": 6,
    "mon": 0, "tue": 1, "tues": 1, "wed": 2, "thu": 3,
    "thur": 3, "thurs": 3, "fri": 4, "sat": 5, "sun": 6,
    "somwar": 0, "mangalwar": 1, "budhwar": 2, "guruwar": 3,
    "shukrawar": 4, "shaniwar": 5, "ravivar": 6
}

# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------

def _search_terms(text: str) -> list[str]:
    return [
        token
        for token in dict.fromkeys(re.findall(r"[a-z0-9]+", text.lower()))
        if len(token) >= 2 and token not in _STOP_WORDS
    ][:30]


def _contains_any(text: str, terms: set[str]) -> bool:
    words = set(re.findall(r"[a-z0-9]+", text.lower()))
    return bool(words & terms)


def _day_of_week_from_text(text: str, today_weekday: int) -> int | None:
    lower = text.lower()
    if re.search(r'\b(tomorrow|kal)\b', lower):
        return (today_weekday + 1) % 7
    if re.search(r'\b(today|aaj|current)\b', lower):
        return today_weekday
    for name, idx in _DAY_NAMES.items():
        if re.search(rf"\b{name}\b", lower):
            return idx
    return None


def _slot_from_time_mention(text: str, config: ScheduleConfig | None) -> int | None:
    if not config:
        return None
    time_match = re.search(
        r"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b", text.lower()
    )
    if not time_match:
        return None
    hour = int(time_match.group(1))
    minute = int(time_match.group(2) or 0)
    period = time_match.group(3)
    if period == "pm" and hour != 12:
        hour += 12
    elif period == "am" and hour == 12:
        hour = 0
    try:
        sh, sm = map(int, (config.start_time or "09:00").split(":"))
    except Exception:
        sh, sm = 9, 0
    dur = config.period_duration_minutes or 60
    total_start_mins = sh * 60 + sm
    total_query_mins = hour * 60 + minute
    diff = total_query_mins - total_start_mins
    if diff < 0:
        return None
    slot = diff // dur
    if config.periods_per_day and slot >= config.periods_per_day:
        return None
    return slot


# ---------------------------------------------------------------------------
# Entity Extractors
# ---------------------------------------------------------------------------

def _extract_division_entities(text: str, db: Session) -> list[Division]:
    lower = text.lower()
    year = None
    if re.search(r'\b(fy|fe|first\s*year|1st\s*year|1st|year\s*1)\b', lower):
        year = 1
    elif re.search(r'\b(sy|se|second\s*year|2nd\s*year|2nd|year\s*2)\b', lower):
        year = 2
    elif re.search(r'\b(ty|te|third\s*year|3rd\s*year|3rd|year\s*3)\b', lower):
        year = 3
    elif re.search(r'\b(btech|be|final\s*year|4th\s*year|4th|year\s*4)\b', lower):
        year = 4

    div_code = None
    div_match = re.search(r'\b(?:div|division|section|sec)[-_ ]*([a-e])\b', lower)
    if div_match:
        div_code = div_match.group(1).upper()
    else:
        code_match = re.search(r'\b(?:fy|fe|sy|se|ty|te|btech|be)[-_ ]*(?:[a-z0-9]+[-_ ]*)?([a-e])\b', lower)
        if code_match:
            div_code = code_match.group(1).upper()

    all_divs = db.query(Division).all()
    matched = []
    for d in all_divs:
        if year is not None and div_code is not None:
            if d.year == year and d.division_code.upper() == div_code:
                matched.append(d)
        elif year is not None:
            if d.year == year:
                matched.append(d)
        elif div_code is not None:
            if d.division_code.upper() == div_code:
                matched.append(d)
        else:
            d_norm = d.name.lower().replace("-", " ").replace("_", " ")
            if len(d_norm) >= 3 and (d_norm in lower or lower in d_norm):
                matched.append(d)
    return matched


def _extract_faculty_entities(text: str, db: Session) -> list[User]:
    words = [w for w in re.findall(r'[a-zA-Z0-9]+', text.lower()) if len(w) >= 3 and w not in _STOP_WORDS]
    if not words:
        return []
    
    all_users = db.query(User).filter(User.is_active.is_(True)).all()
    matched = []
    for u in all_users:
        if not u.full_name:
            continue
        u_name = u.full_name.lower()
        for prefix in ["dr.", "dr ", "prof.", "prof ", "mr.", "mr ", "mrs.", "mrs ", "ms.", "ms."]:
            if u_name.startswith(prefix):
                u_name = u_name[len(prefix):].strip()
        u_tokens = set(re.findall(r'[a-zA-Z0-9]+', u_name))
        if any(w in u_tokens for w in words):
            matched.append(u)
    return matched


def _extract_subject_entities(text: str, db: Session) -> list[Subject]:
    all_subjects = db.query(Subject).all()
    lower = text.lower()
    matched = []
    for s in all_subjects:
        s_name = s.name.lower()
        s_code = (s.code or "").lower()
        if s_code and re.search(rf'\b{re.escape(s_code)}\b', lower):
            matched.append(s)
            continue
        if len(s_name) >= 3 and s_name in lower:
            matched.append(s)
            continue
        s_tokens = [w for w in re.findall(r'[a-zA-Z0-9]+', s_name) if len(w) >= 3 and w not in _STOP_WORDS]
        if len(s_tokens) >= 2:
            if all(re.search(rf'\b{re.escape(t)}\b', lower) for t in s_tokens):
                matched.append(s)
                continue
    return matched


# ---------------------------------------------------------------------------
# Record formatters
# ---------------------------------------------------------------------------

def _assignment_fact(assignment: TeachingAssignment) -> dict[str, Any]:
    return {
        "faculty": assignment.faculty.full_name if assignment.faculty else "Unknown",
        "department": assignment.faculty.department if assignment.faculty else None,
        "subject": assignment.subject.name if assignment.subject else "Unknown",
        "subject_code": assignment.subject.code if assignment.subject else "",
        "division": assignment.division.name if assignment.division else "Unknown",
        "year": assignment.division.year if assignment.division else None,
        "division_code": assignment.division.division_code if assignment.division else "",
        "weekly_count": assignment.weekly_count,
        "duration_slots": assignment.duration_slots,
        "session_type": assignment.session_type,
    }


def _timetable_fact(entry: TimetableEntry, config: ScheduleConfig | None = None) -> dict[str, Any]:
    day_names = config.day_names if config and config.day_names else (
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    )
    day_label = (
        day_names[entry.day]
        if 0 <= entry.day < len(day_names)
        else f"Day {entry.day}"
    )
    time_str = None
    if config:
        try:
            sh, sm = map(int, (config.start_time or "09:00").split(":"))
        except Exception:
            sh, sm = 9, 0
        dur = config.period_duration_minutes or 60
        start_mins = sh * 60 + sm + entry.slot * dur
        end_mins = start_mins + dur
        time_str = (
            f"{start_mins // 60:02d}:{start_mins % 60:02d}–{end_mins // 60:02d}:{end_mins % 60:02d}"
        )
    return {
        "subject": entry.subject.name if entry.subject else "Unknown",
        "subject_code": entry.subject.code if entry.subject else "",
        "faculty": entry.faculty.full_name if entry.faculty else "Unknown",
        "department": entry.faculty.department if entry.faculty else None,
        "division": entry.division.name if entry.division else "Unknown",
        "year": entry.division.year if entry.division else None,
        "division_code": entry.division.division_code if entry.division else "",
        "day": day_label,
        "slot": entry.slot + 1,
        "time": time_str,
        "room": entry.room.name if entry.room else "TBD",
        "session_type": entry.session_type,
        "batch": entry.batch_name or "All",
    }


def _get_timetable_status(db: Session) -> dict[str, Any]:
    latest_run = (
        db.query(GenerationRun)
        .filter(GenerationRun.status.in_(("OPTIMAL", "FEASIBLE")))
        .order_by(GenerationRun.generated_at.desc())
        .first()
    )
    total_runs = db.query(func.count(GenerationRun.id)).scalar() or 0
    failed_runs = (
        db.query(func.count(GenerationRun.id))
        .filter(GenerationRun.status.in_(("INFEASIBLE", "UNKNOWN", "ERROR")))
        .scalar()
        or 0
    )

    if not latest_run:
        return {
            "is_published": False,
            "status": "No timetable has been generated or published yet.",
            "total_generation_attempts": total_runs,
            "failed_generation_attempts": failed_runs,
            "published_at": None,
            "batch_id": None,
            "total_entries": 0,
            "generation_status": None,
        }

    total_entries = (
        db.query(func.count(TimetableEntry.id))
        .filter(TimetableEntry.batch_id == latest_run.id)
        .scalar()
        or 0
    )

    published_at = None
    if latest_run.generated_at:
        published_at = latest_run.generated_at.isoformat()
    if latest_run.config_snapshot and isinstance(latest_run.config_snapshot, dict):
        published_at = latest_run.config_snapshot.get("published_at", published_at)

    return {
        "is_published": True,
        "status": "A timetable is currently published and active.",
        "generation_status": latest_run.status,
        "published_at": published_at,
        "batch_id": latest_run.id,
        "total_entries": total_entries,
        "total_generation_attempts": total_runs,
        "failed_generation_attempts": failed_runs,
        "solver_log_summary": (latest_run.solver_log or "")[:300] if latest_run.solver_log else None,
    }


# ---------------------------------------------------------------------------
# Main context retrieval
# ---------------------------------------------------------------------------

def retrieve_enosis_context(
    db: Session,
    current_user: User,
    message: str,
    conversation_history: list[dict[str, str]],
) -> dict[str, Any]:
    """
    Retrieve bounded, read-only ENOSIS facts relevant to this chat turn.
    """
    recent_user_text = " ".join(
        item["content"]
        for item in conversation_history[-6:]
        if item["role"] == "user"
    )
    search_text = f"{recent_user_text} {message}".strip()
    terms = _search_terms(search_text)

    logger.info("[CTX] User=%s | Message=%r | Terms=%s", current_user.email, message[:80], terms)

    # ── Timezone-aware date calculation (Asia/Kolkata = UTC+5:30) ───────────
    now_ist = datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)
    today_weekday = now_ist.weekday()  # 0=Mon…6=Sun
    weekday_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    today_name = weekday_names[today_weekday]

    # ── Load schedule config (always) ───────────────────────────────────────
    config = db.query(ScheduleConfig).filter(ScheduleConfig.id == "default").first()
    config_info: dict[str, Any] = {}
    if config:
        config_info = {
            "working_days": config.working_days,
            "day_names": config.day_names,
            "periods_per_day": config.periods_per_day,
            "start_time": config.start_time,
            "end_time": config.end_time,
            "period_duration_minutes": config.period_duration_minutes,
            "break_slots": config.break_slots,
            "break_labels": config.break_labels,
            "college_name": config.college_name,
            "department_name": config.department_name,
            "academic_year": config.academic_year,
            "semester": config.semester,
        }

    # ── Intent detection ─────────────────────────────────────────────────────
    is_timetable_query = _contains_any(search_text, _TIMETABLE_TERMS)
    is_status_query = _contains_any(search_text, _STATUS_TERMS)
    is_task_query = _contains_any(search_text, _TASK_TERMS)
    is_attendance_query = "attendance" in set(re.findall(r"[a-z0-9]+", search_text.lower()))

    has_personal_reference = bool(
        re.search(
            r"\b(i|my|mine|me|our|myself)\b|\b(this|current)\s+faculty\b",
            search_text.lower(),
        )
    )
    asks_for_own_schedule = has_personal_reference and (
        _contains_any(search_text, _SCHEDULE_TERMS)
        or _contains_any(search_text, _OWN_COURSE_TERMS)
        or is_timetable_query
    )

    # ── Precise Entity Matching ──────────────────────────────────────────────
    matched_faculty = _extract_faculty_entities(search_text, db)
    matched_divisions = _extract_division_entities(search_text, db)
    matched_subjects = _extract_subject_entities(search_text, db)

    # Check if latest turn contains fresh entities to override history
    cur_faculty = _extract_faculty_entities(message, db)
    cur_divisions = _extract_division_entities(message, db)
    cur_subjects = _extract_subject_entities(message, db)
    if cur_faculty:
        matched_faculty = cur_faculty
    if cur_divisions:
        matched_divisions = cur_divisions
    if cur_subjects:
        matched_subjects = cur_subjects

    matched_faculty_ids = {f.id for f in matched_faculty}
    matched_subject_ids = {s.id for s in matched_subjects}
    matched_division_ids = {d.id for d in matched_divisions}

    # ── Base context dict ────────────────────────────────────────────────────
    context: dict[str, Any] = {
        "today": today_name,
        "today_weekday_index": today_weekday,
        "current_datetime": now_ist.strftime("%Y-%m-%d %H:%M IST"),
        "current_user": {
            "name": current_user.full_name,
            "department": current_user.department,
            "role": current_user.role.value if current_user.role else "faculty",
            "designation": current_user.designation,
        },
        "schedule_config": config_info,
        "timetable_publication_status": {},
        "matched_subjects": [{"name": s.name, "code": s.code} for s in matched_subjects],
        "matched_faculty": [{"name": f.full_name, "department": f.department} for f in matched_faculty],
        "matched_divisions": [
            {"name": d.name, "year": d.year, "division_code": d.division_code}
            for d in matched_divisions
        ],
        "teaching_assignments": [],
        "published_timetable": [],
        "my_teaching_assignments": [],
        "my_published_timetable": [],
        "my_open_tasks": [],
        "my_teaching_attendance_summary": None,
        "all_divisions": [],
        "all_subjects": [],
        "unavailable_sources": [
            "A persisted course CO-PO mapping matrix is not available to this assistant."
        ],
    }

    # ── Always populate publication status for timetable/status queries ─────
    if is_timetable_query or is_status_query or matched_faculty_ids or matched_division_ids or matched_subject_ids:
        pub_status = _get_timetable_status(db)
        context["timetable_publication_status"] = pub_status

    # ── Determine if we need to load timetable entries ───────────────────────
    should_load_timetable = (
        is_timetable_query
        or is_status_query
        or asks_for_own_schedule
        or bool(matched_faculty_ids)
        or bool(matched_division_ids)
        or bool(matched_subject_ids)
    )

    if should_load_timetable:
        latest_run = (
            db.query(GenerationRun)
            .filter(GenerationRun.status.in_(("OPTIMAL", "FEASIBLE")))
            .order_by(GenerationRun.generated_at.desc())
            .first()
        )

        if latest_run:
            # Day resolution
            requested_day = _day_of_week_from_text(search_text, today_weekday)
            cur_requested_day = _day_of_week_from_text(message, today_weekday)
            if cur_requested_day is not None:
                requested_day = cur_requested_day

            day_index_filter: int | None = None
            if requested_day is not None:
                if config and config.day_names:
                    for i, dn in enumerate(config.day_names):
                        if dn.lower() == weekday_names[requested_day].lower():
                            day_index_filter = i
                            break
                    else:
                        day_index_filter = requested_day
                else:
                    day_index_filter = requested_day

            slot_filter = _slot_from_time_mention(message, config) or _slot_from_time_mention(search_text, config)

            base_query = (
                db.query(TimetableEntry)
                .options(
                    joinedload(TimetableEntry.subject),
                    joinedload(TimetableEntry.faculty),
                    joinedload(TimetableEntry.division),
                    joinedload(TimetableEntry.room),
                )
                .filter(TimetableEntry.batch_id == latest_run.id)
            )

            # ── My schedule ───────────────────────────────────────────────────
            if asks_for_own_schedule:
                my_query = base_query.filter(TimetableEntry.faculty_id == current_user.id)
                if day_index_filter is not None:
                    my_query = my_query.filter(TimetableEntry.day == day_index_filter)
                if slot_filter is not None:
                    my_query = my_query.filter(TimetableEntry.slot == slot_filter)
                own_entries = my_query.order_by(TimetableEntry.day, TimetableEntry.slot).limit(100).all()
                context["my_published_timetable"] = [_timetable_fact(e, config) for e in own_entries]

            # ── Entity-targeted query with smart fallback ────────────────────
            entries = []
            if matched_faculty_ids or matched_division_ids or matched_subject_ids:
                q = base_query
                if matched_faculty_ids:
                    q = q.filter(TimetableEntry.faculty_id.in_(matched_faculty_ids))
                if matched_division_ids:
                    q = q.filter(TimetableEntry.division_id.in_(matched_division_ids))
                if matched_subject_ids:
                    q = q.filter(TimetableEntry.subject_id.in_(matched_subject_ids))
                if day_index_filter is not None:
                    q = q.filter(TimetableEntry.day == day_index_filter)
                if slot_filter is not None:
                    q = q.filter(TimetableEntry.slot == slot_filter)

                entries = q.order_by(TimetableEntry.day, TimetableEntry.slot).limit(150).all()

                # Fallback Relaxation: if strict intersection is empty
                if not entries and matched_faculty_ids and matched_division_ids:
                    # Try faculty on that day
                    fallback_fac_q = base_query.filter(TimetableEntry.faculty_id.in_(matched_faculty_ids))
                    if day_index_filter is not None:
                        fallback_fac_q = fallback_fac_q.filter(TimetableEntry.day == day_index_filter)
                    entries = fallback_fac_q.order_by(TimetableEntry.day, TimetableEntry.slot).limit(150).all()

                if not entries and matched_division_ids:
                    # Try division on that day
                    fallback_div_q = base_query.filter(TimetableEntry.division_id.in_(matched_division_ids))
                    if day_index_filter is not None:
                        fallback_div_q = fallback_div_q.filter(TimetableEntry.day == day_index_filter)
                    entries = fallback_div_q.order_by(TimetableEntry.day, TimetableEntry.slot).limit(150).all()

                if not entries and matched_faculty_ids:
                    # Entire week for faculty so assistant knows their schedule
                    fac_all_days_q = base_query.filter(TimetableEntry.faculty_id.in_(matched_faculty_ids))
                    entries = fac_all_days_q.order_by(TimetableEntry.day, TimetableEntry.slot).limit(150).all()

            elif is_timetable_query or is_status_query:
                overview_query = base_query
                if day_index_filter is not None:
                    overview_query = overview_query.filter(TimetableEntry.day == day_index_filter)
                if slot_filter is not None:
                    overview_query = overview_query.filter(TimetableEntry.slot == slot_filter)
                entries = overview_query.order_by(TimetableEntry.day, TimetableEntry.slot).limit(80).all()

            context["published_timetable"] = [_timetable_fact(e, config) for e in entries]

            # ── Teaching assignments for matched entities ─────────────────────
            assignment_options = (
                joinedload(TeachingAssignment.faculty),
                joinedload(TeachingAssignment.subject),
                joinedload(TeachingAssignment.division),
            )
            assignment_filters = []
            if matched_faculty_ids:
                assignment_filters.append(TeachingAssignment.faculty_id.in_(matched_faculty_ids))
            if matched_subject_ids:
                assignment_filters.append(TeachingAssignment.subject_id.in_(matched_subject_ids))
            if matched_division_ids:
                assignment_filters.append(TeachingAssignment.division_id.in_(matched_division_ids))

            if assignment_filters:
                assignments = (
                    db.query(TeachingAssignment)
                    .options(*assignment_options)
                    .filter(or_(*assignment_filters))
                    .order_by(TeachingAssignment.faculty_id, TeachingAssignment.subject_id)
                    .limit(100)
                    .all()
                )
                context["teaching_assignments"] = [_assignment_fact(a) for a in assignments]

            # ── My teaching assignments ───────────────────────────────────────
            if asks_for_own_schedule or has_personal_reference:
                own_assignments = (
                    db.query(TeachingAssignment)
                    .options(*assignment_options)
                    .filter(TeachingAssignment.faculty_id == current_user.id)
                    .order_by(TeachingAssignment.subject_id, TeachingAssignment.division_id)
                    .limit(100)
                    .all()
                )
                context["my_teaching_assignments"] = [_assignment_fact(a) for a in own_assignments]

    # ── All divisions & subjects summary ─────────────────────────────────────
    if is_timetable_query or is_status_query or bool(matched_faculty_ids) or bool(matched_division_ids):
        all_divs = db.query(Division).order_by(Division.year, Division.division_code).limit(50).all()
        context["all_divisions"] = [
            {"name": d.name, "year": d.year, "division_code": d.division_code}
            for d in all_divs
        ]
        all_subs = db.query(Subject).order_by(Subject.name).limit(50).all()
        context["all_subjects"] = [
            {"name": s.name, "code": s.code} for s in all_subs
        ]

    # ── Tasks ────────────────────────────────────────────────────────────────
    if is_task_query:
        tasks = (
            db.query(Task)
            .filter(
                Task.owner_id == current_user.id,
                Task.is_completed.is_(False),
            )
            .order_by(Task.due_date.is_(None), Task.due_date, Task.created_at.desc())
            .limit(25)
            .all()
        )
        context["my_open_tasks"] = [
            {
                "title": task.title,
                "due_date": task.due_date.isoformat() if task.due_date else None,
                "priority": task.priority,
                "status": task.status,
            }
            for task in tasks
        ]

    # ── Attendance ───────────────────────────────────────────────────────────
    if is_attendance_query:
        session_count = (
            db.query(func.count(LectureAttendanceSession.session_id))
            .filter(LectureAttendanceSession.faculty_id == current_user.id)
            .scalar()
            or 0
        )
        attendance_rows = (
            db.query(
                LectureAttendanceRecord.status,
                func.count(LectureAttendanceRecord.record_id),
            )
            .join(
                LectureAttendanceSession,
                LectureAttendanceSession.session_id == LectureAttendanceRecord.session_id,
            )
            .filter(LectureAttendanceSession.faculty_id == current_user.id)
            .group_by(LectureAttendanceRecord.status)
            .all()
        )
        context["my_teaching_attendance_summary"] = {
            "sessions_taught_with_attendance": session_count,
            "student_records_by_status": {
                status.value if isinstance(status, AttendanceStatus) else str(status): count
                for status, count in attendance_rows
            },
            "privacy_note": "Aggregated class attendance only; no student identities are exposed.",
        }

    return context
