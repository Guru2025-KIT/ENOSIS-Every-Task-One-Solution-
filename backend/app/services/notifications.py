"""
Small helper so other modules (Timetable, eventually To-Do reminders,
etc.) can create a notification for a user without importing the whole
notifications route file. Kept intentionally tiny — this is plumbing,
not a module of its own.
"""
from sqlalchemy.orm import Session

from app.models.notification import Notification


def notify(db: Session, *, recipient_id: str, title: str, message: str) -> None:
    """Creates a notification. Does NOT commit — the caller's own
    transaction (e.g. timetable generation) commits everything together,
    so a notification never gets created for an action that then fails."""
    db.add(Notification(recipient_id=recipient_id, title=title, message=message))
