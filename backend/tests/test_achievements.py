"""
Tests for the Career Advancement (Achievement) module: CRUD, ownership
isolation, and that a document_id must belong to the same user (can't
attach someone else's uploaded certificate to your own achievement).

Run with: pytest tests/test_achievements.py -v
"""
import io
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_create_and_list_achievement(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    create = client.post(
        "/achievements",
        json={
            "title": "Completed FDP on Machine Learning",
            "category": "fdp",
            "organization": "IIT Bombay",
            "date_achieved": "2026-03-25",
        },
        headers=headers,
    )
    assert create.status_code == 201
    body = create.json()
    assert body["title"] == "Completed FDP on Machine Learning"
    assert body["category"] == "fdp"
    assert body["document_url"] is None

    listed = client.get("/achievements/mine", headers=headers)
    assert listed.status_code == 200
    assert any(a["title"] == "Completed FDP on Machine Learning" for a in listed.json())


def test_invalid_category_rejected(faculty_user):
    _, token = faculty_user
    response = client.post(
        "/achievements",
        json={"title": "Bad category test", "category": "not_a_real_category"},
        headers=_auth_headers(token),
    )
    assert response.status_code == 422


def test_delete_achievement(faculty_user):
    _, token = faculty_user
    headers = _auth_headers(token)

    achievement = client.post("/achievements", json={"title": "Delete me"}, headers=headers).json()
    delete_response = client.delete(f"/achievements/{achievement['id']}", headers=headers)
    assert delete_response.status_code == 204

    listed = client.get("/achievements/mine", headers=headers).json()
    assert not any(a["id"] == achievement["id"] for a in listed)


def test_user_cannot_see_another_users_achievements(faculty_user, admin_token):
    _, faculty_token = faculty_user
    client.post("/achievements", json={"title": "Faculty-only achievement"}, headers=_auth_headers(faculty_token))

    admin_achievements = client.get("/achievements/mine", headers=_auth_headers(admin_token)).json()
    assert not any(a["title"] == "Faculty-only achievement" for a in admin_achievements)


def test_achievement_with_own_document_succeeds(faculty_user):
    """Attaching a document you own to your own achievement should work,
    and the response should include the document's URL."""
    _, token = faculty_user
    headers = _auth_headers(token)

    fake_cloudinary_response = {
        "secure_url": "https://res.cloudinary.com/demo/image/upload/v1/enosis/cert.pdf",
        "public_id": "enosis/cert",
        "resource_type": "raw",
        "bytes": 10,
    }
    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_cloudinary_response):
        document = client.post(
            "/documents/upload",
            files={"file": ("cert.pdf", io.BytesIO(b"fake cert"), "application/pdf")},
            headers=headers,
        ).json()

    achievement = client.post(
        "/achievements",
        json={"title": "With certificate", "document_id": document["id"]},
        headers=headers,
    )
    assert achievement.status_code == 201
    assert achievement.json()["document_url"] == fake_cloudinary_response["secure_url"]


def test_cannot_attach_another_users_document(faculty_user, admin_token):
    """The important isolation test: can't claim someone else's uploaded
    certificate as proof of your own achievement."""
    _, faculty_token = faculty_user

    fake_cloudinary_response = {
        "secure_url": "https://res.cloudinary.com/demo/image/upload/v1/enosis/admin_cert.pdf",
        "public_id": "enosis/admin_cert",
        "resource_type": "raw",
        "bytes": 10,
    }
    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_cloudinary_response):
        admin_document = client.post(
            "/documents/upload",
            files={"file": ("admin_cert.pdf", io.BytesIO(b"admin's file"), "application/pdf")},
            headers=_auth_headers(admin_token),
        ).json()

    attempt = client.post(
        "/achievements",
        json={"title": "Trying to steal a certificate", "document_id": admin_document["id"]},
        headers=_auth_headers(faculty_token),
    )
    assert attempt.status_code == 404
