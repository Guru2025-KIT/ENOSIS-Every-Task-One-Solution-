from datetime import date, timedelta
import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.models.academic import Division, Subject, Room
from app.models.achievement import Achievement, AchievementCategory
from app.models.attendance import AttendanceStatus, LectureAttendanceRecord, LectureAttendanceSession
from app.models.document import Document  # Required for Achievement foreign key
from app.models.generation_history import GenerationRun
from app.models.schedule_config import ScheduleConfig
from app.models.sli import AcademicClass, Department, Enrollment, MidSemesterResponse, PreSemesterResponse, Semester, Student
from app.models.timetable import TimetableEntry
from app.models.todo import Task
from app.models.user import User, UserRole
from app.schemas.attendance import AttendanceSessionSubmitIn, StudentAttendanceItemIn
from app.services.attendance_service import (
    get_attendance_session_for_slot,
    get_student_attendance_summary,
    submit_lecture_attendance,
)
from app.services.dashboard_service import get_faculty_dashboard_summary


@pytest.fixture
def db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()


def _seed_test_environment(session):
    # Faculty Users
    f1 = User(id="fac-1", email="fac1@college.edu", hashed_password="pw", full_name="Dr. Alan Turing", department="CSE", role=UserRole.FACULTY)
    f2 = User(id="fac-2", email="fac2@college.edu", hashed_password="pw", full_name="Dr. Ada Lovelace", department="CSE", role=UserRole.FACULTY)
    admin = User(id="admin-1", email="admin@college.edu", hashed_password="pw", full_name="Admin User", department="Admin", role=UserRole.ADMIN)
    session.add_all([f1, f2, admin])

    # Divisions
    d1 = Division(id="div-1", name="TE-A", year=3, division_code="A")
    d2 = Division(id="div-2", name="TE-B", year=3, division_code="B")
    session.add_all([d1, d2])

    # Subjects
    s1 = Subject(id="sub-1", code="CS301", name="Operating Systems", is_lab=False)
    s2 = Subject(id="sub-2", code="CS302", name="Database Systems", is_lab=False)
    session.add_all([s1, s2])

    # Room
    r1 = Room(id="room-1", name="Lab 301", capacity=60)
    session.add(r1)

    # Department
    dept = Department(department_id=1, department_name="Computer Science & Engineering", department_code="CSE")
    session.add(dept)

    # Semester
    sem = Semester(semester_id=1, academic_year="2025-2026", semester_number=5, status="ACTIVE")
    session.add(sem)

    # Academic Classes
    ac1 = AcademicClass(class_id=101, department_id=1, year_level=3, division="A", division_id="div-1")
    ac2 = AcademicClass(class_id=102, department_id=1, year_level=3, division="B", division_id="div-2")
    session.add_all([ac1, ac2])

    # Students & Enrollments
    st1 = Student(student_id="ST001", name="Alice Johnson", email="alice@test.com", department_id=1)
    st2 = Student(student_id="ST002", name="Bob Smith", email="bob@test.com", department_id=1)
    st3 = Student(student_id="ST003", name="Charlie Brown", email="charlie@test.com", department_id=1)
    session.add_all([st1, st2, st3])

    e1 = Enrollment(enrollment_id=1, student_id="ST001", class_id=101, subject_id="sub-1", semester_id=1)
    e2 = Enrollment(enrollment_id=2, student_id="ST002", class_id=101, subject_id="sub-1", semester_id=1)
    e3 = Enrollment(enrollment_id=3, student_id="ST003", class_id=102, subject_id="sub-2", semester_id=1)
    session.add_all([e1, e2, e3])

    # Generation Run
    gen_run = GenerationRun(id="gen-batch-1", status="OPTIMAL")
    session.add(gen_run)

    # Timetable Entry (Day 0 = Monday, Slot 1)
    tt1 = TimetableEntry(
        id="tt-entry-1",
        batch_id="gen-batch-1",
        division_id="div-1",
        subject_id="sub-1",
        faculty_id="fac-1",
        room_id="room-1",
        day=0,
        slot=1,
        is_lab_block=False,
    )
    # Timetable Entry for f2 (Day 0, Slot 2)
    tt2 = TimetableEntry(
        id="tt-entry-2",
        batch_id="gen-batch-1",
        division_id="div-2",
        subject_id="sub-2",
        faculty_id="fac-2",
        room_id="room-1",
        day=0,
        slot=2,
        is_lab_block=False,
    )
    session.add_all([tt1, tt2])

    # Tasks for fac-1
    t1 = Task(id="task-1", owner_id="fac-1", title="Prepare Midterm Paper", priority="high", is_completed=False)
    t2 = Task(id="task-2", owner_id="fac-1", title="Review Lab Manual", priority="medium", is_completed=True)
    t3 = Task(id="task-3", owner_id="fac-1", title="Grade Assignments", priority="low", is_completed=False)
    session.add_all([t1, t2, t3])

    # Achievements for fac-1
    ach1 = Achievement(id="ach-1", owner_id="fac-1", title="Published IEEE Paper", category=AchievementCategory.PUBLICATION)
    session.add(ach1)

    session.commit()
    return f1, f2, admin


def test_attendance_session_roster_retrieval(db_session):
    f1, f2, admin = _seed_test_environment(db_session)
    session_date = date(2026, 9, 8)

    # Authorized faculty f1 loads slot
    roster = get_attendance_session_for_slot(
        db=db_session,
        faculty_id="fac-1",
        timetable_entry_id="tt-entry-1",
        session_date=session_date,
        is_admin=False,
    )

    assert roster.timetable_entry_id == "tt-entry-1"
    assert roster.class_id == 101
    assert roster.subject_name == "Operating Systems"
    assert roster.total_enrolled == 2
    assert roster.is_recorded is False
    assert len(roster.records) == 2
    assert {r.student_name for r in roster.records} == {"Alice Johnson", "Bob Smith"}


def test_attendance_authorization_guards(db_session):
    f1, f2, admin = _seed_test_environment(db_session)
    session_date = date(2026, 9, 8)

    # Unauthorized faculty f2 attempts to view f1's timetable entry
    with pytest.raises(HTTPException) as exc_info:
        get_attendance_session_for_slot(
            db=db_session,
            faculty_id="fac-2",
            timetable_entry_id="tt-entry-1",
            session_date=session_date,
            is_admin=False,
        )
    assert exc_info.value.status_code == 403

    # Admin is authorized to view any slot
    admin_roster = get_attendance_session_for_slot(
        db=db_session,
        faculty_id="admin-1",
        timetable_entry_id="tt-entry-1",
        session_date=session_date,
        is_admin=True,
    )
    assert admin_roster.total_enrolled == 2


def test_submit_lecture_attendance_and_idempotency(db_session):
    f1, f2, admin = _seed_test_environment(db_session)
    session_date = date(2026, 9, 8)

    # 1. Submit initial attendance
    payload = AttendanceSessionSubmitIn(
        timetable_entry_id="tt-entry-1",
        session_date=session_date,
        slot_number=1,
        topic_taught="Process Synchronization & Semaphores",
        notes="All students participated actively.",
        records=[
            StudentAttendanceItemIn(enrollment_id=1, status=AttendanceStatus.PRESENT),
            StudentAttendanceItemIn(enrollment_id=2, status=AttendanceStatus.ABSENT, remarks="Medical leave"),
        ],
    )

    saved = submit_lecture_attendance(
        db=db_session,
        faculty_id="fac-1",
        payload=payload,
        is_admin=False,
    )

    assert saved.is_recorded is True
    assert saved.present_count == 1
    assert saved.absent_count == 1
    assert saved.late_count == 0
    assert saved.attendance_percentage == 50.0

    # Verify session count in DB
    sessions_count = db_session.query(LectureAttendanceSession).count()
    assert sessions_count == 1

    # 2. Re-submit with update (Bob marked LATE instead of ABSENT)
    payload_update = AttendanceSessionSubmitIn(
        timetable_entry_id="tt-entry-1",
        session_date=session_date,
        slot_number=1,
        topic_taught="Process Synchronization & Semaphores (Revised)",
        notes="Updated attendance status.",
        records=[
            StudentAttendanceItemIn(enrollment_id=1, status=AttendanceStatus.PRESENT),
            StudentAttendanceItemIn(enrollment_id=2, status=AttendanceStatus.LATE, remarks="Arrived 10 mins late"),
        ],
    )

    updated = submit_lecture_attendance(
        db=db_session,
        faculty_id="fac-1",
        payload=payload_update,
        is_admin=False,
    )

    # Check that session count remains exactly 1 (Idempotent update)
    assert db_session.query(LectureAttendanceSession).count() == 1
    assert updated.present_count == 1
    assert updated.late_count == 1
    assert updated.absent_count == 0
    assert updated.attendance_percentage == 100.0  # Present + Late


def test_invalid_enrollment_rejection(db_session):
    f1, f2, admin = _seed_test_environment(db_session)
    session_date = date(2026, 9, 8)

    # Enrollment 3 belongs to class 102 / sub-2, not class 101 / sub-1
    invalid_payload = AttendanceSessionSubmitIn(
        timetable_entry_id="tt-entry-1",
        session_date=session_date,
        slot_number=1,
        topic_taught="Invalid Session",
        records=[
            StudentAttendanceItemIn(enrollment_id=3, status=AttendanceStatus.PRESENT),
        ],
    )

    with pytest.raises(HTTPException) as exc_info:
        submit_lecture_attendance(
            db=db_session,
            faculty_id="fac-1",
            payload=invalid_payload,
            is_admin=False,
        )
    assert exc_info.value.status_code == 400


def test_student_derived_attendance_summary(db_session):
    f1, f2, admin = _seed_test_environment(db_session)

    # Record 2 sessions on different dates
    for d, st_alice, st_bob in [
        (date(2026, 9, 1), AttendanceStatus.PRESENT, AttendanceStatus.ABSENT),
        (date(2026, 9, 2), AttendanceStatus.PRESENT, AttendanceStatus.LATE),
    ]:
        submit_lecture_attendance(
            db=db_session,
            faculty_id="fac-1",
            payload=AttendanceSessionSubmitIn(
                timetable_entry_id="tt-entry-1",
                session_date=d,
                slot_number=1,
                records=[
                    StudentAttendanceItemIn(enrollment_id=1, status=st_alice),
                    StudentAttendanceItemIn(enrollment_id=2, status=st_bob),
                ],
            ),
            is_admin=False,
        )

    # Derive Alice's Summary (Enrollment 1) -> 2/2 = 100%
    alice_summary = get_student_attendance_summary(
        db=db_session,
        faculty_id="fac-1",
        enrollment_id=1,
        is_admin=False,
    )
    assert alice_summary.total_sessions == 2
    assert alice_summary.attended_sessions == 2
    assert alice_summary.absent_sessions == 0
    assert alice_summary.attendance_percentage == 100.0

    # Derive Bob's Summary (Enrollment 2) -> 1/2 = 50% (1 Absent, 1 Late)
    bob_summary = get_student_attendance_summary(
        db=db_session,
        faculty_id="fac-1",
        enrollment_id=2,
        is_admin=False,
    )
    assert bob_summary.total_sessions == 2
    assert bob_summary.attended_sessions == 1
    assert bob_summary.late_sessions == 1
    assert bob_summary.absent_sessions == 1
    assert bob_summary.attendance_percentage == 50.0


def test_dashboard_aggregator_summary(db_session):
    f1, f2, admin = _seed_test_environment(db_session)

    # Date corresponding to Monday (Day 0)
    monday_date = date(2026, 9, 7)  # 2026-09-07 is Monday

    summary = get_faculty_dashboard_summary(
        db=db_session,
        faculty_user=f1,
        target_date=monday_date,
    )

    assert summary.faculty_id == "fac-1"
    assert summary.faculty_name == "Dr. Alan Turing"
    assert summary.classes_today_count == 1
    assert summary.classes_completed_count == 0
    assert summary.classes_upcoming_count == 1
    assert summary.pending_tasks_count == 2
    assert summary.high_priority_tasks_count == 1
    assert summary.verified_achievements_count == 1
    assert len(summary.today_schedule) == 1
    assert summary.today_schedule[0].subject_name == "Operating Systems"
    assert summary.today_schedule[0].status == "UPCOMING"
    assert summary.today_schedule[0].attendance_recorded is False

    # Now record attendance for this Monday lecture
    submit_lecture_attendance(
        db=db_session,
        faculty_id="fac-1",
        payload=AttendanceSessionSubmitIn(
            timetable_entry_id="tt-entry-1",
            session_date=monday_date,
            slot_number=1,
            topic_taught="OS Overview",
            records=[
                StudentAttendanceItemIn(enrollment_id=1, status=AttendanceStatus.PRESENT),
                StudentAttendanceItemIn(enrollment_id=2, status=AttendanceStatus.PRESENT),
            ],
        ),
        is_admin=False,
    )

    # Re-fetch dashboard summary
    updated_summary = get_faculty_dashboard_summary(
        db=db_session,
        faculty_user=f1,
        target_date=monday_date,
    )

    assert updated_summary.classes_completed_count == 1
    assert updated_summary.classes_upcoming_count == 0
    assert updated_summary.today_schedule[0].status == "COMPLETED"
    assert updated_summary.today_schedule[0].attendance_recorded is True


def test_dashboard_empty_behavior(db_session):
    f1, f2, admin = _seed_test_environment(db_session)

    # Sunday has no scheduled classes
    sunday_date = date(2026, 9, 13)
    summary = get_faculty_dashboard_summary(
        db=db_session,
        faculty_user=f1,
        target_date=sunday_date,
    )

    assert summary.classes_today_count == 0
    assert summary.classes_completed_count == 0
    assert summary.classes_upcoming_count == 0
    assert len(summary.today_schedule) == 0
    assert summary.pending_tasks_count == 2
