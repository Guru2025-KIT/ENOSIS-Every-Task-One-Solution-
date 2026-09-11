from datetime import datetime, timedelta, timezone
from fastapi.testclient import TestClient
import pytest

from app.main import app
from app.models.todo import Task, TaskPriority, TaskStatus
from app.services.reminder_engine import (
    calculate_default_reminder_offsets,
    generate_reminder_plan,
    advance_recurring_task,
)

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_priority_offsets_authoritative():
    """Verify exact priority-based reminder offsets."""
    assert calculate_default_reminder_offsets("urgent") == [1440, 180, 30]
    assert calculate_default_reminder_offsets("URGENT") == [1440, 180, 30]
    assert calculate_default_reminder_offsets("high") == [1440, 120]
    assert calculate_default_reminder_offsets("HIGH") == [1440, 120]
    assert calculate_default_reminder_offsets("medium") == [360]
    assert calculate_default_reminder_offsets("low") == [60]


def test_past_reminder_offsets_skipped():
    """If created close to deadline, only future reminders should be scheduled."""
    now = datetime(2026, 9, 10, 12, 0, 0)
    # Due in 2 hours (120 min) -> 24h (1440m) is past, 3h (180m) is past, but 30m is FUTURE
    due = now + timedelta(hours=2)
    plan = generate_reminder_plan("t1", "urgent", due, now=now)
    assert len(plan) == 1
    assert plan[0]["offset_minutes"] == 30
    assert plan[0]["trigger_at"] == due - timedelta(minutes=30)


def test_create_urgent_task_and_check_reminders(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    due = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    resp = client.post(
        "/todo/tasks",
        json={
            "title": "Urgent Accreditation Report",
            "priority": "URGENT",
            "due_date": due,
            "category": "Accreditation",
            "tags": ["urgent", "nba"],
        },
        headers=headers,
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["priority"] == "urgent"
    assert body["status"] == "TODO"
    assert len(body["reminders"]) == 3  # 1440, 180, 30 all future
    offsets = [r["offset_minutes"] for r in body["reminders"]]
    assert 1440 in offsets
    assert 180 in offsets
    assert 30 in offsets


def test_update_due_date_reschedules_reminders(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    # Initially due in 2 days (Urgent: 3 reminders)
    due1 = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    task = client.post(
        "/todo/tasks",
        json={"title": "Dynamic Date Task", "priority": "high", "due_date": due1},
        headers=headers,
    ).json()
    assert len(task["reminders"]) == 2  # 24h, 2h

    # Move due date to 1 hour from now -> 24h & 2h are past -> 0 pre-due reminders
    due2 = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    updated = client.patch(
        f"/todo/tasks/{task['id']}",
        json={"due_date": due2},
        headers=headers,
    ).json()
    assert len(updated["reminders"]) == 0


def test_snooze_task(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    task = client.post(
        "/todo/tasks",
        json={"title": "Snoozeable Task", "priority": "medium"},
        headers=headers,
    ).json()

    snooze_resp = client.post(
        f"/todo/tasks/{task['id']}/snooze",
        json={"preset": "30m"},
        headers=headers,
    )
    assert snooze_resp.status_code == 200
    snoozed = snooze_resp.json()
    assert snoozed["status"] == "SNOOZED"
    assert any(r["reminder_type"] == "SNOOZE" for r in snoozed["reminders"])


def test_subtasks_lifecycle(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    task = client.post(
        "/todo/tasks",
        json={"title": "Project Documentation", "priority": "high"},
        headers=headers,
    ).json()

    # Add subtask
    sub1_resp = client.post(
        f"/todo/tasks/{task['id']}/subtasks",
        json={"title": "Finalize architecture"},
        headers=headers,
    )
    assert sub1_resp.status_code == 200
    task_with_sub = sub1_resp.json()
    assert len(task_with_sub["subtasks"]) == 1
    sub_id = task_with_sub["subtasks"][0]["id"]
    assert task_with_sub["subtasks"][0]["is_completed"] is False

    # Toggle subtask
    toggle_resp = client.patch(
        f"/todo/tasks/{task['id']}/subtasks/{sub_id}",
        json={"is_completed": True},
        headers=headers,
    )
    assert toggle_resp.status_code == 200
    assert toggle_resp.json()["subtasks"][0]["is_completed"] is True

    # Delete subtask
    del_resp = client.delete(
        f"/todo/tasks/{task['id']}/subtasks/{sub_id}",
        headers=headers,
    )
    assert del_resp.status_code == 200
    assert len(del_resp.json()["subtasks"]) == 0


def test_recurring_task_advancement(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    due = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    task = client.post(
        "/todo/tasks",
        json={
            "title": "Weekly Lab Status",
            "priority": "medium",
            "due_date": due,
            "recurrence_rule": {"frequency": "WEEKLY", "interval": 1},
        },
        headers=headers,
    ).json()

    # Mark complete -> should advance due date by 7 days and reset completion!
    completed_resp = client.patch(
        f"/todo/tasks/{task['id']}",
        json={"is_completed": True},
        headers=headers,
    )
    assert completed_resp.status_code == 200
    adv_task = completed_resp.json()
    assert adv_task["is_completed"] is False
    assert adv_task["status"] == "TODO"
    # Due date should have advanced approximately 7 days from original
    old_dt = datetime.fromisoformat(due.replace("Z", "+00:00"))
    new_dt = datetime.fromisoformat(adv_task["due_date"].replace("Z", "+00:00"))
    diff_days = (new_dt.date() - old_dt.date()).days
    assert diff_days == 7


def test_smart_views_and_sorting(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    now = datetime.now(timezone.utc)
    # 1. Overdue task
    client.post(
        "/todo/tasks",
        json={"title": "Overdue Task", "priority": "low", "due_date": (now - timedelta(days=1)).isoformat()},
        headers=headers,
    )
    # 2. Urgent task due tomorrow
    client.post(
        "/todo/tasks",
        json={"title": "Urgent Future Task", "priority": "urgent", "due_date": (now + timedelta(days=1)).isoformat()},
        headers=headers,
    )
    # 3. High task due today
    client.post(
        "/todo/tasks",
        json={"title": "High Today Task", "priority": "high", "due_date": (now + timedelta(hours=3)).isoformat()},
        headers=headers,
    )

    # Query 'today' view
    today_resp = client.get("/todo/tasks?view=today", headers=headers)
    assert today_resp.status_code == 200
    assert any("High Today Task" in t["title"] for t in today_resp.json())

    # Query 'overdue' view
    overdue_resp = client.get("/todo/tasks?view=overdue", headers=headers)
    assert overdue_resp.status_code == 200
    assert any("Overdue Task" in t["title"] for t in overdue_resp.json())

    # Check Priority Queue ordering: Overdue should be top!
    all_resp = client.get("/todo/tasks", headers=headers)
    all_tasks = all_resp.json()
    assert len(all_tasks) >= 3
    assert all_tasks[0]["is_overdue"] is True
    assert all_tasks[0]["title"] == "Overdue Task"


def test_todo_summary_metrics(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    resp = client.get("/todo/summary", headers=headers)
    assert resp.status_code == 200
    summary = resp.json()
    assert "total_today" in summary
    assert "completed_today" in summary
    assert "remaining_today" in summary
    assert "overdue_count" in summary
    assert "urgent_count" in summary
    assert "high_count" in summary


def test_evaluate_reminders_dispatches_in_app(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    eval_resp = client.post("/todo/reminders/evaluate", headers=headers)
    assert eval_resp.status_code == 200
    assert eval_resp.json()["status"] == "ok"
