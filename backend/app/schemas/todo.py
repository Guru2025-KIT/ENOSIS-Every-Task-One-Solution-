from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict, field_validator

_VALID_PRIORITIES = {"urgent", "high", "medium", "low"}
_VALID_STATUSES = {"TODO", "IN_PROGRESS", "COMPLETED", "SNOOZED"}


class SubtaskItem(BaseModel):
    id: str
    title: str
    is_completed: bool = False


class SubtaskCreate(BaseModel):
    title: str


class SubtaskUpdate(BaseModel):
    title: str | None = None
    is_completed: bool | None = None


class RecurrenceRuleSchema(BaseModel):
    frequency: str  # "DAILY" | "WEEKDAYS" | "WEEKLY" | "MONTHLY" | "YEARLY"
    interval: int = 1
    days_of_week: list[int] | None = None


class ReminderConfigSchema(BaseModel):
    is_custom: bool = False
    custom_offsets: list[int] | None = None  # Minutes before due


class ReminderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    task_id: str
    offset_minutes: int
    trigger_at: datetime
    reminder_type: str
    status: str
    scheduled_notification_id: int | None = None


class SnoozeRequest(BaseModel):
    snooze_until: datetime | None = None
    preset: str | None = None  # "10m" | "30m" | "1h" | "tomorrow"


class TaskCreate(BaseModel):
    title: str
    description: str | None = None
    due_date: datetime | None = None
    priority: str = "medium"
    category: str | None = None
    tags: list[str] | None = None
    estimated_duration_minutes: int | None = None
    recurrence_rule: dict[str, Any] | None = None
    reminders_config: dict[str, Any] | None = None
    subtasks: list[dict[str, Any]] | None = None

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in _VALID_PRIORITIES:
            raise ValueError(f"priority must be one of {sorted(_VALID_PRIORITIES)}")
        return normalized


class TaskUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    due_date: datetime | None = None
    priority: str | None = None
    status: str | None = None
    is_completed: bool | None = None
    category: str | None = None
    tags: list[str] | None = None
    estimated_duration_minutes: int | None = None
    recurrence_rule: dict[str, Any] | None = None
    reminders_config: dict[str, Any] | None = None
    subtasks: list[dict[str, Any]] | None = None

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, value: str | None) -> str | None:
        if value is not None:
            normalized = value.strip().lower()
            if normalized not in _VALID_PRIORITIES:
                raise ValueError(f"priority must be one of {sorted(_VALID_PRIORITIES)}")
            return normalized
        return value

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str | None) -> str | None:
        if value is not None:
            normalized = value.strip().upper()
            if normalized not in _VALID_STATUSES:
                raise ValueError(f"status must be one of {sorted(_VALID_STATUSES)}")
            return normalized
        return value


class TaskOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    owner_id: str
    title: str
    description: str | None = None
    due_date: datetime | None = None
    priority: str
    status: str = "TODO"
    is_completed: bool = False
    category: str | None = None
    tags: list[str] | None = None
    estimated_duration_minutes: int | None = None
    recurrence_rule: dict[str, Any] | None = None
    reminders_config: dict[str, Any] | None = None
    subtasks: list[dict[str, Any]] | None = None
    reminders: list[ReminderOut] = []
    is_overdue: bool = False
    completed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime | None = None


class TodoSummaryOut(BaseModel):
    total_today: int
    completed_today: int
    remaining_today: int
    overdue_count: int
    urgent_count: int
    high_count: int
