"""
Shared pytest setup for the whole test suite.

IMPORTANT: the test-database env var and any stale-file cleanup MUST happen
here, in conftest.py, and MUST run before any test module does
`from app.main import app`. pytest always imports conftest.py before
collecting test files in the same directory, which is exactly the timing
we need — see the DEV_DIARY entry about why deleting the SQLite file after
the app's connection to it already exists causes spurious "readonly
database" errors.
"""
import os

if os.path.exists("test_enosis.db"):
    os.remove("test_enosis.db")
os.environ["DATABASE_URL"] = "sqlite:///./test_enosis.db"

import pytest

from app.core.security import create_access_token, hash_password
from app.db.base import SessionLocal
from app.models.user import User, UserRole


@pytest.fixture(scope="session", autouse=True)
def cleanup_after_all_tests():
    """Removes the test database file once, after the entire test run finishes."""
    yield
    if os.path.exists("test_enosis.db"):
        os.remove("test_enosis.db")


@pytest.fixture
def admin_token():
    """
    Creates an admin user directly via the database (bypassing the public
    /auth/signup endpoint, which always creates FACULTY accounts — there's
    no public "make me an admin" endpoint, on purpose) and returns a valid
    JWT for them. In real deployments, the first admin account would be
    created by a one-off seed script, not through the API.
    """
    db = SessionLocal()
    unique = os.urandom(4).hex()
    admin = User(
        email=f"admin-{unique}@enosis.edu.in",
        hashed_password=hash_password("adminpass123"),
        full_name="Admin User",
        role=UserRole.ADMIN,
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    token = create_access_token(subject=admin.id)
    db.close()
    return token


@pytest.fixture
def faculty_user():
    """Creates a regular (non-admin) faculty user and returns (user_id, token)."""
    db = SessionLocal()
    unique = os.urandom(4).hex()
    user = User(
        email=f"faculty-{unique}@enosis.edu.in",
        hashed_password=hash_password("facultypass123"),
        full_name="Dr. Test Faculty",
        role=UserRole.FACULTY,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=user.id)
    user_id = user.id
    db.close()
    return user_id, token
