"""
Shared pytest setup for the whole test suite.

Sets DATABASE_URL to in-memory SQLite BEFORE any app imports, so the
app.db.base module creates its engine pointing at the test database.
We then reuse that SAME engine everywhere — no separate test engine,
no monkey-patching, no dependency overrides needed.
"""
import os

# Must happen before ANY app import
os.environ["DATABASE_URL"] = "sqlite://"

import pytest
from sqlalchemy import event

from app.core.security import create_access_token, hash_password
from app.db.base import Base, engine, SessionLocal, get_db
from app.models.user import User, UserRole
import app.models.academic
import app.models.timetable
import app.models.schedule_config
import app.models.constraints
import app.models.generation_history
import app.models.achievement
import app.models.attendance
import app.models.document
import app.models.notification
import app.models.todo
import app.models.sli

# Enable foreign-key enforcement (off by default in SQLite)
@event.listens_for(engine, "connect")
def _set_sqlite_pragma(dbapi_conn, connection_record):
    cursor = dbapi_conn.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


@pytest.fixture(autouse=True)
def setup_db_tables():
    """Creates all tables before each test, drops them after."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def admin_token():
    """
    Creates an admin user directly via the database and returns a valid JWT.
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
