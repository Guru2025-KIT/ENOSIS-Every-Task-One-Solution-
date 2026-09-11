import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.todo import (
    Task,
    TaskPriority,
    TaskStatus,
)
from app.models.user import User
from app.schemas.todo import (
    TaskCreate,
    TaskUpdate,
    TaskOut,
    SubtaskCreate,
    SubtaskUpdate,
    SnoozeRequest,
    TodoSummaryOut,
)
from app.services.reminder_engine import (
    sync_task_reminders,
    cancel_task_reminders,
    snooze_task,
    advance_recurring_task,
    is_task_overdue,
    evaluate_and_dispatch_reminders,
    _ensure_naive_utc,
)

router = APIRouter(prefix="/todo", tags=["todo"])


def _get_owned_task(task_id: str, db: Session, current_user: User) -> Task:
    """
    Fetches a task ONLY if it belongs to current user.
    Returns 404 (not 403) to prevent ID probing leakage.
    """
    task = db.query(Task).filter(Task.id == task_id, Task.owner_id == current_user.id).first()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


def _to_task_out(task: Task, now: datetime | None = None) -> TaskOut:
    """Builds TaskOut DTO with computed is_overdue property."""
    current_time = now or datetime.now(timezone.utc).replace(tzinfo=None)
    overdue = is_task_overdue(task, current_time)
    
    # Format subtasks safely
    subtasks = task.subtasks or []

    # Map reminders
    reminders = [r for r in (task.reminders or []) if r.status != "CANCELLED"]

    return TaskOut(
        id=task.id,
        owner_id=task.owner_id,
        title=task.title,
        description=task.description,
        due_date=task.due_date,
        priority=task.priority,
        status=task.status,
        is_completed=task.is_completed,
        category=task.category,
        tags=task.tags,
        estimated_duration_minutes=task.estimated_duration_minutes,
        recurrence_rule=task.recurrence_rule,
        reminders_config=task.reminders_config,
        subtasks=subtasks,
        reminders=reminders,
        is_overdue=overdue,
        completed_at=task.completed_at,
        created_at=task.created_at,
        updated_at=task.updated_at,
    )


@router.post("/tasks", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(
    payload: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Creates a new task and calculates its deterministic reminder schedule."""
    data = payload.model_dump()
    if data.get("due_date"):
        data["due_date"] = _ensure_naive_utc(data["due_date"])

    priority = TaskPriority.normalize(data.get("priority"))
    data["priority"] = priority
    data["status"] = TaskStatus.TODO.value
    data["is_completed"] = False

    task = Task(owner_id=current_user.id, **data)
    db.add(task)
    db.flush()

    # Calculate and store initial reminder plan
    sync_task_reminders(db, task)

    db.commit()
    db.refresh(task)
    return _to_task_out(task)


@router.get("/tasks", response_model=list[TaskOut])
def list_tasks(
    view: str | None = Query(None, description="Smart view: all|today|upcoming|overdue|urgent|high|completed|recurring"),
    task_status: str | None = Query(None, alias="status"),
    priority: str | None = Query(None),
    category: str | None = Query(None),
    search: str | None = Query(None),
    include_completed: bool = Query(True),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Lists tasks for current user with smart view filtering and Priority Queue ordering:
    Overdue Incomplete -> Urgent -> High -> Medium -> Low -> Completed.
    """
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    query = db.query(Task).filter(Task.owner_id == current_user.id)

    if not include_completed:
        query = query.filter(Task.is_completed.is_(False))

    if task_status:
        query = query.filter(Task.status == TaskStatus.normalize(task_status))

    if priority:
        query = query.filter(Task.priority == TaskPriority.normalize(priority))

    if category:
        query = query.filter(Task.category.ilike(f"%{category}%"))

    tasks = query.all()

    # View filtering
    if view:
        v = view.lower().strip()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        today_end = today_start + timedelta(days=1)

        if v == "today":
            tasks = [t for t in tasks if t.due_date and today_start <= _ensure_naive_utc(t.due_date) < today_end]
        elif v == "upcoming":
            tasks = [t for t in tasks if t.due_date and _ensure_naive_utc(t.due_date) >= today_end and not t.is_completed]
        elif v == "overdue":
            tasks = [t for t in tasks if is_task_overdue(t, now)]
        elif v == "urgent":
            tasks = [t for t in tasks if t.priority == TaskPriority.URGENT.value]
        elif v == "high":
            tasks = [t for t in tasks if t.priority in (TaskPriority.URGENT.value, TaskPriority.HIGH.value)]
        elif v == "completed":
            tasks = [t for t in tasks if t.is_completed or t.status == TaskStatus.COMPLETED.value]
        elif v == "recurring":
            tasks = [t for t in tasks if t.recurrence_rule is not None]

    # Search filter
    if search:
        s = search.lower().strip()
        filtered = []
        for t in tasks:
            title_match = s in (t.title or "").lower()
            desc_match = s in (t.description or "").lower()
            cat_match = s in (t.category or "").lower()
            tag_match = any(s in str(tag).lower() for tag in (t.tags or []))
            if title_match or desc_match or cat_match or tag_match:
                filtered.append(t)
        tasks = filtered

    # Priority Rank:
    # 0 = Overdue Incomplete
    # 1 = Urgent
    # 2 = High
    # 3 = Medium
    # 4 = Low
    # 5 = Completed
    def _sort_key(t: Task):
        is_comp = t.is_completed or t.status == TaskStatus.COMPLETED.value
        overdue = is_task_overdue(t, now)

        if is_comp:
            rank = 5
        elif overdue:
            rank = 0
        elif t.priority == TaskPriority.URGENT.value:
            rank = 1
        elif t.priority == TaskPriority.HIGH.value:
            rank = 2
        elif t.priority == TaskPriority.MEDIUM.value:
            rank = 3
        else:
            rank = 4

        due = _ensure_naive_utc(t.due_date)
        # Null due dates come after tasks with due dates in the same rank
        has_no_due = due is None
        due_sort = due or t.created_at

        return (rank, has_no_due, due_sort)

    tasks.sort(key=_sort_key)
    return [_to_task_out(t, now) for t in tasks]


@router.get("/summary", response_model=TodoSummaryOut)
def get_todo_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns today's productivity overview metrics."""
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)

    tasks = db.query(Task).filter(Task.owner_id == current_user.id).all()

    total_today = 0
    completed_today = 0
    remaining_today = 0
    overdue_count = 0
    urgent_count = 0
    high_count = 0

    for t in tasks:
        is_comp = t.is_completed or t.status == TaskStatus.COMPLETED.value
        due = _ensure_naive_utc(t.due_date)

        # Check if today's task
        if due and today_start <= due < today_end:
            total_today += 1
            if is_comp:
                completed_today += 1
            else:
                remaining_today += 1

        if not is_comp:
            if is_task_overdue(t, now):
                overdue_count += 1
            if t.priority == TaskPriority.URGENT.value:
                urgent_count += 1
            elif t.priority == TaskPriority.HIGH.value:
                high_count += 1

    return TodoSummaryOut(
        total_today=total_today,
        completed_today=completed_today,
        remaining_today=remaining_today,
        overdue_count=overdue_count,
        urgent_count=urgent_count,
        high_count=high_count,
    )


@router.get("/tasks/{task_id}", response_model=TaskOut)
def get_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = _get_owned_task(task_id, db, current_user)
    return _to_task_out(task)


@router.patch("/tasks/{task_id}", response_model=TaskOut)
def update_task(
    task_id: str,
    payload: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = _get_owned_task(task_id, db, current_user)
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    updates = payload.model_dump(exclude_unset=True)

    due_date_changed = "due_date" in updates
    priority_changed = "priority" in updates
    status_changed = "status" in updates
    completed_changed = "is_completed" in updates

    if due_date_changed and updates["due_date"]:
        updates["due_date"] = _ensure_naive_utc(updates["due_date"])

    if priority_changed and updates["priority"]:
        updates["priority"] = TaskPriority.normalize(updates["priority"])

    # Handle completion status transitions
    becoming_completed = False
    if completed_changed:
        is_comp = bool(updates["is_completed"])
        updates["is_completed"] = is_comp
        if is_comp:
            updates["status"] = TaskStatus.COMPLETED.value
            updates["completed_at"] = now
            becoming_completed = True
        else:
            updates["status"] = TaskStatus.TODO.value
            updates["completed_at"] = None

    if status_changed and not completed_changed:
        st = TaskStatus.normalize(updates["status"])
        updates["status"] = st
        if st == TaskStatus.COMPLETED.value:
            updates["is_completed"] = True
            updates["completed_at"] = now
            becoming_completed = True
        else:
            updates["is_completed"] = False
            updates["completed_at"] = None

    for field, value in updates.items():
        setattr(task, field, value)

    task.updated_at = now

    # If completed and recurring, advance occurrence!
    if becoming_completed:
        advanced = advance_recurring_task(task, completed_at=now)
        if advanced:
            # Re-generate reminders for the advanced next occurrence
            sync_task_reminders(db, task, now=now)
        else:
            cancel_task_reminders(db, task)
    elif due_date_changed or priority_changed or "reminders_config" in updates:
        sync_task_reminders(db, task, now=now)

    db.commit()
    db.refresh(task)
    return _to_task_out(task, now)


@router.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = _get_owned_task(task_id, db, current_user)
    db.delete(task)
    db.commit()
    return None


@router.post("/tasks/{task_id}/snooze", response_model=TaskOut)
def snooze_task_endpoint(
    task_id: str,
    payload: SnoozeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Snoozes a task for a specified duration or preset time."""
    task = _get_owned_task(task_id, db, current_user)
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    target_time = None
    if payload.snooze_until:
        target_time = _ensure_naive_utc(payload.snooze_until)
    elif payload.preset:
        p = payload.preset.lower().strip()
        if p == "10m":
            target_time = now + timedelta(minutes=10)
        elif p == "30m":
            target_time = now + timedelta(minutes=30)
        elif p == "1h":
            target_time = now + timedelta(hours=1)
        elif p == "tomorrow":
            tomorrow = (now + timedelta(days=1)).replace(hour=9, minute=0, second=0, microsecond=0)
            target_time = tomorrow
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported snooze preset: {payload.preset}")
    else:
        raise HTTPException(status_code=400, detail="Must provide either snooze_until or preset")

    if target_time <= now:
        raise HTTPException(status_code=400, detail="Snooze time must be in the future")

    snooze_task(db, task, target_time, now=now)
    db.commit()
    db.refresh(task)
    return _to_task_out(task, now)


@router.post("/tasks/{task_id}/subtasks", response_model=TaskOut)
def add_subtask(
    task_id: str,
    payload: SubtaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Adds a checklist subtask to a task."""
    task = _get_owned_task(task_id, db, current_user)
    subtasks = list(task.subtasks or [])
    new_item = {
        "id": str(uuid.uuid4()),
        "title": payload.title.strip(),
        "is_completed": False,
    }
    subtasks.append(new_item)
    task.subtasks = subtasks
    flag_modified(task, "subtasks")
    task.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(task)
    return _to_task_out(task)


@router.patch("/tasks/{task_id}/subtasks/{subtask_id}", response_model=TaskOut)
def update_subtask(
    task_id: str,
    subtask_id: str,
    payload: SubtaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Updates or toggles completion of a checklist subtask."""
    task = _get_owned_task(task_id, db, current_user)
    subtasks = list(task.subtasks or [])
    found = False

    for item in subtasks:
        if item.get("id") == subtask_id:
            found = True
            if payload.title is not None:
                item["title"] = payload.title.strip()
            if payload.is_completed is not None:
                item["is_completed"] = bool(payload.is_completed)
            break

    if not found:
        raise HTTPException(status_code=404, detail="Subtask not found")

    task.subtasks = subtasks
    flag_modified(task, "subtasks")
    task.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(task)
    return _to_task_out(task)


@router.delete("/tasks/{task_id}/subtasks/{subtask_id}", response_model=TaskOut)
def delete_subtask(
    task_id: str,
    subtask_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Deletes a checklist subtask."""
    task = _get_owned_task(task_id, db, current_user)
    subtasks = [item for item in (task.subtasks or []) if item.get("id") != subtask_id]
    task.subtasks = subtasks
    flag_modified(task, "subtasks")
    task.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(task)
    return _to_task_out(task)


@router.post("/reminders/evaluate")
def evaluate_reminders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Evaluates due reminders and overdue tasks for current user and emits in-app notifications."""
    result = evaluate_and_dispatch_reminders(db, current_user.id)
    return {"status": "ok", **result}
