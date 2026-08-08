from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator

_VALID_PRIORITIES = {"low", "medium", "high"}


class TaskCreate(BaseModel):
    title: str
    description: str | None = None
    due_date: datetime | None = None
    priority: str = "medium"

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, value: str) -> str:
        if value not in _VALID_PRIORITIES:
            raise ValueError(f"priority must be one of {sorted(_VALID_PRIORITIES)}")
        return value


class TaskUpdate(BaseModel):
    """
    All fields optional — a PATCH only sends what's changing (e.g. just
    `is_completed: true` when checking a task off), not the whole object.
    """
    title: str | None = None
    description: str | None = None
    due_date: datetime | None = None
    priority: str | None = None
    is_completed: bool | None = None

    @field_validator("priority")
    @classmethod
    def validate_priority(cls, value: str | None) -> str | None:
        if value is not None and value not in _VALID_PRIORITIES:
            raise ValueError(f"priority must be one of {sorted(_VALID_PRIORITIES)}")
        return value


class TaskOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    description: str | None
    due_date: datetime | None
    priority: str
    is_completed: bool
    created_at: datetime
