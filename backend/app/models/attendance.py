import enum
from sqlalchemy import (
    Column, Date, DateTime, Enum, ForeignKey, Integer, String, Text, UniqueConstraint, func
)
from sqlalchemy.orm import relationship

from app.db.base import Base


class AttendanceStatus(str, enum.Enum):
    PRESENT = "PRESENT"
    ABSENT = "ABSENT"
    LATE = "LATE"


class LectureAttendanceSession(Base):
    """
    Session-level ledger entry for one specific lecture or lab slot
    taught on a specific calendar date.
    
    Uniqueness on (timetable_entry_id, session_date) ensures that submitting
    attendance for the same scheduled lecture slot twice updates the existing
    session rather than creating duplicate sessions.
    """
    __tablename__ = "lecture_attendance_sessions"

    session_id = Column(Integer, primary_key=True, autoincrement=True)
    timetable_entry_id = Column(
        String(36),
        ForeignKey("timetable_entries.id"),
        nullable=False,
        index=True,
    )
    class_id = Column(
        Integer,
        ForeignKey("classes.class_id"),
        nullable=False,
        index=True,
    )
    subject_id = Column(
        String(36),
        ForeignKey("subjects.id"),
        nullable=False,
        index=True,
    )
    faculty_id = Column(
        String(36),
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )
    session_date = Column(Date, nullable=False, index=True)
    slot_number = Column(Integer, nullable=False)
    topic_taught = Column(String(255), nullable=True)
    notes = Column(Text, nullable=True)
    recorded_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("timetable_entry_id", "session_date", name="uq_timetable_entry_session_date"),
    )

    # Relationships
    records = relationship("LectureAttendanceRecord", back_populates="session", cascade="all, delete-orphan")


class LectureAttendanceRecord(Base):
    """
    Individual student attendance status for a single lecture session.
    Unique on (session_id, enrollment_id) to prevent duplicate student marks per session.
    """
    __tablename__ = "lecture_attendance_records"

    record_id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(
        Integer,
        ForeignKey("lecture_attendance_sessions.session_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    enrollment_id = Column(
        Integer,
        ForeignKey("enrollments.enrollment_id"),
        nullable=False,
        index=True,
    )
    status = Column(Enum(AttendanceStatus), nullable=False, default=AttendanceStatus.PRESENT)
    remarks = Column(String(255), nullable=True)

    __table_args__ = (
        UniqueConstraint("session_id", "enrollment_id", name="uq_session_enrollment"),
    )

    # Relationships
    session = relationship("LectureAttendanceSession", back_populates="records")
