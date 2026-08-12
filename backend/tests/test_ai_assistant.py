"""
Tests for the AI chat scaffold. Same honesty pattern as documents: we
don't have a real Groq API key in this environment, so we test (1) the
real "not configured" behavior, and (2) the route's own logic with the
actual Groq network call mocked out.

Run with: pytest tests/test_ai_assistant.py -v
"""
from unittest.mock import patch

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_chat_returns_503_when_not_configured(faculty_user):
    """Real current behavior — no GROQ_API_KEY is set."""
    _, token = faculty_user
    response = client.post("/ai/chat", json={"message": "Hello"}, headers=_auth_headers(token))
    assert response.status_code == 503
    assert "isn't configured" in response.json()["detail"].lower()


def test_chat_succeeds_with_mocked_groq_response(faculty_user):
    _, token = faculty_user

    with patch("app.api.routes.ai_assistant.is_configured", return_value=True), \
         patch("app.api.routes.ai_assistant.send_chat_message", return_value="Hi! How can I help you today?"):
        response = client.post("/ai/chat", json={"message": "Hello"}, headers=_auth_headers(token))

    assert response.status_code == 200
    assert response.json()["reply"] == "Hi! How can I help you today?"


def test_chat_rejects_empty_message(faculty_user):
    _, token = faculty_user
    with patch("app.api.routes.ai_assistant.is_configured", return_value=True):
        response = client.post("/ai/chat", json={"message": "   "}, headers=_auth_headers(token))
    assert response.status_code == 400


def test_chat_requires_authentication():
    response = client.post("/ai/chat", json={"message": "Hello"})
    assert response.status_code == 401


def test_chat_surfaces_llm_errors_as_502(faculty_user):
    """If Groq itself errors (rate limit, bad key, etc.), that should
    come back as a clear 502, not a raw 500 crash."""
    _, token = faculty_user
    with patch("app.api.routes.ai_assistant.is_configured", return_value=True), \
         patch("app.api.routes.ai_assistant.send_chat_message", side_effect=RuntimeError("rate limited")):
        response = client.post("/ai/chat", json={"message": "Hello"}, headers=_auth_headers(token))
    assert response.status_code == 502
