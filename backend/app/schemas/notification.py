from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationCreate(BaseModel):
    """Admin-only — see POST /notifications. recipient_id is required
    (no broadcast-to-everyone yet, see Notification's docstring)."""
    recipient_id: str
    title: str
    message: str


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    message: str
    is_read: bool
    created_at: datetime
