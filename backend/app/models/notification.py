import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey

from app.db.base import Base


class Notification(Base):
    """
    A notification for one specific recipient — no broadcast/"send to
    everyone" complexity yet (that would need per-recipient read-state
    tracking separate from the notification itself). Created either by an
    admin directly (POST /notifications) or automatically by other
    modules — e.g. Timetable generation notifies every affected faculty
    member (see api/routes/timetable.py's generate() route).
    """
    __tablename__ = "notifications"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    recipient_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    message = Column(String(1000), nullable=False)
    is_read = Column(Boolean, nullable=False, default=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
