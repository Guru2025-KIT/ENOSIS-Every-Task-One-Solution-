"""
Tests for the To-Do module: basic CRUD, and — the important one — that
one faculty member can never see or modify another's tasks.

Run with: pytest tests/test_todo.py -v
"""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_create_and_list_task(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    create = client.post("/todo/tasks", json={"title": "Submit internal marks", "priority": "high"}, headers=headers)
    assert create.status_code == 201
    body = create.json()
    assert body["title"] == "Submit internal marks"
    assert body["priority"] == "high"
    assert body["is_completed"] is False

    listed = client.get("/todo/tasks", headers=headers)
    assert listed.status_code == 200
    assert any(t["title"] == "Submit internal marks" for t in listed.json())


def test_invalid_priority_is_rejected(faculty_user):
    _, token = faculty_user
    response = client.post(
        "/todo/tasks", json={"title": "Bad priority test", "priority": "urgent!!"}, headers=_auth_headers(token)
    )
    assert response.status_code == 422


def test_mark_task_complete(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    task = client.post("/todo/tasks", json={"title": "Complete me"}, headers=headers).json()

    updated = client.patch(f"/todo/tasks/{task['id']}", json={"is_completed": True}, headers=headers)
    assert updated.status_code == 200
    assert updated.json()["is_completed"] is True

    # title should be unchanged — PATCH only touches what was sent
    assert updated.json()["title"] == "Complete me"


def test_delete_task(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    task = client.post("/todo/tasks", json={"title": "Delete me"}, headers=headers).json()
    delete_response = client.delete(f"/todo/tasks/{task['id']}", headers=headers)
    assert delete_response.status_code == 204

    listed = client.get("/todo/tasks", headers=headers).json()
    assert not any(t["id"] == task["id"] for t in listed)


def test_user_cannot_see_another_users_tasks(faculty_user, admin_token):
    """The critical ownership-isolation test — a task created by one user
    must be completely invisible to another, not just 'read-only'."""
    _, faculty_token = faculty_user
    faculty_headers = _auth_headers(faculty_token)
    admin_headers = _auth_headers(admin_token)

    task = client.post("/todo/tasks", json={"title": "Faculty-only task"}, headers=faculty_headers).json()

    # The admin's own task list must not contain the faculty member's task
    admin_tasks = client.get("/todo/tasks", headers=admin_headers).json()
    assert not any(t["id"] == task["id"] for t in admin_tasks)

    # The admin can't update or delete it either — 404, not 403, so we
    # don't even confirm the task id exists to an unauthorized caller
    update_attempt = client.patch(f"/todo/tasks/{task['id']}", json={"title": "hijacked"}, headers=admin_headers)
    assert update_attempt.status_code == 404

    delete_attempt = client.delete(f"/todo/tasks/{task['id']}", headers=admin_headers)
    assert delete_attempt.status_code == 404


def test_unauthenticated_requests_rejected():
    assert client.get("/todo/tasks").status_code == 401
    assert client.post("/todo/tasks", json={"title": "x"}).status_code == 401
