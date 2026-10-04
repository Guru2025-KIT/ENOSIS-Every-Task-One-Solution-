import io
import csv
import re
import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.security import hash_password
from app.models.user import User, UserRole
from app.models.academic import Subject, Division, TeachingAssignment
from app.models.achievement import Achievement
from app.schemas.admin import (
    AdminDashboardStatsOut, SubjectAllocationOut, SubjectAllocationCreate,
    SubjectReassignRequest, GovernanceRequestOut, GovernanceActionRequest
)
from app.schemas.user import (
    FacultyCreate, FacultyUpdate, FacultyOut,
    FacultyImportRow, FacultyValidationResult, FacultyImportPayload
)


EMAIL_REGEX = re.compile(r"^[\w\.-]+@[\w\.-]+\.\w+$")


# ─── 1. REAL-TIME ADMIN DASHBOARD STATS ───────────────────────────────────────

def get_admin_dashboard_stats(db: Session) -> AdminDashboardStatsOut:
    """
    Direct SQL aggregations for live dashboard metrics.
    No mock data or static random values.
    """
    total_faculty = db.query(User).filter(User.role == UserRole.FACULTY).count()
    active_faculty = db.query(User).filter(User.role == UserRole.FACULTY, User.is_active == True).count()
    allocated_courses = db.query(TeachingAssignment).count()
    
    # Department breakdown
    dept_rows = (
        db.query(User.department, func.count(User.id))
        .filter(User.role == UserRole.FACULTY, User.is_active == True)
        .group_by(User.department)
        .all()
    )
    department_counts = {
        (dept or "General"): count for dept, count in dept_rows
    }

    # Governance: count pending achievements
    pending_gov = db.query(Achievement).count()
    
    # Attainment calculation: percentage of subjects with teaching assignments
    total_subjects = db.query(Subject).count()
    attainment_pct = int((allocated_courses / total_subjects * 100)) if total_subjects > 0 else 0
    if attainment_pct > 100:
        attainment_pct = 100

    return AdminDashboardStatsOut(
        total_faculty=total_faculty,
        active_faculty=active_faculty,
        allocated_courses_count=allocated_courses,
        attainment_completed_percent=attainment_pct,
        pending_governance_count=pending_gov,
        department_counts=department_counts,
    )


# ─── 2. FACULTY CRUD ─────────────────────────────────────────────────────────

def list_faculty(
    db: Session,
    department: str | None = None,
    search: str | None = None,
    is_active: bool | None = None
) -> list[FacultyOut]:
    query = db.query(User).filter(User.role == UserRole.FACULTY)

    if is_active is not None:
        query = query.filter(User.is_active == is_active)

    if department and department.lower() != "all":
        query = query.filter(User.department == department)

    if search:
        s = f"%{search.strip().lower()}%"
        query = query.filter(
            func.lower(User.full_name).like(s) |
            func.lower(User.email).like(s) |
            func.lower(User.employee_id).like(s) |
            func.lower(User.designation).like(s)
        )

    users = query.order_by(User.full_name.asc()).all()
    
    # Fetch assigned subject codes for each faculty
    faculty_ids = [u.id for u in users]
    assignments = (
        db.query(TeachingAssignment.faculty_id, Subject.code)
        .join(Subject, TeachingAssignment.subject_id == Subject.id)
        .filter(TeachingAssignment.faculty_id.in_(faculty_ids))
        .all()
    ) if faculty_ids else []

    assigned_map: dict[str, list[str]] = {}
    for fac_id, sub_code in assignments:
        if sub_code:
            assigned_map.setdefault(fac_id, []).append(sub_code)

    results = []
    for u in users:
        results.append(FacultyOut(
            id=u.id,
            full_name=u.full_name,
            email=u.email,
            employee_id=u.employee_id,
            department=u.department,
            designation=u.designation or "Assistant Professor",
            phone=u.phone,
            is_active=u.is_active,
            can_manage_timetable=u.can_manage_timetable,
            assigned_subject_codes=assigned_map.get(u.id, []),
            created_at=u.created_at,
        ))
    return results


def create_single_faculty(db: Session, payload: FacultyCreate) -> FacultyOut:
    # Check email / employee_id uniqueness
    existing_email = db.query(User).filter(func.lower(User.email) == payload.email.lower()).first()
    if existing_email:
        raise ValueError(f"A user with email '{payload.email}' already exists.")

    if payload.employee_id:
        existing_emp = db.query(User).filter(func.lower(User.employee_id) == payload.employee_id.lower()).first()
        if existing_emp:
            raise ValueError(f"A faculty member with Employee ID '{payload.employee_id}' already exists.")

    temp_password = payload.password or "Enosis@123"
    hashed = hash_password(temp_password)

    user = User(
        id=str(uuid.uuid4()),
        email=payload.email.lower().strip(),
        hashed_password=hashed,
        full_name=payload.full_name.strip(),
        employee_id=payload.employee_id.strip() if payload.employee_id else None,
        department=payload.department.strip() if payload.department else None,
        designation=payload.designation.strip() if payload.designation else "Assistant Professor",
        phone=payload.phone.strip() if payload.phone else None,
        office_address=payload.office_address.strip() if payload.office_address else None,
        joining_date=payload.joining_date.strip() if payload.joining_date else None,
        experience=payload.experience.strip() if payload.experience else None,
        role=UserRole.FACULTY,
        is_active=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return FacultyOut(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        employee_id=user.employee_id,
        department=user.department,
        designation=user.designation,
        phone=user.phone,
        office_address=user.office_address,
        joining_date=user.joining_date,
        experience=user.experience,
        is_active=user.is_active,
        can_manage_timetable=user.can_manage_timetable,
        assigned_subject_codes=[],
        created_at=user.created_at,
    )


def update_single_faculty(db: Session, user_id: str, payload: FacultyUpdate) -> FacultyOut:
    user = db.query(User).filter(User.id == user_id, User.role == UserRole.FACULTY).first()
    if not user:
        raise KeyError("Faculty member not found.")

    if payload.email and payload.email.lower() != user.email.lower():
        existing = db.query(User).filter(func.lower(User.email) == payload.email.lower(), User.id != user_id).first()
        if existing:
            raise ValueError(f"Email '{payload.email}' is already in use by another user.")
        user.email = payload.email.lower().strip()

    if payload.employee_id and payload.employee_id != user.employee_id:
        existing = db.query(User).filter(func.lower(User.employee_id) == payload.employee_id.lower(), User.id != user_id).first()
        if existing:
            raise ValueError(f"Employee ID '{payload.employee_id}' is already in use.")
        user.employee_id = payload.employee_id.strip()

    if payload.full_name is not None:
        user.full_name = payload.full_name.strip()
    if payload.department is not None:
        user.department = payload.department.strip()
    if payload.designation is not None:
        user.designation = payload.designation.strip()
    if payload.phone is not None:
        user.phone = payload.phone.strip()
    if payload.office_address is not None:
        user.office_address = payload.office_address.strip()
    if payload.joining_date is not None:
        user.joining_date = payload.joining_date.strip()
    if payload.experience is not None:
        user.experience = payload.experience.strip()
    if payload.is_active is not None:
        user.is_active = payload.is_active
    if payload.can_manage_timetable is not None:
        user.can_manage_timetable = payload.can_manage_timetable

    db.commit()
    db.refresh(user)

    assignments = (
        db.query(Subject.code)
        .join(TeachingAssignment, TeachingAssignment.subject_id == Subject.id)
        .filter(TeachingAssignment.faculty_id == user.id)
        .all()
    )
    assigned_codes = [c[0] for c in assignments if c[0]]

    return FacultyOut(
        id=user.id,
        full_name=user.full_name,
        email=user.email,
        employee_id=user.employee_id,
        department=user.department,
        designation=user.designation,
        phone=user.phone,
        office_address=user.office_address,
        joining_date=user.joining_date,
        experience=user.experience,
        is_active=user.is_active,
        can_manage_timetable=user.can_manage_timetable,
        assigned_subject_codes=assigned_codes,
        created_at=user.created_at,
    )


def delete_single_faculty(db: Session, user_id: str) -> dict[str, str]:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise KeyError("Faculty member not found.")
    
    role_str = (user.role.value if hasattr(user.role, "value") else str(user.role)).upper()
    if role_str == "ADMIN":
        raise ValueError("Cannot delete the system administrator account.")

    faculty_name = user.full_name or user.email

    # Clean up all referencing tables
    try:
        from app.models.academic import TeachingAssignment, FacultyUnavailability, InstitutionalCourse, SharedCourse
        db.query(TeachingAssignment).filter(TeachingAssignment.faculty_id == user_id).delete(synchronize_session=False)
        db.query(FacultyUnavailability).filter(FacultyUnavailability.faculty_id == user_id).delete(synchronize_session=False)
        db.query(InstitutionalCourse).filter(InstitutionalCourse.faculty_id == user_id).delete(synchronize_session=False)
        db.query(SharedCourse).filter(SharedCourse.faculty_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty Academic Cleanup Notice]:", e)

    try:
        from app.models.timetable import TimetableEntry
        db.query(TimetableEntry).filter(TimetableEntry.faculty_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty Timetable Cleanup Notice]:", e)

    try:
        from app.models.attendance import LectureAttendanceSession, LectureAttendanceRecord
        session_ids = [s[0] for s in db.query(LectureAttendanceSession.session_id).filter(LectureAttendanceSession.faculty_id == user_id).all()]
        if session_ids:
            db.query(LectureAttendanceRecord).filter(LectureAttendanceRecord.session_id.in_(session_ids)).delete(synchronize_session=False)
        db.query(LectureAttendanceSession).filter(LectureAttendanceSession.faculty_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty Attendance Cleanup Notice]:", e)


    try:
        from app.models.sli import Assessment, Intervention, PreSemesterResponse, MidSemesterResponse, EndSemesterResponse, StudentTopicFeedback
        assessment_ids = [a[0] for a in db.query(Assessment.assessment_id).filter(Assessment.faculty_id == user_id).all()]
        if assessment_ids:
            db.query(PreSemesterResponse).filter(PreSemesterResponse.assessment_id.in_(assessment_ids)).delete(synchronize_session=False)
            db.query(MidSemesterResponse).filter(MidSemesterResponse.assessment_id.in_(assessment_ids)).delete(synchronize_session=False)
            db.query(EndSemesterResponse).filter(EndSemesterResponse.assessment_id.in_(assessment_ids)).delete(synchronize_session=False)
            db.query(StudentTopicFeedback).filter(StudentTopicFeedback.assessment_id.in_(assessment_ids)).delete(synchronize_session=False)
        db.query(Assessment).filter(Assessment.faculty_id == user_id).delete(synchronize_session=False)
        db.query(Intervention).filter(Intervention.faculty_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty SLI Cleanup Notice]:", e)

    try:
        from app.models.achievement import Achievement
        db.query(Achievement).filter(Achievement.owner_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty Achievement Cleanup Notice]:", e)

    try:
        from app.models.todo import Task
        db.query(Task).filter(Task.owner_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty Task Cleanup Notice]:", e)

    try:
        from app.models.notification import Notification
        db.query(Notification).filter(Notification.recipient_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty Notification Cleanup Notice]:", e)

    try:
        from app.models.document import Document
        db.query(Document).filter(Document.owner_id == user_id).delete(synchronize_session=False)
    except Exception as e:
        print("[Delete Faculty Document Cleanup Notice]:", e)

    db.delete(user)
    db.commit()

    return {"status": "deleted", "message": f"Faculty member '{faculty_name}' was removed successfully."}




# ─── 3. SPREADSHEET DRY-RUN VALIDATION & BULK IMPORT ─────────────────────────

def _extract_raw_rows(content: bytes, filename: str) -> list[dict[str, str]]:
    raw_rows: list[dict[str, str]] = []
    
    if filename.lower().endswith(".csv"):
        text = content.decode("utf-8-sig", errors="replace")
        reader = csv.DictReader(io.StringIO(text))
        for row in reader:
            cleaned = {k.strip().lower(): (v.strip() if v else "") for k, v in row.items() if k}
            raw_rows.append(cleaned)
    else:
        try:
            import openpyxl
            wb = openpyxl.load_workbook(io.BytesIO(content), data_only=True)
            ws = wb.active
            headers = [str(cell.value).strip().lower() for cell in next(ws.iter_rows(min_row=1, max_row=1)) if cell.value]
            for row in ws.iter_rows(min_row=2, values_only=True):
                if not row or not any(row):
                    continue
                row_dict = {}
                for idx, val in enumerate(row):
                    if idx < len(headers):
                        row_dict[headers[idx]] = str(val).strip() if val is not None else ""
                raw_rows.append(row_dict)
        except Exception as e:
            raise ValueError(f"Failed to read spreadsheet file: {str(e)}")

    return raw_rows


def _get_val(row: dict[str, str], aliases: list[str]) -> str:
    for alias in aliases:
        for k in row.keys():
            if alias in k:
                return row[k].strip()
    return ""


def validate_faculty_spreadsheet(db: Session, filename: str, content: bytes) -> FacultyValidationResult:
    raw_rows = _extract_raw_rows(content, filename)
    
    # Existing DB lookups
    existing_emails = {u.email.lower(): u for u in db.query(User).all()}
    existing_emps = {u.employee_id.lower(): u for u in db.query(User).filter(User.employee_id.isnot(None)).all()}

    seen_file_emails: set[str] = set()
    seen_file_emps: set[str] = set()

    valid_records: list[FacultyImportRow] = []
    invalid_records: list[FacultyImportRow] = []
    duplicate_records: list[FacultyImportRow] = []
    missing_records: list[FacultyImportRow] = []

    for idx, row in enumerate(raw_rows, start=2):  # Row 1 is header
        full_name = _get_val(row, ["name", "faculty", "full_name"])
        email = _get_val(row, ["email", "mail"])
        employee_id = _get_val(row, ["emp", "employee", "code", "id"])
        department = _get_val(row, ["dept", "department", "branch"])
        designation = _get_val(row, ["desig", "designation", "role", "post"]) or "Assistant Professor"
        phone = _get_val(row, ["phone", "mobile", "contact", "tel"])

        record = FacultyImportRow(
            row_number=idx,
            full_name=full_name,
            email=email,
            employee_id=employee_id,
            department=department,
            designation=designation,
            phone=phone,
        )

        # 1. Missing Required Fields
        missing_fields = []
        if not full_name:
            missing_fields.append("Full Name")
        if not email:
            missing_fields.append("Email")
        if not employee_id:
            missing_fields.append("Employee ID")
        if not department:
            missing_fields.append("Department")

        if missing_fields:
            record.error = f"Missing required field(s): {', '.join(missing_fields)}"
            missing_records.append(record)
            continue

        # 2. Format Validations
        if not EMAIL_REGEX.match(email):
            record.error = f"Invalid email format: '{email}'"
            invalid_records.append(record)
            continue

        # 3. Duplicate checks (Within file and against database)
        norm_email = email.lower()
        norm_emp = employee_id.lower()

        if norm_email in seen_file_emails:
            record.error = f"Duplicate email in file: '{email}' (already listed in earlier row)"
            duplicate_records.append(record)
            continue

        if norm_emp in seen_file_emps:
            record.error = f"Duplicate Employee ID in file: '{employee_id}' (already listed in earlier row)"
            duplicate_records.append(record)
            continue

        if norm_email in existing_emails:
            record.error = f"Email '{email}' already registered in database for '{existing_emails[norm_email].full_name}'"
            duplicate_records.append(record)
            continue

        if norm_emp in existing_emps:
            record.error = f"Employee ID '{employee_id}' already registered in database for '{existing_emps[norm_emp].full_name}'"
            duplicate_records.append(record)
            continue

        # Passed all validations!
        seen_file_emails.add(norm_email)
        seen_file_emps.add(norm_emp)
        valid_records.append(record)

    return FacultyValidationResult(
        total_rows=len(raw_rows),
        valid_count=len(valid_records),
        invalid_count=len(invalid_records),
        duplicate_count=len(duplicate_records),
        missing_fields_count=len(missing_records),
        valid_records=valid_records,
        invalid_records=invalid_records,
        duplicate_records=duplicate_records,
        missing_records=missing_records,
        valid_rows=valid_records,
        invalid_rows=invalid_records,
        duplicate_rows=duplicate_records,
        missing_fields_rows=missing_records,
    )


def bulk_import_faculty(db: Session, payload: FacultyImportPayload) -> dict[str, int]:
    imported_count = 0
    default_hashed = hash_password("Enosis@123")

    rows_to_import = payload.rows if payload.rows else payload.records
    for rec in rows_to_import:
        # Final safety check on duplicates
        existing = db.query(User).filter(
            (func.lower(User.email) == rec.email.lower()) |
            (func.lower(User.employee_id) == rec.employee_id.lower())
        ).first()

        if existing:
            continue

        user = User(
            id=str(uuid.uuid4()),
            email=rec.email.lower().strip(),
            hashed_password=default_hashed,
            full_name=rec.full_name.strip(),
            employee_id=rec.employee_id.strip(),
            department=rec.department.strip(),
            designation=rec.designation.strip() if rec.designation else "Assistant Professor",
            phone=rec.phone.strip() if rec.phone else None,
            role=UserRole.FACULTY,
            is_active=True,
        )
        db.add(user)
        imported_count += 1

    db.commit()
    return {"imported_count": imported_count}


# ─── 4. SUBJECT ALLOCATION MANAGEMENT ───────────────────────────────────────

def list_subject_allocations(
    db: Session,
    year: str | None = None,
    semester: str | None = None,
    department: str | None = None,
) -> list[SubjectAllocationOut]:
    query = (
        db.query(TeachingAssignment, Subject, Division, User)
        .join(Subject, TeachingAssignment.subject_id == Subject.id)
        .join(Division, TeachingAssignment.division_id == Division.id)
        .join(User, TeachingAssignment.faculty_id == User.id)
    )

    if department and department.lower() != "all":
        query = query.filter(User.department == department)

    assignments = query.all()
    results = []

    for ta, sub, div, fac in assignments:
        year_str = f"Year {div.year}"
        sem_str = div.semester or f"Semester {div.year * 2}"

        if year and year.lower() not in year_str.lower():
            continue
        if semester and semester.lower() not in sem_str.lower():
            continue

        results.append(SubjectAllocationOut(
            id=ta.id,
            course_code=sub.code or "SUB001",
            course_name=sub.name,
            department=fac.department or "CSE (AI & ML)",
            year=year_str,
            semester=sem_str,
            credits=int(getattr(sub, "credits", 3) or 3),
            faculty_id=fac.id,
            faculty_name=fac.full_name,
            co_faculty_name="None",
            attainment_status="In Progress",
        ))

    return results


def create_subject_allocation(db: Session, payload: SubjectAllocationCreate) -> SubjectAllocationOut:
    # 1. Ensure Subject
    subject = db.query(Subject).filter(Subject.code == payload.course_code.strip().upper()).first()
    if not subject:
        subject = Subject(
            id=str(uuid.uuid4()),
            name=payload.course_name.strip(),
            code=payload.course_code.strip().upper(),
            weekly_lectures=3,
        )
        db.add(subject)
        db.flush()

    # 2. Ensure Division
    division = db.query(Division).first()
    if not division:
        division = Division(
            id=str(uuid.uuid4()),
            name=f"{payload.year} - Div A",
            year=2,
            division_code="A",
            semester=payload.semester,
        )
        db.add(division)
        db.flush()

    # 3. Create TeachingAssignment
    assignment = TeachingAssignment(
        id=str(uuid.uuid4()),
        faculty_id=payload.faculty_id,
        subject_id=subject.id,
        division_id=division.id,
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)

    faculty = db.query(User).filter(User.id == payload.faculty_id).first()

    return SubjectAllocationOut(
        id=assignment.id,
        course_code=subject.code or payload.course_code,
        course_name=subject.name,
        department=payload.department,
        year=payload.year,
        semester=payload.semester,
        credits=payload.credits,
        faculty_id=payload.faculty_id,
        faculty_name=faculty.full_name if faculty else "Unknown",
        co_faculty_name=payload.co_faculty_name,
        attainment_status="Not Started",
    )


def reassign_subject_allocation(db: Session, allocation_id: str, payload: SubjectReassignRequest) -> SubjectAllocationOut:
    assignment = db.query(TeachingAssignment).filter(TeachingAssignment.id == allocation_id).first()
    if not assignment:
        raise KeyError("Teaching assignment allocation not found.")

    new_faculty = db.query(User).filter(User.id == payload.faculty_id).first()
    if not new_faculty:
        raise KeyError("Target faculty member not found.")

    assignment.faculty_id = new_faculty.id
    db.commit()
    db.refresh(assignment)

    sub = db.query(Subject).filter(Subject.id == assignment.subject_id).first()
    div = db.query(Division).filter(Division.id == assignment.division_id).first()

    return SubjectAllocationOut(
        id=assignment.id,
        course_code=sub.code if sub else "SUB001",
        course_name=sub.name if sub else "Course",
        department=new_faculty.department or "CSE (AI & ML)",
        year=f"Year {div.year}" if div else "S.Y. B.Tech",
        semester=div.semester if div and div.semester else "Semester IV",
        credits=3,
        faculty_id=new_faculty.id,
        faculty_name=new_faculty.full_name,
        co_faculty_name=payload.co_faculty_name or "None",
        attainment_status="In Progress",
    )


# ─── 5. GOVERNANCE & APPROVAL REQUESTS ──────────────────────────────────────

def list_governance_requests(db: Session, status_filter: str | None = None) -> list[GovernanceRequestOut]:
    achievements = (
        db.query(Achievement, User)
        .join(User, Achievement.owner_id == User.id)
        .order_by(Achievement.created_at.desc())
        .all()
    )

    results = []
    for ach, u in achievements:
        results.append(GovernanceRequestOut(
            id=ach.id,
            faculty_id=u.id,
            faculty_name=u.full_name,
            type=ach.category.value.upper() if hasattr(ach.category, "value") else str(ach.category).upper(),
            title=ach.title,
            status="PENDING",
            submitted_at=ach.created_at or datetime.now(timezone.utc),
            document_url=None,
        ))

    return results


def process_governance_action(db: Session, request_id: str, payload: GovernanceActionRequest) -> GovernanceRequestOut:
    achievement = db.query(Achievement).filter(Achievement.id == request_id).first()
    if not achievement:
        raise KeyError("Governance request not found.")

    u = db.query(User).filter(User.id == achievement.owner_id).first()
    fac_name = u.full_name if u else "Faculty"

    if payload.action.upper() == "REJECT":
        db.delete(achievement)
        db.commit()
        return GovernanceRequestOut(
            id=request_id,
            faculty_id=achievement.owner_id,
            faculty_name=fac_name,
            type=achievement.category.value.upper() if hasattr(achievement.category, "value") else str(achievement.category).upper(),
            title=achievement.title,
            status="REJECTED",
            submitted_at=achievement.created_at or datetime.now(timezone.utc),
        )
    else:
        return GovernanceRequestOut(
            id=request_id,
            faculty_id=achievement.owner_id,
            faculty_name=fac_name,
            type=achievement.category.value.upper() if hasattr(achievement.category, "value") else str(achievement.category).upper(),
            title=achievement.title,
            status="APPROVED",
            submitted_at=achievement.created_at or datetime.now(timezone.utc),
        )


# ─── 6. PASSWORD RESET & CREDENTIAL DISPATCH ────────────────────────────────

def _generate_temp_password(length: int = 12) -> str:
    """Generate a secure random password for faculty onboarding / reset."""
    import secrets
    import string
    alphabet = string.ascii_letters + string.digits + "!@#$%"
    return "".join(secrets.choice(alphabet) for _ in range(length))


def reset_faculty_password(db: Session, user_id: str, send_email_flag: bool = True) -> dict:
    """Admin-triggered password reset: generates a new temp password and
    optionally sends it to the faculty member's email."""
    from app.services.email_service import send_password_reset_email

    user = db.query(User).filter(User.id == user_id, User.role == UserRole.FACULTY).first()
    if not user:
        raise KeyError("Faculty member not found.")

    temp_password = _generate_temp_password()
    user.hashed_password = hash_password(temp_password)
    db.commit()

    email_sent = False
    if send_email_flag:
        email_sent = send_password_reset_email(user.email, temp_password)

    return {
        "status": "password_reset",
        "faculty_name": user.full_name,
        "faculty_email": user.email,
        "temp_password": temp_password,  # returned so admin can see it in the UI
        "email_sent": email_sent,
    }


def send_onboarding_credentials(db: Session, user_id: str, password: str) -> dict:
    """Send (or re-send) the onboarding welcome email with credentials."""
    from app.services.email_service import send_onboarding_email

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise KeyError("User not found.")

    email_sent = send_onboarding_email(user.full_name, user.email, password)
    return {
        "status": "onboarding_sent",
        "faculty_name": user.full_name,
        "email_sent": email_sent,
    }


def create_single_faculty_with_email(db: Session, payload) -> tuple:
    """Create a faculty member AND send onboarding credentials.
    Returns (FacultyOut, temp_password, email_sent)."""
    from app.services.email_service import send_onboarding_email

    temp_password = payload.password or _generate_temp_password()
    # Override the payload password with the generated one
    payload_dict = payload.model_dump()
    payload_dict["password"] = temp_password

    from app.schemas.user import FacultyCreate
    updated_payload = FacultyCreate(**payload_dict)

    faculty_out = create_single_faculty(db, updated_payload)
    email_sent = send_onboarding_email(faculty_out.full_name, faculty_out.email, temp_password)

    return faculty_out, temp_password, email_sent


# ─── 7. ADMIN EMAIL SETTINGS (runtime-editable) ─────────────────────────────

def get_email_settings() -> dict:
    """Return current SMTP / admin email configuration (passwords masked)."""
    from app.core.config import settings as s
    return {
        "admin_email": s.ADMIN_EMAIL,
        "smtp_host": s.SMTP_HOST,
        "smtp_port": s.SMTP_PORT,
        "smtp_user": s.SMTP_USER,
        "smtp_configured": bool(s.SMTP_HOST and s.SMTP_USER and s.SMTP_PASSWORD),
    }


def update_email_settings(payload) -> dict:
    """Update SMTP / admin email settings at runtime (in-memory) and persist to .env file."""
    import os
    from app.core.config import settings as s

    updates = {}
    if payload.admin_email is not None:
        s.ADMIN_EMAIL = payload.admin_email
        updates["ADMIN_EMAIL"] = payload.admin_email
    if payload.smtp_host is not None:
        s.SMTP_HOST = payload.smtp_host
        updates["SMTP_HOST"] = payload.smtp_host
    if payload.smtp_port is not None:
        s.SMTP_PORT = payload.smtp_port
        updates["SMTP_PORT"] = str(payload.smtp_port)
    if payload.smtp_user is not None:
        s.SMTP_USER = payload.smtp_user
        updates["SMTP_USER"] = payload.smtp_user
    if payload.smtp_password is not None:
        s.SMTP_PASSWORD = payload.smtp_password
        updates["SMTP_PASSWORD"] = payload.smtp_password
    if payload.smtp_use_tls is not None:
        s.SMTP_USE_TLS = payload.smtp_use_tls
        updates["SMTP_USE_TLS"] = "true" if payload.smtp_use_tls else "false"

    # Persist to .env file
    if updates:
        for candidate in [
            os.path.join(os.getcwd(), ".env"),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), ".env"),
        ]:
            if os.path.exists(candidate):
                try:
                    with open(candidate, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                    new_lines = []
                    found = set()
                    for line in lines:
                        trimmed = line.strip()
                        if trimmed and not trimmed.startswith("#") and "=" in trimmed:
                            k = trimmed.split("=", 1)[0].strip()
                            if k in updates:
                                new_lines.append(f"{k}={updates[k]}\n")
                                found.add(k)
                                continue
                        new_lines.append(line)
                    for k, v in updates.items():
                        if k not in found:
                            new_lines.append(f"{k}={v}\n")
                    with open(candidate, "w", encoding="utf-8") as f:
                        f.writelines(new_lines)
                    break
                except Exception as e:
                    print("[Notice: Could not write SMTP config to .env]:", e)

    return get_email_settings()



# ─── 8. FACULTY PERFORMANCE & PROFILE ────────────────────────────────────────

def get_faculty_performance(db: Session, faculty_id: str) -> dict:
    """Return comprehensive performance, allocations, achievements, timetable schedule, and teaching metrics for a faculty member."""
    from app.models.timetable import TimetableEntry
    from app.models.academic import Room, Division

    user = db.query(User).filter(User.id == faculty_id).first()
    if not user:
        raise KeyError(f"Faculty with ID '{faculty_id}' not found.")

    # 1. Course Allocations & Workload
    assignments = (
        db.query(TeachingAssignment, Subject, Division)
        .join(Subject, TeachingAssignment.subject_id == Subject.id)
        .outerjoin(Division, TeachingAssignment.division_id == Division.id)
        .filter(TeachingAssignment.faculty_id == faculty_id)
        .all()
    )
    allocations = []
    total_lecture_hours = 0
    total_lab_hours = 0

    for ta, subj, div in assignments:
        is_lab = subj.is_lab or (ta.session_type and ta.session_type.lower() == "lab")
        weekly_count = ta.weekly_count or subj.weekly_lectures or 3
        if is_lab:
            total_lab_hours += weekly_count
        else:
            total_lecture_hours += weekly_count

        allocations.append({
            "assignment_id": ta.id,
            "subject_code": subj.code or "N/A",
            "subject_name": subj.name,
            "division": div.name if div else "All",
            "weekly_lectures": weekly_count,
            "is_lab": is_lab,
            "credits": float(subj.credits) if subj.credits else 3.0,
            "session_type": "Lab" if is_lab else "Theory",
        })

    # 2. Timetable Schedule & Load
    timetable_entries = (
        db.query(TimetableEntry, Subject, Room, Division)
        .join(Subject, TimetableEntry.subject_id == Subject.id)
        .outerjoin(Room, TimetableEntry.room_id == Room.id)
        .outerjoin(Division, TimetableEntry.division_id == Division.id)
        .filter(TimetableEntry.faculty_id == faculty_id)
        .all()
    )

    day_labels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    schedule_list = []
    for entry, subj, room, div in timetable_entries:
        day_str = day_labels[entry.day] if 0 <= entry.day < len(day_labels) else f"Day {entry.day + 1}"
        schedule_list.append({
            "day": day_str,
            "day_index": entry.day,
            "slot": entry.slot + 1,
            "subject_code": subj.code,
            "subject_name": subj.name,
            "division": div.name if div else "Class",
            "room": room.name if room else "Room N/A",
            "type": "Lab" if entry.is_lab_block else "Theory",
            "batch": entry.batch_name or "All",
        })

    schedule_list.sort(key=lambda s: (s["day_index"], s["slot"]))

    # 3. Achievements (Publications, Certifications, FDPs, Awards)
    achievements = (
        db.query(Achievement)
        .filter(Achievement.owner_id == faculty_id)
        .order_by(Achievement.created_at.desc())
        .all()
    )
    achievements_list = []
    achievements_by_category = {}
    for a in achievements:
        cat = a.category.value if hasattr(a.category, "value") else str(a.category)
        achievements_by_category[cat] = achievements_by_category.get(cat, 0) + 1
        achievements_list.append({
            "id": a.id,
            "title": a.title,
            "category": cat.upper(),
            "date": a.date_achieved.strftime("%d %b %Y") if a.date_achieved else None,
            "organization": a.organization or "Institution / Body",
            "description": a.description or "",
            "has_proof": bool(a.document_id),
        })

    # 4. SLI Student metrics
    from app.models.sli import Enrollment, PreSemesterResponse, MidSemesterResponse
    subject_ids = [ta.subject_id for ta, _, _ in assignments]
    if subject_ids:
        pre_responses_count = (
            db.query(PreSemesterResponse)
            .join(Enrollment, PreSemesterResponse.enrollment_id == Enrollment.enrollment_id)
            .filter(Enrollment.subject_id.in_(subject_ids))
            .count()
        )
        mid_responses_count = (
            db.query(MidSemesterResponse)
            .join(Enrollment, MidSemesterResponse.enrollment_id == Enrollment.enrollment_id)
            .filter(Enrollment.subject_id.in_(subject_ids))
            .count()
        )
    else:
        pre_responses_count = 0
        mid_responses_count = 0

    # 5. Attendance Sessions conducted
    from app.models.attendance import LectureAttendanceSession
    attendance_count = db.query(LectureAttendanceSession).filter(LectureAttendanceSession.faculty_id == faculty_id).count()

    total_workload_hours = total_lecture_hours + total_lab_hours

    return {
        "faculty": {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "employee_id": user.employee_id or "N/A",
            "department": user.department or "General",
            "designation": user.designation or "Assistant Professor",
            "phone": user.phone or "Not provided",
            "office_address": user.office_address or "Not provided",
            "joining_date": user.joining_date or "Not provided",
            "experience": user.experience or "Not provided",
            "is_active": user.is_active,
            "can_manage_timetable": user.can_manage_timetable,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        },
        "metrics": {
            "allocated_courses_count": len(allocations),
            "weekly_timetable_slots": len(timetable_entries),
            "total_lecture_hours": total_lecture_hours,
            "total_lab_hours": total_lab_hours,
            "total_workload_hours": total_workload_hours,
            "total_achievements": len(achievements),
            "achievements_by_category": achievements_by_category,
            "sli_pre_responses": pre_responses_count,
            "sli_mid_responses": mid_responses_count,
            "attendance_sessions_logged": attendance_count,
        },
        "allocations": allocations,
        "schedule": schedule_list,
        "achievements": achievements_list,
    }


# ─── 9. ADMIN PROFILE (Username, Email & Password update) ─────────────────────
def update_admin_profile(db: Session, admin_user: User, payload) -> User:
    """Updates admin username (full_name), email, and password."""
    from app.core.config import settings as s
    from app.core.security import hash_password, verify_password

    if payload.email is not None:
        clean_email = payload.email.strip().lower()
        if clean_email != admin_user.email.lower():
            existing = db.query(User).filter(func.lower(User.email) == clean_email, User.id != admin_user.id).first()
            if existing:
                raise ValueError(f"An account with email '{payload.email}' already exists.")
            admin_user.email = clean_email
            s.ADMIN_EMAIL = clean_email

    if payload.full_name is not None and payload.full_name.strip():
        admin_user.full_name = payload.full_name.strip()

    if payload.new_password is not None and payload.new_password.strip():
        new_pw = payload.new_password.strip()
        if len(new_pw) < 6:
            raise ValueError("New password must be at least 6 characters long.")
        if not payload.current_password or not payload.current_password.strip():
            raise ValueError("Current password is required to change password.")
        if not verify_password(payload.current_password.strip(), admin_user.hashed_password):
            raise ValueError("Current password is incorrect.")
        admin_user.hashed_password = hash_password(new_pw)

    db.commit()
    db.refresh(admin_user)
    return admin_user




