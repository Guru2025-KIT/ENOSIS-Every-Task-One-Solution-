"""
TimetableConstraint — generic, extensible constraint store.

Instead of hardcoding every possible constraint type as a separate DB table,
we store constraints as typed JSON blobs.  The solver converts them into
OR-Tools constructs at solve time.  This makes it trivial to add new
constraint types (soft preferences, combined-division lectures, room
reservations, etc.) without a schema migration.

Constraint types implemented so far
────────────────────────────────────
HARD constraints (must never be violated):
  faculty_unavailability   day + slot + faculty_id
  room_unavailability      day + slot + room_id
  fixed_slot               division_id + subject_id + day + slot
  max_lectures_per_day     faculty_id + max_count

SOFT constraints (optimised, but violation is allowed):
  avoid_first_period       faculty_id
  avoid_last_period        faculty_id
  prefer_morning           faculty_id
  avoid_consecutive_same   division_id + subject_id
  preferred_room           subject_id + room_id
  preferred_slot           subject_id + day + slot
  balance_daily_load       (global)
"""
import uuid

from sqlalchemy import Column, String, Boolean, JSON, DateTime
from sqlalchemy.sql import func

from app.db.base import Base


class TimetableConstraint(Base):
    __tablename__ = "timetable_constraints"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))

    # One of the type strings listed in the module docstring above
    constraint_type = Column(String(80), nullable=False, index=True)

    # "hard" → violation makes the problem infeasible
    # "soft" → violation is penalised in the objective
    priority = Column(String(10), nullable=False, default="hard")

    # Flexible data bag — exact keys depend on constraint_type (see docstring)
    payload = Column(JSON, nullable=False, default=dict)

    # Human-readable summary shown in the constraint list UI
    description = Column(String(500), nullable=False, default="")

    # Whether this constraint is currently active (UI can toggle without deleting)
    is_active = Column(Boolean, nullable=False, default=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
