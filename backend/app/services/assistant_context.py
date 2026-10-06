import re
from typing import Any

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session, joinedload

from app.models.academic import Division, Subject, TeachingAssignment
from app.models.attendance import (
    AttendanceStatus,
    LectureAttendanceRecord,
    LectureAttendanceSession,
)
from app.models.generation_history import GenerationRun
from app.models.sli import Department
from app.models.timetable import TimetableEntry
from app.models.todo import Task
from app.models.user import User

_STOP_WORDS = {
    "a", "about", "all", "am", "an", "and", "are", "assigned", "at", "can",
    "class", "classes", "course", "courses", "do", "does", "faculty", "for",
    "from", "give", "have", "help", "i", "in", "is", "it", "me", "my", "of",
    "on", "please", "prof", "professor", "show", "subject", "subjects", "tell",
    "the", "their", "this", "to", "today", "tomorrow", "what", "when", "where",
    "which", "who", "with", "year",
}
_YEAR_WORDS = {
    "first": 1,
    "second": 2,
    "third": 3,
    "fourth": 4,
    "fifth": 5,
    "sixth": 6,
}
_SCHEDULE_TERMS = {
    "schedule", "timetable", "workload", "teaching", "teach", "lecture",
    "lectures", "period", "periods", "slot", "slots", "assignment",
    "assignments", "assigned",
}
_OWN_COURSE_TERMS = {"class", "classes", "course", "courses", "subject", "subjects"}
_TASK_TERMS = {"task", "tasks", "todo", "todos", "reminder", "reminders", "deadline"}


def _search_terms(text: str) -> list[str]:
    return [
        token
        for token in dict.fromkeys(re.findall(r"[a-z0-9]+", text.lower()))
        if len(token) >= 2 and token not in _STOP_WORDS
    ][:20]


def _requested_years(text: str) -> set[int]:
    years = {
        int(match)
        for match in re.findall(r"\b([1-6])(?:st|nd|rd|th)?\s+year\b", text.lower())
    }
    years.update(
        year for word, year in _YEAR_WORDS.items()
        if re.search(rf"\b{word}\s+year\b", text.lower())
    )
    return years


def _contains_term(text: str, terms: set[str]) -> bool:
    words = set(re.findall(r"[a-z0-9]+", text.lower()))
    return bool(words & terms)


def _assignment_fact(assignment: TeachingAssignment) -> dict[str, Any]:
    return {
        "faculty": assignment.faculty.full_name,
        "department": assignment.faculty.department,
        "subject": assignment.subject.name,
        "subject_code": assignment.subject.code,
        "division": assignment.division.name,
        "year": assignment.division.year,
        "division_code": assignment.division.division_code,
        "weekly_count": assignment.weekly_count,
        "duration_slots": assignment.duration_slots,
        "session_type": assignment.session_type,
    }


def _timetable_fact(entry: TimetableEntry) -> dict[str, Any]:
    day_names = ("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
    return {
        "subject": entry.subject.name,
        "subject_code": entry.subject.code,
        "faculty": entry.faculty.full_name,
        "department": entry.faculty.department,
        "division": entry.division.name,
        "year": entry.division.year,
        "division_code": entry.division.division_code,
        "day": day_names[entry.day] if 0 <= entry.day < len(day_names) else entry.day,
        "slot": entry.slot,
        "room": entry.room.name,
        "session_type": entry.session_type,
    }


def _latest_published_run(db: Session) -> GenerationRun | None:
    return (
        db.query(GenerationRun)
        .filter(GenerationRun.status.in_(("OPTIMAL", "FEASIBLE")))
        .order_by(GenerationRun.generated_at.desc())
        .first()
    )


def retrieve_enosis_context(
    db: Session,
    current_user: User,
    message: str,
    conversation_history: list[dict[str, str]],
) -> dict[str, Any]:
    """Retrieve bounded, read-only ENOSIS facts relevant to this chat turn."""
    recent_user_text = " ".join(
        item["content"]
        for item in conversation_history[-10:]
        if item["role"] == "user"
    )
    search_text = f"{recent_user_text} {message}"
    terms = _search_terms(search_text)

    context: dict[str, Any] = {
        "matched_subjects": [],
        "matched_faculty": [],
        "matched_divisions": [],
        "teaching_assignments": [],
        "published_timetable": [],
        "my_teaching_assignments": [],
        "my_published_timetable": [],
        "my_open_tasks": [],
        "my_teaching_attendance_summary": None,
        "unavailable_sources": [
            "A persisted course CO-PO mapping matrix is not available to this assistant."
        ],
    }

    token_filters = []
    for term in terms:
        pattern = f"%{term}%"
        token_filters.extend(
            (
                Subject.name.ilike(pattern),
                Subject.code.ilike(pattern),
                Department.department_name.ilike(pattern),
                Department.department_code.ilike(pattern),
            )
        )
    matched_subjects = []
    if token_filters:
        matched_subjects = (
            db.query(Subject)
            .outerjoin(Department, Subject.sli_department_id == Department.department_id)
            .filter(or_(*token_filters))
            .order_by(Subject.name)
            .limit(40)
            .all()
        )

    faculty_filters = []
    for term in terms:
        pattern = f"%{term}%"
        faculty_filters.extend((User.full_name.ilike(pattern), User.department.ilike(pattern)))
    matched_faculty = (
        db.query(User)
        .filter(User.is_active.is_(True), or_(*faculty_filters))
        .order_by(User.full_name)
        .limit(40)
        .all()
        if faculty_filters
        else []
    )

    division_filters = []
    for term in terms:
        pattern = f"%{term}%"
        division_filters.extend((Division.name.ilike(pattern), Division.division_code.ilike(pattern)))
    requested_years = _requested_years(search_text)
    if requested_years:
        division_filters.append(Division.year.in_(requested_years))
    division_code = re.search(r"\b(?:division|div|section)\s+([a-z])\b", search_text.lower())
    if division_code:
        division_filters.append(Division.division_code.ilike(division_code.group(1)))
    matched_divisions = (
        db.query(Division)
        .filter(or_(*division_filters))
        .order_by(Division.year, Division.division_code)
        .limit(40)
        .all()
        if division_filters
        else []
    )

    context["matched_subjects"] = [
        {
            "name": subject.name,
            "code": subject.code,
        }
        for subject in matched_subjects
    ]
    context["matched_faculty"] = [
        {"name": faculty.full_name, "department": faculty.department}
        for faculty in matched_faculty
    ]
    context["matched_divisions"] = [
        {
            "name": division.name,
            "year": division.year,
            "division_code": division.division_code,
        }
        for division in matched_divisions
    ]

    matched_faculty_ids = {faculty.id for faculty in matched_faculty}
    matched_subject_ids = {subject.id for subject in matched_subjects}
    matched_division_ids = {division.id for division in matched_divisions}
    has_personal_reference = bool(
        re.search(
            r"\b(i|my|mine|me|our|myself)\b|\b(this|current)\s+faculty\b",
            search_text.lower(),
        )
    )
    asks_for_own_schedule = has_personal_reference and (
        _contains_term(search_text, _SCHEDULE_TERMS)
        or _contains_term(search_text, _OWN_COURSE_TERMS)
    )

    assignment_filters = []
    if matched_faculty_ids:
        assignment_filters.append(TeachingAssignment.faculty_id.in_(matched_faculty_ids))
    if matched_subject_ids:
        assignment_filters.append(TeachingAssignment.subject_id.in_(matched_subject_ids))
    if matched_division_ids:
        assignment_filters.append(TeachingAssignment.division_id.in_(matched_division_ids))

    assignment_options = (
        joinedload(TeachingAssignment.faculty),
        joinedload(TeachingAssignment.subject),
        joinedload(TeachingAssignment.division),
    )
    if assignment_filters:
        assignments = (
            db.query(TeachingAssignment)
            .options(*assignment_options)
            .filter(and_(*assignment_filters))
            .order_by(TeachingAssignment.faculty_id, TeachingAssignment.subject_id)
            .limit(100)
            .all()
        )
        context["teaching_assignments"] = [_assignment_fact(item) for item in assignments]

    if asks_for_own_schedule:
        own_assignments = (
            db.query(TeachingAssignment)
            .options(*assignment_options)
            .filter(TeachingAssignment.faculty_id == current_user.id)
            .order_by(TeachingAssignment.subject_id, TeachingAssignment.division_id)
            .limit(100)
            .all()
        )
        context["my_teaching_assignments"] = [
            _assignment_fact(item) for item in own_assignments
        ]

    latest_run = (
        _latest_published_run(db)
        if asks_for_own_schedule
        or matched_faculty_ids
        or matched_subject_ids
        or matched_division_ids
        else None
    )
    if latest_run:
        timetable_query = (
            db.query(TimetableEntry)
            .options(
                joinedload(TimetableEntry.subject),
                joinedload(TimetableEntry.faculty),
                joinedload(TimetableEntry.division),
                joinedload(TimetableEntry.room),
            )
            .filter(TimetableEntry.batch_id == latest_run.id)
        )
        if asks_for_own_schedule:
            own_entries = (
                timetable_query.filter(TimetableEntry.faculty_id == current_user.id)
                .order_by(TimetableEntry.day, TimetableEntry.slot)
                .limit(100)
                .all()
            )
            context["my_published_timetable"] = [_timetable_fact(item) for item in own_entries]

        timetable_filters = []
        if matched_faculty_ids:
            timetable_filters.append(TimetableEntry.faculty_id.in_(matched_faculty_ids))
        if matched_subject_ids:
            timetable_filters.append(TimetableEntry.subject_id.in_(matched_subject_ids))
        if matched_division_ids:
            timetable_filters.append(TimetableEntry.division_id.in_(matched_division_ids))
        if timetable_filters:
            entries = (
                timetable_query.filter(and_(*timetable_filters))
                .order_by(TimetableEntry.day, TimetableEntry.slot)
                .limit(120)
                .all()
            )
            context["published_timetable"] = [_timetable_fact(item) for item in entries]

    if _contains_term(search_text, _TASK_TERMS):
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

    if "attendance" in set(re.findall(r"[a-z0-9]+", search_text.lower())):
        session_count = (
            db.query(func.count(LectureAttendanceSession.session_id))
            .filter(LectureAttendanceSession.faculty_id == current_user.id)
            .scalar()
            or 0
        )
        attendance_rows = (
            db.query(LectureAttendanceRecord.status, func.count(LectureAttendanceRecord.record_id))
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
