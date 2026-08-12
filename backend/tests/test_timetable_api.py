"""
Integration tests for the Timetable module — these go through the real
HTTP layer, real auth/permission checks, and the real database, unlike
test_timetable_solver.py which tests the solver in isolation. Together
they cover: "is the algorithm correct?" (solver test) and
"is it wired up correctly end-to-end?" (this file).

Run with: pytest tests/test_timetable_api.py -v
"""
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_non_admin_cannot_create_division_when_access_restricted(faculty_user):
    """OPEN_TIMETABLE_ACCESS defaults to True (a testing convenience —
    see app/core/config.py), so this test explicitly restricts access to
    prove the underlying permission check itself is still correct."""
    _, faculty_token = faculty_user
    with patch("app.api.deps.settings.OPEN_TIMETABLE_ACCESS", False):
        response = client.post(
            "/timetable/divisions",
            json={"name": "TE-Z", "strength": 60},
            headers=_auth_headers(faculty_token),
        )
    assert response.status_code == 403


def test_admin_can_create_division(admin_token):
    response = client.post(
        "/timetable/divisions",
        json={"name": "TE-Setup-Test", "strength": 60},
        headers=_auth_headers(admin_token),
    )
    assert response.status_code == 201
    assert response.json()["name"] == "TE-Setup-Test"


def test_full_generation_flow(admin_token, faculty_user):
    """
    The real end-to-end path: admin sets up divisions/subjects/rooms/
    assignments -> triggers generation -> the assigned faculty member can
    view their own resulting timetable via GET /timetable/me.
    """
    faculty_id, faculty_token = faculty_user
    headers = _auth_headers(admin_token)

    # 1. Set up a division
    division = client.post(
        "/timetable/divisions",
        json={"name": "TE-Flow-Test", "strength": 50},
        headers=headers,
    ).json()

    # 2. Set up a subject (lecture-only, keep it simple)
    subject = client.post(
        "/timetable/subjects",
        json={"name": "Software Engineering", "code": "SE301", "weekly_lectures": 3},
        headers=headers,
    ).json()

    # 3. Set up a room
    room = client.post(
        "/timetable/rooms",
        json={"name": "Room T1", "type": "lecture", "capacity": 60},
        headers=headers,
    ).json()

    # 4. Assign the faculty member to teach this subject to this division
    assignment_response = client.post(
        "/timetable/assignments",
        json={"faculty_id": faculty_id, "subject_id": subject["id"], "division_id": division["id"]},
        headers=headers,
    )
    assert assignment_response.status_code == 201

    # 5. Generate
    generate_response = client.post("/timetable/generate", headers=headers)
    assert generate_response.status_code == 200
    body = generate_response.json()
    assert body["status"] in ("OPTIMAL", "FEASIBLE")
    assert body["total_entries"] >= 3  # at least this subject's 3 weekly lectures

    # 6. The assigned faculty can see their own timetable
    my_timetable = client.get("/timetable/me", headers=_auth_headers(faculty_token))
    assert my_timetable.status_code == 200
    entries = my_timetable.json()
    assert any(e["subject_name"] == "Software Engineering" for e in entries)
    assert any(e["division_name"] == "TE-Flow-Test" for e in entries)
    assert any(e["room_name"] == "Room T1" for e in entries)

    # 7. The division's full timetable is also viewable
    division_timetable = client.get(f"/timetable/division/{division['id']}", headers=_auth_headers(faculty_token))
    assert division_timetable.status_code == 200
    assert len(division_timetable.json()) >= 3


def test_generate_requires_admin_when_access_restricted(faculty_user):
    _, faculty_token = faculty_user
    with patch("app.api.deps.settings.OPEN_TIMETABLE_ACCESS", False):
        response = client.post("/timetable/generate", headers=_auth_headers(faculty_token))
    assert response.status_code == 403


def test_unauthenticated_requests_are_rejected():
    response = client.get("/timetable/divisions")
    assert response.status_code == 401

    response = client.post("/timetable/generate")
    assert response.status_code == 401


def test_viewing_unknown_division_returns_404(faculty_user):
    _, faculty_token = faculty_user
    response = client.get("/timetable/division/does-not-exist", headers=_auth_headers(faculty_token))
    assert response.status_code == 404


def test_assignment_rejects_unknown_faculty_id(admin_token):
    headers = _auth_headers(admin_token)
    division = client.post(
        "/timetable/divisions", json={"name": "TE-Ref-Test", "strength": 50}, headers=headers
    ).json()
    subject = client.post(
        "/timetable/subjects", json={"name": "Test Subject", "weekly_lectures": 1}, headers=headers
    ).json()

    response = client.post(
        "/timetable/assignments",
        json={"faculty_id": "does-not-exist", "subject_id": subject["id"], "division_id": division["id"]},
        headers=headers,
    )
    assert response.status_code == 404


def test_seed_sample_data_then_generate(faculty_user):
    """The real end-to-end proof for the one-tap seeder: seed, then
    generate, and confirm real entries come back for the seeding user."""
    faculty_id, faculty_token = faculty_user
    headers = _auth_headers(faculty_token)

    seed = client.post("/timetable/seed-sample-data", headers=headers)
    assert seed.status_code == 200
    body = seed.json()
    assert body["divisions_created"] == 2
    assert body["subjects_created"] == 4
    assert body["assignments_created"] == 8

    generate = client.post("/timetable/generate", headers=headers)
    assert generate.status_code == 200
    assert generate.json()["total_entries"] > 0

    my_timetable = client.get("/timetable/me", headers=headers)
    assert my_timetable.status_code == 200
    assert len(my_timetable.json()) > 0


def test_seed_sample_data_requires_timetable_manager_access(faculty_user):
    _, faculty_token = faculty_user
    with patch("app.api.deps.settings.OPEN_TIMETABLE_ACCESS", False):
        response = client.post("/timetable/seed-sample-data", headers=_auth_headers(faculty_token))
    assert response.status_code == 403
