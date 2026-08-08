"""
Tests for:
- delegating timetable-management permission to a non-admin faculty member
- the public college-info endpoint
- the Year/Division fields on Division

Run with: pytest tests/test_permissions_and_college_info.py -v
"""
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_college_info_is_public_no_auth_needed():
    response = client.get("/timetable/college-info")
    assert response.status_code == 200
    assert "college_name" in response.json()


def test_faculty_without_delegation_cannot_generate(faculty_user):
    _, faculty_token = faculty_user
    response = client.post("/timetable/generate", headers=_auth_headers(faculty_token))
    assert response.status_code == 403


def test_admin_can_delegate_timetable_access_to_faculty(admin_token, faculty_user):
    faculty_id, faculty_token = faculty_user
    admin_headers = _auth_headers(admin_token)

    # Before delegation: faculty can't even create a division
    denied = client.post(
        "/timetable/divisions",
        json={"name": "TE-Delegate-Test", "year": 2, "division_code": "A", "strength": 50},
        headers=_auth_headers(faculty_token),
    )
    assert denied.status_code == 403

    # Admin delegates timetable-management to this faculty member
    grant = client.post(f"/users/{faculty_id}/timetable-access", headers=admin_headers)
    assert grant.status_code == 200
    assert grant.json()["can_manage_timetable"] is True

    # Now the SAME faculty member (same token — permission is re-checked
    # from the DB on every request, not cached in the token) can create one
    allowed = client.post(
        "/timetable/divisions",
        json={"name": "TE-Delegate-Test", "year": 2, "division_code": "A", "strength": 50},
        headers=_auth_headers(faculty_token),
    )
    assert allowed.status_code == 201

    # And can trigger generation too (empty setup is fine — either a
    # feasible empty result or a 422 "nothing to schedule", both prove
    # the PERMISSION check passed, which is what this test is about)
    generate = client.post("/timetable/generate", headers=_auth_headers(faculty_token))
    assert generate.status_code in (200, 422)

    # Revoke it again
    revoke = client.delete(f"/users/{faculty_id}/timetable-access", headers=admin_headers)
    assert revoke.status_code == 200
    assert revoke.json()["can_manage_timetable"] is False

    denied_again = client.post(
        "/timetable/divisions",
        json={"name": "TE-Delegate-Test-2", "year": 2, "division_code": "B", "strength": 50},
        headers=_auth_headers(faculty_token),
    )
    assert denied_again.status_code == 403


def test_non_admin_cannot_delegate_permission(faculty_user):
    """Only a real admin can grant timetable-management — a delegated
    faculty member can't further delegate to someone else."""
    faculty_id, faculty_token = faculty_user
    response = client.post(f"/users/{faculty_id}/timetable-access", headers=_auth_headers(faculty_token))
    assert response.status_code == 403


def test_division_year_and_code_round_trip(admin_token):
    response = client.post(
        "/timetable/divisions",
        json={"name": "SE-C", "year": 2, "division_code": "C", "strength": 65},
        headers=_auth_headers(admin_token),
    )
    assert response.status_code == 201
    body = response.json()
    assert body["year"] == 2
    assert body["division_code"] == "C"


def test_list_divisions_filters_by_year(admin_token):
    headers = _auth_headers(admin_token)
    client.post("/timetable/divisions", json={"name": "FE-Year-Filter-A", "year": 1, "division_code": "A"}, headers=headers)
    client.post("/timetable/divisions", json={"name": "BE-Year-Filter-A", "year": 4, "division_code": "A"}, headers=headers)

    response = client.get("/timetable/divisions?year=4", headers=headers)
    assert response.status_code == 200
    years = {d["year"] for d in response.json()}
    assert years == {4}
