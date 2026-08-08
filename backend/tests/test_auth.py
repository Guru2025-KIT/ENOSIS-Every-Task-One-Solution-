"""
First backend test — covers the whole Auth flow end-to-end:
signup -> login -> use the token to call a protected route.

Run with: pytest

DB setup/cleanup for the whole test suite lives in conftest.py.
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_signup_creates_a_user():
    response = client.post(
        "/auth/signup",
        json={
            "email": "priya.sharma@enosis.edu.in",
            "password": "supersecret123",
            "full_name": "Dr. Priya Sharma",
            "employee_id": "CS2015407",
            "department": "Computer Science",
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "priya.sharma@enosis.edu.in"
    assert "hashed_password" not in body  # password hash must never leak in responses
    assert "password" not in body


def test_signup_rejects_duplicate_email():
    payload = {
        "email": "dupe@enosis.edu.in",
        "password": "supersecret123",
        "full_name": "Dr. Dupe",
    }
    first = client.post("/auth/signup", json=payload)
    assert first.status_code == 201

    second = client.post("/auth/signup", json=payload)
    assert second.status_code == 400


def test_login_and_access_protected_route():
    # 1. Sign up
    client.post(
        "/auth/signup",
        json={
            "email": "login.test@enosis.edu.in",
            "password": "supersecret123",
            "full_name": "Login Test",
        },
    )

    # 2. Log in (OAuth2PasswordRequestForm expects form data, not JSON)
    login_response = client.post(
        "/auth/login",
        data={"username": "login.test@enosis.edu.in", "password": "supersecret123"},
    )
    assert login_response.status_code == 200
    token = login_response.json()["access_token"]
    assert token

    # 3. Use the token to call the protected /auth/me route
    me_response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me_response.status_code == 200
    assert me_response.json()["email"] == "login.test@enosis.edu.in"


def test_login_rejects_wrong_password():
    client.post(
        "/auth/signup",
        json={
            "email": "wrongpass@enosis.edu.in",
            "password": "correctpassword",
            "full_name": "Wrong Pass Test",
        },
    )

    response = client.post(
        "/auth/login",
        data={"username": "wrongpass@enosis.edu.in", "password": "incorrectpassword"},
    )
    assert response.status_code == 401


def test_protected_route_rejects_missing_token():
    response = client.get("/auth/me")
    assert response.status_code == 401
