import calendar
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.models.todo import (
    Task,
    TaskReminder,
    TaskPriority,
    TaskStatus,
    ReminderStatus,
    ReminderType,
)
from app.services.notifications import notify


def _ensure_naive_utc(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def calculate_default_reminder_offsets(priority: str) -> list[int]:
    """
    Authoritative reminder policy offsets (in minutes before deadline):
    - URGENT: 24 hours (1440m), 3 hours (180m), 30 minutes (30m)
    - HIGH:   24 hours (1440m), 2 hours (120m)
    - MEDIUM: 6 hours (360m)
    - LOW:    1 hour (60m)
    """
    normalized = TaskPriority.normalize(priority)
    if normalized == TaskPriority.URGENT.value:
        return [1440, 180, 30]
    elif normalized == TaskPriority.HIGH.value:
        return [1440, 120]
    elif normalized == TaskPriority.MEDIUM.value:
        return [360]
    elif normalized == TaskPriority.LOW.value:
        return [60]
    return [360]


def generate_reminder_plan(
    task_id: str,
    priority: str,
    due_date: datetime | None,
    custom_config: dict[str, Any] | None = None,
    now: datetime | None = None,
    occurrence_key: str = "base",
) -> list[dict[str, Any]]:
    """
    Calculates deterministic future reminder triggers for a task.
    Skips past reminder offsets — only retains trigger_at > now.
    """
    if due_date is None:
        return []

    target_due = _ensure_naive_utc(due_date)
    current_time = _ensure_naive_utc(now) or datetime.now(timezone.utc).replace(tzinfo=None)

    # Determine offsets
    if custom_config and custom_config.get("is_custom") and custom_config.get("custom_offsets"):
        raw_offsets = [int(o) for o in custom_config.get("custom_offsets", []) if int(o) > 0]
        offsets = sorted(raw_offsets, reverse=True)
    else:
        offsets = calculate_default_reminder_offsets(priority)

    plan = []
    for offset in offsets:
        trigger_at = target_due - timedelta(minutes=offset)
        # Skip past timestamps
        if trigger_at <= current_time:
            continue

        fingerprint = f"{task_id}:{occurrence_key}:{offset}:{ReminderType.PRE_DUE.value}"
        stable_id = abs(hash(fingerprint)) % 2147483647

        plan.append({
            "task_id": task_id,
            "occurrence_key": occurrence_key,
            "offset_minutes": offset,
            "trigger_at": trigger_at,
            "reminder_type": ReminderType.PRE_DUE.value,
            "status": ReminderStatus.SCHEDULED.value,
            "scheduled_notification_id": stable_id,
            "fingerprint": fingerprint,
        })

    return plan


def sync_task_reminders(
    db: Session,
    task: Task,
    now: datetime | None = None,
) -> list[TaskReminder]:
    """
    Synchronizes reminders for a task when created or updated:
    - If COMPLETED or no due_date: cancels all future scheduled reminders
    - Cancels obsolete scheduled reminders
    - Schedules new valid future reminders without duplicate fingerprints
    """
    current_time = _ensure_naive_utc(now) or datetime.now(timezone.utc).replace(tzinfo=None)

    if task.status == TaskStatus.COMPLETED.value or task.due_date is None:
        for r in task.reminders:
            if r.status == ReminderStatus.SCHEDULED.value:
                r.status = ReminderStatus.CANCELLED.value
                r.updated_at = current_time
        return [r for r in task.reminders if r.status == ReminderStatus.SCHEDULED.value]

    # Calculate new reminder plan
    plan = generate_reminder_plan(
        task_id=task.id,
        priority=task.priority,
        due_date=task.due_date,
        custom_config=task.reminders_config,
        now=current_time,
    )

    new_fingerprints = {item["fingerprint"]: item for item in plan}

    # Deactivate obsolete scheduled reminders
    for existing in task.reminders:
        if existing.status == ReminderStatus.SCHEDULED.value:
            if existing.fingerprint not in new_fingerprints:
                existing.status = ReminderStatus.CANCELLED.value
                existing.updated_at = current_time

    # Add or re-enable planned reminders
    existing_by_fp = {r.fingerprint: r for r in task.reminders}
    for fp, item in new_fingerprints.items():
        if fp in existing_by_fp:
            existing = existing_by_fp[fp]
            if existing.status == ReminderStatus.CANCELLED.value:
                existing.status = ReminderStatus.SCHEDULED.value
                existing.trigger_at = item["trigger_at"]
                existing.updated_at = current_time
        else:
            reminder = TaskReminder(
                task_id=task.id,
                occurrence_key=item["occurrence_key"],
                offset_minutes=item["offset_minutes"],
                trigger_at=item["trigger_at"],
                reminder_type=item["reminder_type"],
                status=item["status"],
                scheduled_notification_id=item["scheduled_notification_id"],
                fingerprint=item["fingerprint"],
            )
            db.add(reminder)

    return [r for r in task.reminders if r.status == ReminderStatus.SCHEDULED.value]


def cancel_task_reminders(db: Session, task: Task) -> None:
    """Cancels all active scheduled reminders for a task."""
    current_time = datetime.now(timezone.utc).replace(tzinfo=None)
    for r in task.reminders:
        if r.status == ReminderStatus.SCHEDULED.value:
            r.status = ReminderStatus.CANCELLED.value
            r.updated_at = current_time


def snooze_task(
    db: Session,
    task: Task,
    snooze_until: datetime,
    now: datetime | None = None,
) -> TaskReminder:
    """
    Snoozes a task until the specified datetime.
    Cancels current scheduled reminders and creates a SNOOZE reminder.
    """
    current_time = _ensure_naive_utc(now) or datetime.now(timezone.utc).replace(tzinfo=None)
    target_snooze = _ensure_naive_utc(snooze_until)

    # Cancel any current scheduled reminders
    for r in task.reminders:
        if r.status == ReminderStatus.SCHEDULED.value:
            r.status = ReminderStatus.CANCELLED.value
            r.updated_at = current_time

    task.status = TaskStatus.SNOOZED.value
    task.updated_at = current_time

    fp = f"{task.id}:snooze:{int(target_snooze.timestamp())}"
    stable_id = abs(hash(fp)) % 2147483647

    snooze_reminder = TaskReminder(
        task_id=task.id,
        occurrence_key="snooze",
        offset_minutes=0,
        trigger_at=target_snooze,
        reminder_type=ReminderType.SNOOZE.value,
        status=ReminderStatus.SCHEDULED.value,
        scheduled_notification_id=stable_id,
        fingerprint=fp,
    )
    db.add(snooze_reminder)
    return snooze_reminder


def advance_recurring_task(task: Task, completed_at: datetime | None = None) -> bool:
    """
    If a task has a recurrence_rule, advances its due_date to the next occurrence,
    resets status to TODO, is_completed to False, and clears completed_at.
    Returns True if advanced, False if not recurring.
    """
    if not task.recurrence_rule or not task.due_date:
        return False

    rule = task.recurrence_rule
    freq = str(rule.get("frequency", "")).upper()
    interval = max(1, int(rule.get("interval", 1)))

    curr_due = _ensure_naive_utc(task.due_date)
    next_due = None

    if freq == "DAILY":
        next_due = curr_due + timedelta(days=interval)
    elif freq == "WEEKDAYS":
        next_due = curr_due + timedelta(days=1)
        while next_due.weekday() >= 5:  # Saturday or Sunday
            next_due += timedelta(days=1)
    elif freq == "WEEKLY":
        next_due = curr_due + timedelta(weeks=interval)
    elif freq == "MONTHLY":
        month = curr_due.month - 1 + interval
        year = curr_due.year + month // 12
        month = month % 12 + 1
        day = min(curr_due.day, calendar.monthrange(year, month)[1])
        next_due = curr_due.replace(year=year, month=month, day=day)
    elif freq == "YEARLY":
        try:
            next_due = curr_due.replace(year=curr_due.year + interval)
        except ValueError:
            next_due = curr_due.replace(year=curr_due.year + interval, day=28)

    if next_due:
        task.due_date = next_due
        task.status = TaskStatus.TODO.value
        task.is_completed = False
        task.completed_at = None
        task.updated_at = _ensure_naive_utc(completed_at) or datetime.now(timezone.utc).replace(tzinfo=None)
        return True

    return False


def is_task_overdue(task: Task, now: datetime | None = None) -> bool:
    """Returns True if the task is past its due datetime and not completed."""
    if task.status == TaskStatus.COMPLETED.value or not task.due_date:
        return False
    current_time = _ensure_naive_utc(now) or datetime.now(timezone.utc).replace(tzinfo=None)
    due = _ensure_naive_utc(task.due_date)
    return due < current_time


def evaluate_and_dispatch_reminders(
    db: Session,
    user_id: str,
    now: datetime | None = None,
) -> dict[str, int]:
    """
    Evaluates due scheduled reminders for the user and emits in-app notifications.
    Also evaluates overdue tasks and handles controlled escalation.
    """
    current_time = _ensure_naive_utc(now) or datetime.now(timezone.utc).replace(tzinfo=None)
    delivered_count = 0
    overdue_count = 0

    # 1. Evaluate triggered reminders
    tasks = db.query(Task).filter(Task.owner_id == user_id).all()

    for task in tasks:
        if task.status == TaskStatus.COMPLETED.value:
            continue

        for reminder in task.reminders:
            if (
                reminder.status == ReminderStatus.SCHEDULED.value
                and _ensure_naive_utc(reminder.trigger_at) <= current_time
            ):
                reminder.status = ReminderStatus.DELIVERED.value
                reminder.delivered_at = current_time

                # If it was a snooze reminder, restore task to TODO
                if reminder.reminder_type == ReminderType.SNOOZE.value:
                    task.status = TaskStatus.TODO.value

                # Format concise notification content based on priority
                title = f"{task.priority.upper()}: Task Reminder"
                if reminder.reminder_type == ReminderType.SNOOZE.value:
                    message = f"Snoozed task '{task.title}' is now due for action."
                elif reminder.offset_minutes >= 1440:
                    message = f"'{task.title}' is due tomorrow."
                elif reminder.offset_minutes >= 60:
                    hours = reminder.offset_minutes // 60
                    message = f"'{task.title}' is due in {hours} hour{'s' if hours > 1 else ''}."
                else:
                    message = f"'{task.title}' is due in {reminder.offset_minutes} minutes."

                notify(db, recipient_id=user_id, title=title, message=message)
                delivered_count += 1

        # 2. Overdue detection & controlled escalation
        if is_task_overdue(task, current_time):
            overdue_count += 1
            # Check if overdue alert was already dispatched
            overdue_fp = f"{task.id}:overdue:{task.due_date.strftime('%Y%m%d')}"
            existing_overdue = [r for r in task.reminders if r.fingerprint.startswith(f"{task.id}:overdue")]

            prio = TaskPriority.normalize(task.priority)
            should_notify = False

            if prio == TaskPriority.URGENT.value:
                # Urgent: alert once per day overdue
                if not any(r.fingerprint == overdue_fp for r in existing_overdue):
                    should_notify = True
            elif prio == TaskPriority.HIGH.value:
                # High: alert once upon breach
                if len(existing_overdue) == 0:
                    should_notify = True

            if should_notify:
                record = TaskReminder(
                    task_id=task.id,
                    occurrence_key="overdue",
                    offset_minutes=0,
                    trigger_at=current_time,
                    reminder_type=ReminderType.OVERDUE.value,
                    status=ReminderStatus.DELIVERED.value,
                    delivered_at=current_time,
                    fingerprint=overdue_fp,
                )
                db.add(record)
                notify(
                    db,
                    recipient_id=user_id,
                    title=f"OVERDUE ({task.priority.upper()}): {task.title}",
                    message=f"Task '{task.title}' was due on {task.due_date.strftime('%d %b at %I:%M %p')}.",
                )

    db.commit()
    return {"delivered_reminders": delivered_count, "overdue_tasks": overdue_count}
