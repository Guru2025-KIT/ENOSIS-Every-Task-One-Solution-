from datetime import date, datetime, timezone
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.academic import Division, Subject
from app.models.attendance import AttendanceStatus, LectureAttendanceRecord, LectureAttendanceSession
from app.models.generation_history import GenerationRun
from app.models.sli import AcademicClass, Enrollment, Student
from app.models.timetable import TimetableEntry
from app.schemas.attendance import (
    AttendanceSessionOut,
    AttendanceSessionSubmitIn,
    StudentAttendanceItemOut,
    StudentAttendanceSummaryOut,
)
from app.services.sli_pre_service import authorize_faculty_teaching_assignment


def _get_authorized_timetable_entry(
    db: Session,
    faculty_id: str,
    timetable_entry_id: str,
    is_admin: bool = False,
) -> tuple[TimetableEntry, AcademicClass, Subject, Division]:
    """
    Validates that a timetable entry exists, is tied to an optimal generation run,
    and the faculty is authorized to access it.
    """
    entry = db.query(TimetableEntry).filter(TimetableEntry.id == timetable_entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Timetable entry not found.")

    # Validate active generation batch
    gen_run = db.query(GenerationRun).filter(GenerationRun.id == entry.batch_id).first()
    if gen_run and gen_run.status != "OPTIMAL":
        raise HTTPException(status_code=400, detail="Timetable batch is not active/optimal.")

    division = db.query(Division).filter(Division.id == entry.division_id).first()
    if not division:
        raise HTTPException(status_code=404, detail="Division not found.")

    subject = db.query(Subject).filter(Subject.id == entry.subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found.")

    academic_class = db.query(AcademicClass).filter(
        (AcademicClass.division_id == division.id) |
        ((AcademicClass.year_level == division.year) & (AcademicClass.division == division.division_code))
    ).first()
    if not academic_class:
        raise HTTPException(status_code=404, detail="Academic class for division not found.")

    # Strict Faculty Authorization: assigned faculty or admin
    if not is_admin and entry.faculty_id != faculty_id:
        # Cross-verify via teaching assignment authorization
        authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division.id, is_admin)

    return entry, academic_class, subject, division


def get_attendance_session_for_slot(
    db: Session,
    faculty_id: str,
    timetable_entry_id: str,
    session_date: date,
    is_admin: bool = False,
) -> AttendanceSessionOut:
    """
    Retrieves or initializes an attendance session for a specific scheduled slot and calendar date.
    Returns the student enrollment roster with saved status or default 'PRESENT'.
    """
    entry, academic_class, subject, division = _get_authorized_timetable_entry(
        db, faculty_id, timetable_entry_id, is_admin
    )

    # 1. Fetch Enrolled Students in this class & subject
    enrollments = (
        db.query(Enrollment, Student)
        .join(Student, Student.student_id == Enrollment.student_id)
        .filter(
            Enrollment.class_id == academic_class.class_id,
            Enrollment.subject_id == subject.id,
        )
        .order_by(Student.name.asc())
        .all()
    )

    # 2. Check if a session has already been recorded
    session = (
        db.query(LectureAttendanceSession)
        .filter(
            LectureAttendanceSession.timetable_entry_id == timetable_entry_id,
            LectureAttendanceSession.session_date == session_date,
        )
        .first()
    )

    records_out: list[StudentAttendanceItemOut] = []
    saved_records_map: dict[int, LectureAttendanceRecord] = {}

    if session:
        for r in session.records:
            saved_records_map[r.enrollment_id] = r

    for enrollment, student in enrollments:
        if enrollment.enrollment_id in saved_records_map:
            saved_rec = saved_records_map[enrollment.enrollment_id]
            records_out.append(
                StudentAttendanceItemOut(
                    enrollment_id=enrollment.enrollment_id,
                    student_id=student.student_id,
                    student_name=student.name,
                    roll_number=student.student_id,
                    status=saved_rec.status,
                    remarks=saved_rec.remarks,
                )
            )
        else:
            records_out.append(
                StudentAttendanceItemOut(
                    enrollment_id=enrollment.enrollment_id,
                    student_id=student.student_id,
                    student_name=student.name,
                    roll_number=student.student_id,
                    status=AttendanceStatus.PRESENT,
                    remarks=None,
                )
            )

    total_enrolled = len(records_out)
    present_count = sum(1 for r in records_out if r.status == AttendanceStatus.PRESENT)
    absent_count = sum(1 for r in records_out if r.status == AttendanceStatus.ABSENT)
    late_count = sum(1 for r in records_out if r.status == AttendanceStatus.LATE)

    # Attended = Present + Late
    attended_count = present_count + late_count
    att_pct = round((attended_count / total_enrolled * 100), 1) if total_enrolled > 0 else 0.0

    return AttendanceSessionOut(
        session_id=session.session_id if session else None,
        timetable_entry_id=timetable_entry_id,
        class_id=academic_class.class_id,
        subject_id=subject.id,
        subject_name=subject.name,
        subject_code=subject.code,
        division_name=division.name,
        year_level=division.year,
        session_date=session_date,
        slot_number=session.slot_number if session else entry.slot,
        topic_taught=session.topic_taught if session else None,
        notes=session.notes if session else None,
        total_enrolled=total_enrolled,
        present_count=present_count,
        absent_count=absent_count,
        late_count=late_count,
        attendance_percentage=att_pct,
        is_recorded=session is not None,
        records=records_out,
        recorded_at=session.recorded_at if session else None,
    )


def submit_lecture_attendance(
    db: Session,
    faculty_id: str,
    payload: AttendanceSessionSubmitIn,
    is_admin: bool = False,
) -> AttendanceSessionOut:
    """
    Records or updates student attendance for a lecture session idempotently.
    Prevents duplicate sessions and updates existing records in place.
    """
    entry, academic_class, subject, division = _get_authorized_timetable_entry(
        db, faculty_id, payload.timetable_entry_id, is_admin
    )

    # Validate that all enrollments in payload belong to this authorized class & subject
    valid_enrollments = {
        e.enrollment_id: e
        for e in db.query(Enrollment).filter(
            Enrollment.class_id == academic_class.class_id,
            Enrollment.subject_id == subject.id,
        ).all()
    }

    for item in payload.records:
        if item.enrollment_id not in valid_enrollments:
            raise HTTPException(
                status_code=400,
                detail=f"Enrollment ID {item.enrollment_id} does not belong to this class and subject context."
            )

    # 1. Upsert LectureAttendanceSession
    session = (
        db.query(LectureAttendanceSession)
        .filter(
            LectureAttendanceSession.timetable_entry_id == payload.timetable_entry_id,
            LectureAttendanceSession.session_date == payload.session_date,
        )
        .first()
    )

    if not session:
        session = LectureAttendanceSession(
            timetable_entry_id=payload.timetable_entry_id,
            class_id=academic_class.class_id,
            subject_id=subject.id,
            faculty_id=entry.faculty_id if not is_admin else faculty_id,
            session_date=payload.session_date,
            slot_number=payload.slot_number,
            topic_taught=payload.topic_taught,
            notes=payload.notes,
        )
        db.add(session)
        db.flush()
    else:
        session.slot_number = payload.slot_number
        session.topic_taught = payload.topic_taught
        session.notes = payload.notes

    # 2. Upsert Student Attendance Records
    existing_records = {
        r.enrollment_id: r
        for r in db.query(LectureAttendanceRecord).filter(
            LectureAttendanceRecord.session_id == session.session_id
        ).all()
    }

    for item in payload.records:
        if item.enrollment_id in existing_records:
            rec = existing_records[item.enrollment_id]
            rec.status = AttendanceStatus(item.status.value)
            rec.remarks = item.remarks
        else:
            rec = LectureAttendanceRecord(
                session_id=session.session_id,
                enrollment_id=item.enrollment_id,
                status=AttendanceStatus(item.status.value),
                remarks=item.remarks,
            )
            db.add(rec)

    db.commit()
    db.refresh(session)

    return get_attendance_session_for_slot(
        db=db,
        faculty_id=faculty_id,
        timetable_entry_id=payload.timetable_entry_id,
        session_date=payload.session_date,
        is_admin=is_admin,
    )


def get_student_attendance_summary(
    db: Session,
    faculty_id: str,
    enrollment_id: int,
    is_admin: bool = False,
) -> StudentAttendanceSummaryOut:
    """
    Computes cumulative derived attendance metrics for a student enrollment
    from recorded lecture attendance sessions.
    """
    enrollment = db.query(Enrollment).filter(Enrollment.enrollment_id == enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == enrollment.class_id).first()
    subject = db.query(Subject).filter(Subject.id == enrollment.subject_id).first()
    student = db.query(Student).filter(Student.student_id == enrollment.student_id).first()

    if not academic_class or not subject or not student:
        raise HTTPException(status_code=404, detail="Associated academic records not found.")

    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division_id, is_admin)

    # Fetch all records for this enrollment
    records = db.query(LectureAttendanceRecord).filter(
        LectureAttendanceRecord.enrollment_id == enrollment_id
    ).all()

    total_sessions = len(records)
    present_sessions = sum(1 for r in records if r.status == AttendanceStatus.PRESENT)
    late_sessions = sum(1 for r in records if r.status == AttendanceStatus.LATE)
    absent_sessions = sum(1 for r in records if r.status == AttendanceStatus.ABSENT)
    attended_sessions = present_sessions + late_sessions

    att_pct = round((attended_sessions / total_sessions * 100), 1) if total_sessions > 0 else 0.0

    return StudentAttendanceSummaryOut(
        enrollment_id=enrollment_id,
        student_id=student.student_id,
        student_name=student.name,
        class_id=academic_class.class_id,
        subject_id=subject.id,
        subject_name=subject.name,
        total_sessions=total_sessions,
        attended_sessions=attended_sessions,
        absent_sessions=absent_sessions,
        late_sessions=late_sessions,
        attendance_percentage=att_pct,
    )
