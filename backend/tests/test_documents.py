"""
Tests for the document storage module. We don't have real Cloudinary
credentials in this environment, so these tests cover two things
honestly: (1) the "not configured yet" path, which is real and exactly
what happens until you add your credentials, and (2) the upload/delete
logic with the Cloudinary SDK call itself mocked out — proving our code
around it (ownership, DB record creation, error handling) is correct
independent of whether Cloudinary is actually reachable.

Run with: pytest tests/test_documents.py -v
"""
import io
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

_MINIMAL_PDF = (
    b"%PDF-1.7\n"
    b"1 0 obj\n<< /Type /Catalog >>\nendobj\n"
    b"trailer\n<< /Root 1 0 R >>\n%%EOF\n"
)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_upload_returns_503_when_not_configured(faculty_user):
    """The route returns a clear error when storage is unavailable."""
    _, token = faculty_user
    with patch("app.api.routes.documents.is_configured", return_value=False):
        response = client.post(
            "/documents/upload",
            files={"file": ("test.pdf", io.BytesIO(b"fake pdf bytes"), "application/pdf")},
            headers=_auth_headers(token),
        )
    assert response.status_code == 503
    assert "isn't configured" in response.json()["detail"].lower()


def test_upload_succeeds_with_mocked_cloudinary(faculty_user):
    """Proves the upload route's OWN logic (auth, DB record creation,
    response shape) is correct, with Cloudinary's actual network call
    replaced by a fake response — since we don't have real credentials
    to test against the live service in this environment."""
    _, token = faculty_user

    fake_cloudinary_response = {
        "secure_url": "https://res.cloudinary.com/demo/image/upload/v1/enosis/fake123.pdf",
        "public_id": "enosis/fake123",
        "resource_type": "raw",
        "bytes": 14,
    }

    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_cloudinary_response):
        response = client.post(
            "/documents/upload",
            files={"file": ("certificate.pdf", io.BytesIO(b"fake pdf bytes"), "application/pdf")},
            headers=_auth_headers(token),
        )

    assert response.status_code == 201
    body = response.json()
    assert body["file_name"] == "certificate.pdf"
    assert body["url"] == fake_cloudinary_response["secure_url"]
    assert body["file_size_bytes"] == 14


def test_list_and_delete_owned_document(faculty_user):
    _, token = faculty_user
    fake_cloudinary_response = {
        "secure_url": "https://res.cloudinary.com/demo/image/upload/v1/enosis/todelete.pdf",
        "public_id": "enosis/todelete",
        "resource_type": "raw",
        "bytes": 5,
    }

    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_cloudinary_response):
        upload_response = client.post(
            "/documents/upload",
            files={"file": ("todelete.pdf", io.BytesIO(b"hello"), "application/pdf")},
            headers=_auth_headers(token),
        )
    document_id = upload_response.json()["id"]

    listed = client.get("/documents/mine", headers=_auth_headers(token))
    assert listed.status_code == 200
    assert any(d["id"] == document_id for d in listed.json())

    # Delete — Cloudinary's delete call is mocked too, same reasoning
    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.delete_file", return_value={"result": "ok"}):
        delete_response = client.delete(f"/documents/{document_id}", headers=_auth_headers(token))
    assert delete_response.status_code == 204

    listed_after = client.get("/documents/mine", headers=_auth_headers(token))
    assert not any(d["id"] == document_id for d in listed_after.json())


def test_user_cannot_delete_another_users_document(faculty_user, admin_token):
    """Same ownership-isolation pattern as To-Do's tasks."""
    _, faculty_token = faculty_user
    fake_response = {
        "secure_url": "https://res.cloudinary.com/demo/image/upload/v1/enosis/owned.pdf",
        "public_id": "enosis/owned",
        "resource_type": "raw",
        "bytes": 5,
    }

    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_response):
        upload_response = client.post(
            "/documents/upload",
            files={"file": ("owned.pdf", io.BytesIO(b"hello"), "application/pdf")},
            headers=_auth_headers(faculty_token),
        )
    document_id = upload_response.json()["id"]

    delete_attempt = client.delete(f"/documents/{document_id}", headers=_auth_headers(admin_token))
    assert delete_attempt.status_code == 404


def test_view_and_download_return_original_pdf_bytes_and_filename(faculty_user):
    _, token = faculty_user
    fake_response = {
        "secure_url": "https://res.cloudinary.com/demo/raw/upload/opaque-id",
        "public_id": "opaque-id",
        "resource_type": "raw",
        "bytes": len(_MINIMAL_PDF),
    }

    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_response):
        upload_response = client.post(
            "/documents/upload",
            files={"file": ("original certificate.pdf", io.BytesIO(_MINIMAL_PDF), "application/pdf")},
            headers=_auth_headers(token),
        )
    document_id = upload_response.json()["id"]

    with patch("app.api.routes.documents._fetch_storage_file", return_value=_MINIMAL_PDF):
        view_response = client.get(
            f"/documents/{document_id}/content",
            headers=_auth_headers(token),
        )
        download_response = client.get(
            f"/documents/{document_id}/download",
            headers=_auth_headers(token),
        )

    assert view_response.status_code == 200
    assert view_response.headers["content-type"] == "application/pdf"
    assert view_response.headers["content-disposition"].startswith(
        'inline; filename="original certificate.pdf"'
    )
    assert view_response.content == _MINIMAL_PDF
    assert view_response.headers["x-content-type-options"] == "nosniff"

    assert download_response.status_code == 200
    assert download_response.headers["content-type"] == "application/pdf"
    assert download_response.headers["content-disposition"].startswith(
        'attachment; filename="original certificate.pdf"'
    )
    assert download_response.content == _MINIMAL_PDF


def test_document_content_is_owner_scoped(faculty_user, admin_token):
    _, faculty_token = faculty_user
    fake_response = {
        "secure_url": "https://res.cloudinary.com/demo/raw/upload/opaque-id",
        "public_id": "opaque-id",
        "resource_type": "raw",
        "bytes": len(_MINIMAL_PDF),
    }
    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_response):
        upload_response = client.post(
            "/documents/upload",
            files={"file": ("owned.pdf", io.BytesIO(_MINIMAL_PDF), "application/pdf")},
            headers=_auth_headers(faculty_token),
        )

    response = client.get(
        f"/documents/{upload_response.json()['id']}/content",
        headers=_auth_headers(admin_token),
    )
    assert response.status_code == 404


def test_document_content_requires_authentication():
    response = client.get("/documents/not-a-document/content")
    assert response.status_code == 401


def test_pdf_content_rejects_non_pdf_storage_response(faculty_user):
    _, token = faculty_user
    fake_response = {
        "secure_url": "https://res.cloudinary.com/demo/raw/upload/opaque-id",
        "public_id": "opaque-id",
        "resource_type": "raw",
        "bytes": 4,
    }
    with patch("app.api.routes.documents.is_configured", return_value=True), \
         patch("app.api.routes.documents.upload_file", return_value=fake_response):
        upload_response = client.post(
            "/documents/upload",
            files={"file": ("original.pdf", io.BytesIO(b"fake"), "application/pdf")},
            headers=_auth_headers(token),
        )

    with patch("app.api.routes.documents._fetch_storage_file", return_value=b"not a pdf"):
        response = client.get(
            f"/documents/{upload_response.json()['id']}/content",
            headers=_auth_headers(token),
        )
    assert response.status_code == 502
    assert "valid PDF" in response.json()["detail"]


def test_unauthenticated_upload_rejected():
    response = client.post(
        "/documents/upload",
        files={"file": ("test.pdf", io.BytesIO(b"x"), "application/pdf")},
    )
    assert response.status_code == 401
