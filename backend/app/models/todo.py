import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Boolean, DateTime, Text, ForeignKey

from app.db.base import Base


class Task(Base):
    """
    A personal to-do item. Unlike Timetable, this has no admin/delegation
    concept — every faculty member only ever sees and manages their OWN
    tasks (enforced by filtering on owner_id == current_user.id in every
    route, never trusting a task id alone).
    """
    __tablename__ = "tasks"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    due_date = Column(DateTime, nullable=True)
    priority = Column(String(10), nullable=False, default="medium")  # "low" | "medium" | "high"
    is_completed = Column(Boolean, nullable=False, default=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
