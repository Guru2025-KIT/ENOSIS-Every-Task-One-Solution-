"""
Tests for Notifications: admin-only manual creation, owner-scoped
viewing, and — the real integration test — that generating a timetable
actually creates notifications for the affected faculty automatically.

Run with: pytest tests/test_notifications.py -v
"""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_non_admin_cannot_create_notification(faculty_user):
    faculty_id, token = faculty_user
    response = client.post(
        "/notifications",
        json={"recipient_id": faculty_id, "title": "Test", "message": "Test message"},
        headers=_auth_headers(token),
    )
    assert response.status_code == 403


def test_admin_can_notify_a_faculty_member(admin_token, faculty_user):
    faculty_id, faculty_token = faculty_user

    create = client.post(
        "/notifications",
        json={"recipient_id": faculty_id, "title": "Welcome", "message": "Welcome to ENOSIS!"},
        headers=_auth_headers(admin_token),
    )
    assert create.status_code == 201

    mine = client.get("/notifications/mine", headers=_auth_headers(faculty_token))
    assert mine.status_code == 200
    assert any(n["title"] == "Welcome" for n in mine.json())


def test_user_only_sees_own_notifications(admin_token, faculty_user):
    faculty_id, faculty_token = faculty_user
    client.post(
        "/notifications",
        json={"recipient_id": faculty_id, "title": "Private note", "message": "Just for you"},
        headers=_auth_headers(admin_token),
    )

    admin_mine = client.get("/notifications/mine", headers=_auth_headers(admin_token))
    assert not any(n["title"] == "Private note" for n in admin_mine.json())


def test_mark_read_and_unread_count(admin_token, faculty_user):
    faculty_id, faculty_token = faculty_user
    faculty_headers = _auth_headers(faculty_token)

    notif = client.post(
        "/notifications",
        json={"recipient_id": faculty_id, "title": "Unread test", "message": "x"},
        headers=_auth_headers(admin_token),
    ).json()

    before = client.get("/notifications/unread-count", headers=faculty_headers).json()
    assert before["unread_count"] >= 1

    mark = client.patch(f"/notifications/{notif['id']}/read", headers=faculty_headers)
    assert mark.status_code == 200
    assert mark.json()["is_read"] is True


def test_cannot_mark_someone_elses_notification_read(admin_token, faculty_user):
    faculty_id, _ = faculty_user
    notif = client.post(
        "/notifications",
        json={"recipient_id": faculty_id, "title": "Not yours", "message": "x"},
        headers=_auth_headers(admin_token),
    ).json()

    # admin didn't receive it, so admin marking it read should 404
    attempt = client.patch(f"/notifications/{notif['id']}/read", headers=_auth_headers(admin_token))
    assert attempt.status_code == 404


def test_timetable_generation_notifies_affected_faculty(admin_token, faculty_user):
    """The real integration proof: generating a timetable should create a
    notification for the faculty member assigned to teach in it, with no
    manual notification call needed anywhere in the test."""
    faculty_id, faculty_token = faculty_user
    admin_headers = _auth_headers(admin_token)

    division = client.post(
        "/timetable/divisions", json={"name": "TE-Notify-Test", "year": 3, "division_code": "A", "strength": 50},
        headers=admin_headers,
    ).json()
    subject = client.post(
        "/timetable/subjects", json={"name": "Notify Test Subject", "weekly_lectures": 2},
        headers=admin_headers,
    ).json()
    client.post("/timetable/rooms", json={"name": "Notify Room", "type": "lecture", "capacity": 60}, headers=admin_headers)
    client.post(
        "/timetable/assignments",
        json={"faculty_id": faculty_id, "subject_id": subject["id"], "division_id": division["id"]},
        headers=admin_headers,
    )

    generate = client.post("/timetable/generate", headers=admin_headers)
    assert generate.status_code == 200

    mine = client.get("/notifications/mine", headers=_auth_headers(faculty_token))
    assert any("timetable" in n["title"].lower() for n in mine.json())
