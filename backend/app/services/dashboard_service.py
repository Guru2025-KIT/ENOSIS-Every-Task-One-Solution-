from datetime import date, datetime, timedelta
from sqlalchemy.orm import Session

from app.models.academic import Division, Subject
from app.models.achievement import Achievement
from app.models.attendance import LectureAttendanceSession
from app.models.generation_history import GenerationRun
from app.models.schedule_config import ScheduleConfig
from app.models.sli import AcademicClass, Enrollment, Semester
from app.models.timetable import TimetableEntry
from app.models.todo import Task
from app.models.user import User
from app.schemas.dashboard import DashboardSummaryOut, TodayScheduleSlotOut
from app.services.sli_analytics_service import get_student_longitudinal_analytics
from app.services.sli_pre_service import get_faculty_teaching_contexts


def _format_slot_time(slot: int, config: ScheduleConfig | None) -> str:
    start_hour = 9
    start_min = 0
    duration_min = 60

    if config and config.start_time:
        try:
            parts = config.start_time.split(":")
            start_hour = int(parts[0])
            start_min = int(parts[1])
        except Exception:
            pass
        if config.period_duration_minutes:
            duration_min = config.period_duration_minutes

    # slot can be 0-based or 1-based; adjust if slot >= 1
    slot_offset = slot if slot < 8 else (slot - 1)
    slot_start = datetime(2000, 1, 1, start_hour, start_min) + timedelta(minutes=slot_offset * duration_min)
    slot_end = slot_start + timedelta(minutes=duration_min)
    return f"{slot_start.strftime('%I:%M %p')} - {slot_end.strftime('%I:%M %p')}"


import uuid
from app.models.academic import Division, Room, Subject, TeachingAssignment
from app.models.achievement import Achievement, AchievementCategory
from app.models.generation_history import GenerationRun
from app.models.sli import AcademicClass, Department, Enrollment, PreSemesterResponse, MidSemesterResponse, Semester, Student, Topic
from app.models.timetable import TimetableEntry
from app.models.todo import Task


def ensure_faculty_complete_academic_data(db: Session, faculty_user: User):
    """
    Ensures essential system tables exist (e.g. Department, active Semester)
    without seeding artificial dummy subjects or timetable entries.
    Real academic data comes from faculty-uploaded Excel and generated timetables.
    """
    try:
        dept = db.query(Department).first()
        if not dept:
            dept = Department(department_name="Computer Science & Engineering", department_code="CSE")
            db.add(dept)
            db.flush()

        sem = db.query(Semester).filter(Semester.status == "ACTIVE").first()
        if not sem:
            sem = Semester(academic_year="2026-27", semester_number=1, status="ACTIVE")
            db.add(sem)
            db.flush()

        db.commit()
    except Exception as e:
        db.rollback()
        print(f"[Academic Base Provision Notice]: {e}")


def get_faculty_dashboard_summary(
    db: Session,
    faculty_user: User,
    target_date: date | None = None,
) -> DashboardSummaryOut:
    """
    Composes a read-only operational dashboard DTO for the faculty member.
    Aggregates:
    - Today's timetable schedule & recorded attendance status
    - Pending to-do tasks and priority counts
    - Verified career achievements
    - SLI critical and attention students across teaching contexts
    """
    # Guarantee full academic profile & timetable exists for this faculty
    ensure_faculty_complete_academic_data(db, faculty_user)

    today = target_date or date.today()
    day_idx = today.weekday()  # Monday=0, Tuesday=1, ...
    day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    day_name = day_names[day_idx] if 0 <= day_idx < 7 else "Today"

    # Helper to clean faculty names
    def _normalize_name(name_str: str) -> str:
        s = name_str.lower().strip()
        for prefix in ["dr.", "dr ", "prof.", "prof ", "mr.", "mr ", "mrs.", "mrs ", "ms.", "ms "]:
            if s.startswith(prefix):
                s = s[len(prefix):].strip()
        return s

    # 1. Fetch Schedule Config for time calculations
    config = db.query(ScheduleConfig).first()

    # 2. Get active generation run if any
    active_run = db.query(GenerationRun).filter(GenerationRun.status == "OPTIMAL").order_by(GenerationRun.generated_at.desc()).first()
    batch_id = active_run.id if active_run else None

    # 3. Query Faculty Timetable for Selected Day
    is_admin = (
        (faculty_user.role.value if hasattr(faculty_user.role, "value") else str(faculty_user.role)).lower() == "admin"
    )

    # Resolve all matching user IDs for this faculty
    target_clean = _normalize_name(faculty_user.full_name or "")
    target_tokens = set(target_clean.split())

    all_users = db.query(User).all()
    matched_user_ids = {faculty_user.id}

    if target_clean:
        for u in all_users:
            if not u.full_name:
                continue
            u_clean = _normalize_name(u.full_name)
            u_tokens = set(u_clean.split())
            if target_clean in u_clean or u_clean in target_clean or (target_tokens and target_tokens.issubset(u_tokens)) or (u_tokens and u_tokens.issubset(target_tokens)):
                matched_user_ids.add(u.id)
            elif u.email and faculty_user.email:
                if u.email.split('@')[0].lower() == faculty_user.email.split('@')[0].lower():
                    matched_user_ids.add(u.id)

    # Query entries for matched users on TODAY's day_idx
    query = db.query(TimetableEntry).filter(
        TimetableEntry.day == day_idx,
    )
    if batch_id:
        query = query.filter(TimetableEntry.batch_id == batch_id)

    entries = query.filter(TimetableEntry.faculty_id.in_(list(matched_user_ids))).order_by(TimetableEntry.slot.asc()).all()

    # Fallback 1: if no entries in latest batch, search across any batch for today
    if not entries:
        entries = (
            db.query(TimetableEntry)
            .filter(
                TimetableEntry.faculty_id.in_(list(matched_user_ids)),
                TimetableEntry.day == day_idx,
            )
            .order_by(TimetableEntry.slot.asc())
            .all()
        )

    # Fallback 2: check if faculty has teaching assignments for any lectures scheduled today
    if not entries:
        ta_pairs = db.query(
            TeachingAssignment.subject_id,
            TeachingAssignment.division_id,
        ).filter(TeachingAssignment.faculty_id.in_(list(matched_user_ids))).all()

        for sub_id, div_id in ta_pairs:
            matched_entries = db.query(TimetableEntry).filter(
                TimetableEntry.day == day_idx,
                TimetableEntry.subject_id == sub_id,
                TimetableEntry.division_id == div_id,
            ).order_by(TimetableEntry.slot.asc()).all()
            for me in matched_entries:
                if me not in entries:
                    entries.append(me)
        entries.sort(key=lambda e: e.slot)

    # Fallback 3: if admin user and no personal schedule, show today's departmental lecture overview
    if not entries and is_admin:
        admin_q = db.query(TimetableEntry).filter(TimetableEntry.day == day_idx)
        if batch_id:
            admin_q = admin_q.filter(TimetableEntry.batch_id == batch_id)
        entries = admin_q.order_by(TimetableEntry.slot.asc()).all()
        if not entries:
            entries = db.query(TimetableEntry).filter(TimetableEntry.day == day_idx).order_by(TimetableEntry.slot.asc()).all()

    is_multi_day_view = False

    # 4. Map Timetable Entries to TodayScheduleSlotOut
    today_schedule: list[TodayScheduleSlotOut] = []
    classes_completed = 0

    for entry in entries:
        # Check if attendance is recorded for this entry and date
        attendance_session = (
            db.query(LectureAttendanceSession)
            .filter(
                LectureAttendanceSession.timetable_entry_id == entry.id,
                LectureAttendanceSession.session_date == today,
            )
            .first()
        )

        division = entry.division
        subject = entry.subject
        room = entry.room

        # Academic Class lookup
        academic_class = None
        if division:
            academic_class = db.query(AcademicClass).filter(
                (AcademicClass.division_id == division.id) |
                ((AcademicClass.year_level == division.year) & (AcademicClass.division == division.division_code))
            ).first()

        # Active Semester lookup
        semester = db.query(Semester).filter(Semester.status == "ACTIVE").first()

        is_recorded = attendance_session is not None
        status_str = "COMPLETED" if is_recorded else "UPCOMING"
        if is_recorded:
            classes_completed += 1

        base_time = _format_slot_time(entry.slot, config)
        if is_multi_day_view and 0 <= entry.day < len(day_names):
            time_range = f"{day_names[entry.day][:3]} · {base_time}"
        else:
            time_range = base_time

        slot_num_display = entry.slot if entry.slot >= 1 else (entry.slot + 1)

        today_schedule.append(
            TodayScheduleSlotOut(
                timetable_entry_id=entry.id,
                slot_number=slot_num_display,
                time_range=time_range,
                subject_id=entry.subject_id,
                subject_name=subject.name if subject else "Course Lecture",
                subject_code=subject.code if subject else None,
                division_name=division.name if division else "Class",
                room_name=room.name if room else "Room",
                is_lab=entry.is_lab_block,
                class_id=academic_class.class_id if academic_class else None,
                semester_id=semester.semester_id if semester else None,
                status=status_str,
                attendance_recorded=is_recorded,
                session_id=attendance_session.session_id if attendance_session else None,
            )
        )

    classes_today_count = len(today_schedule)
    classes_upcoming_count = max(0, classes_today_count - classes_completed)

    # 5. Pending Tasks
    pending_tasks = db.query(Task).filter(
        Task.owner_id == faculty_user.id,
        Task.is_completed == False,
    ).all()
    pending_tasks_count = len(pending_tasks)
    high_priority_tasks_count = sum(1 for t in pending_tasks if (t.priority or "").lower() in ("high", "urgent"))

    # 6. Career Achievements
    achievements_count = db.query(Achievement).filter(
        Achievement.owner_id == faculty_user.id
    ).count()

    # 7. SLI Critical & Attention Students Count across Faculty Teaching Contexts
    sli_attention_count = 0
    sli_critical_count = 0

    try:
        is_admin_user = (
            faculty_user.role.value == "admin"
            if hasattr(faculty_user.role, "value")
            else faculty_user.role == "admin"
        )
        faculty_contexts = get_faculty_teaching_contexts(
            db=db,
            faculty_id=faculty_user.id,
            is_admin=is_admin_user,
        )

        seen_enrollment_ids = set()
        for ctx in faculty_contexts:
            class_id = ctx.get("class_id")
            subject_id = ctx.get("subject_id")
            sem_id = ctx.get("semester_id")

            if not class_id or not subject_id:
                continue

            query = db.query(Enrollment).filter(
                Enrollment.class_id == class_id,
                Enrollment.subject_id == subject_id,
            )
            if sem_id:
                query = query.filter(Enrollment.semester_id == sem_id)

            for e in query.all():
                if e.enrollment_id in seen_enrollment_ids:
                    continue
                seen_enrollment_ids.add(e.enrollment_id)
                try:
                    student_analytics = get_student_longitudinal_analytics(
                        db=db,
                        faculty_id=faculty_user.id,
                        enrollment_id=e.enrollment_id,
                        is_admin=True,
                    )
                    is_crit = False
                    is_att = False

                    findings = student_analytics.risk_findings or []
                    if findings:
                        if any(f.severity == "CRITICAL" for f in findings):
                            is_crit = True
                        else:
                            is_att = True

                    ml_pred = student_analytics.ml_prediction or {}
                    risk_lvl = (ml_pred.get("risk_level") or "").upper()
                    if risk_lvl in ["HIGH", "HIGH_RISK", "CRITICAL"]:
                        is_crit = True
                    elif risk_lvl in ["MODERATE", "MEDIUM", "MEDIUM_RISK", "ATTENTION"]:
                        if not is_crit:
                            is_att = True

                    if is_crit:
                        sli_critical_count += 1
                    elif is_att:
                        sli_attention_count += 1
                except Exception:
                    continue
    except Exception:
        pass

    return DashboardSummaryOut(
        faculty_id=faculty_user.id,
        faculty_name=faculty_user.full_name,
        faculty_email=faculty_user.email,
        department_name=faculty_user.department,
        today_date=today,
        day_name=day_name,
        classes_today_count=classes_today_count,
        classes_completed_count=classes_completed,
        classes_upcoming_count=classes_upcoming_count,
        pending_tasks_count=pending_tasks_count,
        high_priority_tasks_count=high_priority_tasks_count,
        sli_attention_students_count=sli_attention_count,
        sli_critical_students_count=sli_critical_count,
        verified_achievements_count=achievements_count,
        today_schedule=today_schedule,
    )
