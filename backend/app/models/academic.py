import enum
import uuid

from sqlalchemy import Column, String, Integer, Boolean, Enum, ForeignKey, JSON
from sqlalchemy.orm import relationship

from app.db.base import Base


class RoomType(str, enum.Enum):
    LECTURE = "lecture"
    LAB = "lab"


class Division(Base):
    """
    A class/section of students — e.g. Year 2, Division "B". Everything in
    a timetable is ultimately organized around: which division is where,
    doing what, at a given day/slot. `year` + `division_code` are the
    structured fields the UI uses for its Year/Division picker; `name` is
    a free-text display label (e.g. "SE-B") an admin can customize.
    """
    __tablename__ = "divisions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False)
    year = Column(Integer, nullable=False, default=1)  # 1-4
    division_code = Column(String(5), nullable=False, default="A")  # "A", "B", "C", ...
    semester = Column(String(20), nullable=True)
    strength = Column(Integer, nullable=False, default=60)  # number of students, for room capacity checks


class Subject(Base):
    """
    A course, e.g. "Database Management Systems". `weekly_lectures` and
    `lab_sessions_per_week` tell the solver how many times this subject
    needs to appear in a division's week — this is the actual input a
    faculty/admin fills in (not something the solver invents).
    """
    __tablename__ = "subjects"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    code = Column(String(50), nullable=True)
    weekly_lectures = Column(Integer, nullable=False, default=0)  # 1-slot lecture sessions/week
    is_lab = Column(Boolean, nullable=False, default=False)
    lab_sessions_per_week = Column(Integer, nullable=False, default=0)
    lab_block_size = Column(Integer, nullable=False, default=2)  # consecutive slots per lab session


class Room(Base):
    """A physical room/lab. `type` gates which subjects can use it."""
    __tablename__ = "rooms"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(100), nullable=False)
    type = Column(Enum(RoomType), nullable=False, default=RoomType.LECTURE)
    capacity = Column(Integer, nullable=False, default=60)


class TeachingAssignment(Base):
    """
    Says "this faculty member teaches this subject to this division" —
    the link the solver needs to know WHO to schedule for each
    division/subject pair. Set up by an admin before generation.
    """
    __tablename__ = "teaching_assignments"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    faculty_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    subject_id = Column(String(36), ForeignKey("subjects.id"), nullable=False)
    division_id = Column(String(36), ForeignKey("divisions.id"), nullable=False)

    faculty = relationship("User")
    subject = relationship("Subject")
    division = relationship("Division")


class FacultyUnavailability(Base):
    """
    "This faculty member cannot teach on day X, slot Y" — e.g. they teach
    at another campus that morning. The solver treats these as hard
    constraints it must respect, not preferences.
    """
    __tablename__ = "faculty_unavailability"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    faculty_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    day = Column(Integer, nullable=False)  # 0 = Monday ... 5 = Saturday
    slot = Column(Integer, nullable=False)  # 0-indexed period of the day


class InstitutionalCourse(Base):
    """
    Fixed/institutional course decided by the college with fixed timings.
    Blocks all normal courses for the configured divisions during this day/slot.
    """
    __tablename__ = "institutional_courses"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    course_name = Column(String(255), nullable=False)
    course_code = Column(String(50), nullable=True)
    year = Column(Integer, nullable=False, default=1)
    divisions = Column(JSON, nullable=False, default=list)  # JSON list of strings (e.g. ["A", "B", "C"])
    day = Column(Integer, nullable=False)  # 0 = Monday ... 5 = Saturday
    start_slot = Column(Integer, nullable=False)  # 0-indexed period of the day
    duration_slots = Column(Integer, nullable=False, default=1)
    faculty_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    room_id = Column(String(36), ForeignKey("rooms.id"), nullable=True)

    faculty = relationship("User")
    room = relationship("Room")


class SharedCourse(Base):
    """
    Shared/mixed-division course where students from multiple divisions attend
    together at the same time and in the exact same room.
    """
    __tablename__ = "shared_courses"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    course_name = Column(String(255), nullable=False)
    course_code = Column(String(50), nullable=True)
    year = Column(Integer, nullable=False, default=1)
    divisions = Column(JSON, nullable=False, default=list)  # JSON list of strings (e.g. ["A", "B"])
    faculty_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    room_id = Column(String(36), ForeignKey("rooms.id"), nullable=True)
    duration_slots = Column(Integer, nullable=False, default=1)
    weekly_sessions = Column(Integer, nullable=False, default=1)
    session_type = Column(String(50), nullable=False, default="lecture")  # "lecture" or "lab"

    faculty = relationship("User")
    room = relationship("Room")
