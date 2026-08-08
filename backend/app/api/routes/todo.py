from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.todo import Task
from app.models.user import User
from app.schemas.todo import TaskCreate, TaskUpdate, TaskOut

router = APIRouter(prefix="/todo", tags=["todo"])


def _get_owned_task(task_id: str, db: Session, current_user: User) -> Task:
    """
    Fetches a task ONLY if it belongs to the current user. Deliberately
    returns 404 (not 403) for a task that exists but belongs to someone
    else — this avoids confirming to a caller that a given task_id exists
    at all, which is the standard approach for personal-data endpoints.
    """
    task = db.query(Task).filter(Task.id == task_id, Task.owner_id == current_user.id).first()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.post("/tasks", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    task = Task(owner_id=current_user.id, **payload.model_dump())
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.get("/tasks", response_model=list[TaskOut])
def list_tasks(
    include_completed: bool = True,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Task).filter(Task.owner_id == current_user.id)
    if not include_completed:
        query = query.filter(Task.is_completed.is_(False))
    # Incomplete tasks first, then by due date (nulls last), matching how
    # a to-do list is actually useful to scan at a glance.
    tasks = query.all()
    tasks.sort(key=lambda t: (t.is_completed, t.due_date is None, t.due_date or t.created_at))
    return tasks


@router.patch("/tasks/{task_id}", response_model=TaskOut)
def update_task(
    task_id: str,
    payload: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    task = _get_owned_task(task_id, db, current_user)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, field, value)
    db.commit()
    db.refresh(task)
    return task


@router.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(task_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    task = _get_owned_task(task_id, db, current_user)
    db.delete(task)
    db.commit()
    return None
