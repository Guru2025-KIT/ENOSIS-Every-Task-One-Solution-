from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_admin
from app.db.base import get_db
from app.models.notification import Notification
from app.models.user import User
from app.schemas.notification import NotificationCreate, NotificationOut

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.post("", response_model=NotificationOut, status_code=status.HTTP_201_CREATED)
def create_notification(payload: NotificationCreate, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """Admin-only manual send — e.g. an announcement. Most notifications
    in practice come from other modules automatically (see
    services/notifications.py's notify(), used by Timetable generation)."""
    recipient = db.query(User).filter(User.id == payload.recipient_id).first()
    if recipient is None:
        raise HTTPException(status_code=404, detail="Recipient not found")

    notification = Notification(
        recipient_id=payload.recipient_id,
        title=payload.title,
        message=payload.message,
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


class CourseSlotNotifyIn(NotificationCreate):
    timetable_entry_id: str | None = None
    subject_name: str | None = None
    time_range: str | None = None
    room_name: str | None = None
    division_name: str | None = None
    faculty_id: str | None = None


@router.post("/notify-course-slot")
def notify_course_slot(
    payload: dict,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Dispatches a lecture schedule notification to the assigned faculty member.
    Creates an official persistent in-app notification.
    """
    from app.models.timetable import TimetableEntry

    subject_name = payload.get("subject_name") or "Course Lecture"
    time_range = payload.get("time_range") or "Scheduled Time"
    room_name = payload.get("room_name") or "Assigned Room"
    division_name = payload.get("division_name") or "Class"
    entry_id = payload.get("timetable_entry_id")

    recipient_id = payload.get("faculty_id")
    if not recipient_id and entry_id:
        entry = db.query(TimetableEntry).filter(TimetableEntry.id == entry_id).first()
        if entry:
            recipient_id = entry.faculty_id

    if not recipient_id:
        recipient_id = current_user.id

    title = f"Lecture Reminder: {subject_name}"
    message = (
        payload.get("custom_message")
        or f"Reminder: Your {subject_name} lecture for {division_name} is scheduled at {time_range} in {room_name}."
    )

    notif = Notification(
        recipient_id=recipient_id,
        title=title,
        message=message,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return {
        "success": True,
        "message": f"Faculty notified for {subject_name}",
        "notification_id": notif.id,
        "recipient_id": recipient_id,
        "title": title,
    }


@router.get("/mine", response_model=list[NotificationOut])
def list_my_notifications(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return (
        db.query(Notification)
        .filter(Notification.recipient_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .all()
    )


@router.get("/unread-count")
def unread_count(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    count = (
        db.query(Notification)
        .filter(Notification.recipient_id == current_user.id, Notification.is_read.is_(False))
        .count()
    )
    return {"unread_count": count}


@router.patch("/{notification_id}/read", response_model=NotificationOut)
def mark_read(notification_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    notification = (
        db.query(Notification)
        .filter(Notification.id == notification_id, Notification.recipient_id == current_user.id)
        .first()
    )
    if notification is None:
        raise HTTPException(status_code=404, detail="Notification not found")

    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return notification


@router.patch("/read-all")
def mark_all_read(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    (
        db.query(Notification)
        .filter(Notification.recipient_id == current_user.id, Notification.is_read.is_(False))
        .update({"is_read": True})
    )
    db.commit()
    return {"status": "ok"}
