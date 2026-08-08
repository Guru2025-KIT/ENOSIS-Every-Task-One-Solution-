import uuid

from sqlalchemy import Column, String, Integer, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship

from app.db.base import Base


class TimetableEntry(Base):
    """
    One scheduled slot: "Division TE-A has DBMS with Dr. Sharma in Room 301
    on Tuesday, period 3." A full generated timetable is just many rows of
    this table, tagged with the `batch_id` of the generation run that
    created them (so we can tell old/new generations apart, and Android's
    read-only viewing screens just query this table — they never touch
    the solver directly).
    """
    __tablename__ = "timetable_entries"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    batch_id = Column(String(36), nullable=False, index=True)

    division_id = Column(String(36), ForeignKey("divisions.id"), nullable=False)
    subject_id = Column(String(36), ForeignKey("subjects.id"), nullable=False)
    faculty_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    room_id = Column(String(36), ForeignKey("rooms.id"), nullable=False)

    day = Column(Integer, nullable=False)
    slot = Column(Integer, nullable=False)
    is_lab_block = Column(Boolean, nullable=False, default=False)

    generated_at = Column(DateTime, nullable=True)

    division = relationship("Division")
    subject = relationship("Subject")
    faculty = relationship("User")
    room = relationship("Room")
