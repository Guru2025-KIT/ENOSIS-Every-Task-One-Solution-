import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Boolean, DateTime, Text, ForeignKey, Integer, JSON
from sqlalchemy.orm import relationship

from app.db.base import Base


class TaskPriority(str, enum.Enum):
    URGENT = "urgent"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"

    @classmethod
    def normalize(cls, val: str | None) -> str:
        if not val:
            return cls.MEDIUM.value
        cleaned = str(val).strip().lower()
        if cleaned in {"urgent", "high", "medium", "low"}:
            return cleaned
        return cls.MEDIUM.value


class TaskStatus(str, enum.Enum):
    TODO = "TODO"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    SNOOZED = "SNOOZED"

    @classmethod
    def normalize(cls, val: str | None) -> str:
        if not val:
            return cls.TODO.value
        cleaned = str(val).strip().upper()
        if cleaned in {"TODO", "IN_PROGRESS", "COMPLETED", "SNOOZED"}:
            return cleaned
        return cls.TODO.value


class ReminderStatus(str, enum.Enum):
    SCHEDULED = "SCHEDULED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"
    SNOOZED = "SNOOZED"


class ReminderType(str, enum.Enum):
    PRE_DUE = "PRE_DUE"
    DUE = "DUE"
    OVERDUE = "OVERDUE"
    SNOOZE = "SNOOZE"


class Task(Base):
    """
    A personal to-do item for ENOSIS faculty productivity.
    Enforces strict ownership: every faculty member only ever manages their
    own tasks (owner_id == current_user.id).
    """
    __tablename__ = "tasks"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    due_date = Column(DateTime, nullable=True, index=True)
    priority = Column(String(10), nullable=False, default="medium", index=True)  # "urgent" | "high" | "medium" | "low"
    status = Column(String(20), nullable=False, default="TODO", index=True)      # "TODO" | "IN_PROGRESS" | "COMPLETED" | "SNOOZED"
    is_completed = Column(Boolean, nullable=False, default=False)                # Kept synchronized with status == "COMPLETED"

    category = Column(String(100), nullable=True)
    tags = Column(JSON, nullable=True)                                          # list[str]
    estimated_duration_minutes = Column(Integer, nullable=True)
    recurrence_rule = Column(JSON, nullable=True)                               # dict e.g. {"frequency": "DAILY|WEEKDAYS|WEEKLY|MONTHLY|YEARLY", "interval": 1}
    reminders_config = Column(JSON, nullable=True)                              # dict e.g. {"is_custom": bool, "custom_offsets": [int]}
    subtasks = Column(JSON, nullable=True)                                      # list of dicts: [{"id": "...", "title": "...", "is_completed": bool}]

    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relationship to dedicated reminder schedule records
    reminders = relationship("TaskReminder", back_populates="task", cascade="all, delete-orphan", lazy="joined")


class TaskReminder(Base):
    """
    Dedicated reminder entity for deterministic reminder lifecycle management.
    Prevents duplicate notifications across synchronization and allows
    per-offset cancellation, delivery tracking, and snoozing.
    """
    __tablename__ = "task_reminders"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    task_id = Column(String(36), ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False, index=True)
    occurrence_key = Column(String(50), nullable=False, default="base")
    offset_minutes = Column(Integer, nullable=False)                            # e.g. 1440 (24h), 180 (3h), 30 (30m)
    trigger_at = Column(DateTime, nullable=False, index=True)
    reminder_type = Column(String(20), nullable=False, default="PRE_DUE")        # PRE_DUE, DUE, OVERDUE, SNOOZE
    status = Column(String(20), nullable=False, default="SCHEDULED", index=True) # SCHEDULED, DELIVERED, CANCELLED, SNOOZED

    scheduled_notification_id = Column(Integer, nullable=True)                  # Numeric ID for local OS notification
    delivered_at = Column(DateTime, nullable=True)
    fingerprint = Column(String(150), unique=True, index=True, nullable=False)   # Unique idempotency key

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    task = relationship("Task", back_populates="reminders")
