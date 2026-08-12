"""
Tests for:
- delegating timetable-management permission to a non-admin faculty member
- the public college-info endpoint
- the Year/Division fields on Division
- the OPEN_TIMETABLE_ACCESS testing-convenience toggle

Run with: pytest tests/test_permissions_and_college_info.py -v
"""
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_college_info_is_public_no_auth_needed():
    response = client.get("/timetable/college-info")
    assert response.status_code == 200
    assert "college_name" in response.json()


def test_open_timetable_access_lets_any_faculty_generate_by_default(faculty_user):
    """OPEN_TIMETABLE_ACCESS defaults to True — this is the CURRENT real
    behavior of the app right now, not a hypothetical. Any logged-in
    faculty member can generate without any admin delegation step."""
    _, faculty_token = faculty_user
    response = client.post("/timetable/generate", headers=_auth_headers(faculty_token))
    # 200 (generated) or 422 (nothing to schedule yet) both prove the
    # PERMISSION check passed — 403 would mean it didn't.
    assert response.status_code in (200, 422)


def test_faculty_without_delegation_cannot_generate_when_access_is_restricted(faculty_user):
    """Proves the underlying admin-or-delegated permission check still
    works correctly — this is what happens once OPEN_TIMETABLE_ACCESS is
    set to False for a real deployment."""
    _, faculty_token = faculty_user
    with patch("app.api.deps.settings.OPEN_TIMETABLE_ACCESS", False):
        response = client.post("/timetable/generate", headers=_auth_headers(faculty_token))
    assert response.status_code == 403


def test_admin_can_delegate_timetable_access_to_faculty(admin_token, faculty_user):
    """This test specifically exercises the admin-or-delegated permission
    check, so it runs with OPEN_TIMETABLE_ACCESS off — otherwise every
    request would trivially succeed regardless of delegation state,
    proving nothing about the delegation mechanism itself."""
    faculty_id, faculty_token = faculty_user
    admin_headers = _auth_headers(admin_token)

    with patch("app.api.deps.settings.OPEN_TIMETABLE_ACCESS", False):
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


def test_faculty_list_accessible_to_delegated_manager_not_just_admin(admin_token, faculty_user):
    """A delegated (non-admin) timetable coordinator needs to see the
    faculty list to build assignments — the stricter /users endpoint
    (admin-only) would block them, so /timetable/faculty-list uses the
    same require_timetable_manager check as everything else in this
    module. Runs with OPEN_TIMETABLE_ACCESS off since it's specifically
    testing the delegation mechanism."""
    faculty_id, faculty_token = faculty_user
    admin_headers = _auth_headers(admin_token)

    with patch("app.api.deps.settings.OPEN_TIMETABLE_ACCESS", False):
        # Before delegation: denied, same as any other timetable-manager route
        denied = client.get("/timetable/faculty-list", headers=_auth_headers(faculty_token))
        assert denied.status_code == 403

        client.post(f"/users/{faculty_id}/timetable-access", headers=admin_headers)

        allowed = client.get("/timetable/faculty-list", headers=_auth_headers(faculty_token))
        assert allowed.status_code == 200
    assert any(f["id"] == faculty_id for f in allowed.json())
    # Confirms it's the trimmed shape, not the full admin-only UserOut
    assert set(allowed.json()[0].keys()) == {"id", "full_name", "email"}
