"""
GenerationRun — timetable generation history.

Each call to POST /timetable/generate creates exactly one row here.
The row is written even if the solver returns INFEASIBLE — in that case
conflicts/suggestions are recorded so the user can see what went wrong and
regenerate after fixing constraints, without losing the previous attempt.

The `batch_id` here matches the `batch_id` on TimetableEntry rows so you
can cross-reference "which run produced these timetable entries?"
"""
import uuid

from sqlalchemy import Column, String, Integer, Float, Boolean, JSON, DateTime
from sqlalchemy.sql import func

from app.db.base import Base


class GenerationRun(Base):
    __tablename__ = "generation_runs"

    # Matches TimetableEntry.batch_id for the entries produced by this run
    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))

    generated_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    # "OPTIMAL" | "FEASIBLE" | "INFEASIBLE" | "UNKNOWN" | "ERROR"
    status = Column(String(20), nullable=False)

    solve_time_seconds = Column(Float, nullable=True)
    total_entries = Column(Integer, nullable=False, default=0)

    # CP-SAT objective value (higher = more soft constraints satisfied)
    objective_score = Column(Float, nullable=True)

    # Whether the independent post-solve validator passed
    validation_passed = Column(Boolean, nullable=True)

    # Snapshot of the ScheduleConfig used (so history is self-contained even
    # if the config changes afterward)
    config_snapshot = Column(JSON, nullable=True)

    # Structured conflict list when INFEASIBLE
    # e.g. [{"type": "no_compatible_room", "subject": "AI Lab", ...}]
    conflicts = Column(JSON, nullable=True)

    # Auto-generated suggestions for fixing conflicts
    suggestions = Column(JSON, nullable=True)

    # Full solver log (constraint counts, search stats) — for debugging
    solver_log = Column(String(4000), nullable=True)
