import uuid
from datetime import date
import pytest
from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.db.base import Base, engine, SessionLocal
from app.main import app
from app.models.academic import Division, Subject, Room, TeachingAssignment
from app.models.generation_history import GenerationRun
from app.models.sli import (
    AcademicClass, Department, Enrollment, Intervention, Semester, Student,
)
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole

client = TestClient(app)


@pytest.fixture(scope="module")
def intervention_test_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # Create unique faculty user
        faculty_user = User(
            id=str(uuid.uuid4()),
            email=f"faculty_int_{uuid.uuid4().hex[:6]}@enosis.edu",
            full_name="Prof. Intervention Test",
            role=UserRole.FACULTY,
            hashed_password="mock_hash",
        )


        db.add(faculty_user)
        db.flush()

        # Create Department, Semester, Subject
        dept = Department(department_code=f"IT_{uuid.uuid4().hex[:4]}", department_name="Information Technology")
        db.add(dept)
        db.flush()

        semester = Semester(
            academic_year="2026-2027",
            semester_number=5,
            status="ACTIVE",
            start_date=date(2026, 7, 1),
            end_date=date(2026, 12, 1),
        )
        db.add(semester)
        db.flush()

        subject = Subject(
            id=str(uuid.uuid4()),
            name="Advanced Database Systems",
            code=f"IT501_{uuid.uuid4().hex[:4]}",
            weekly_lectures=4,
            is_lab=True,
            lab_sessions_per_week=2,
            sli_department_id=dept.department_id,
        )
        db.add(subject)
        db.flush()

        # Create Division and AcademicClass
        division = Division(
            id=str(uuid.uuid4()),
            name="TE IT Division A",
            year=3,
            division_code="A",
        )
        db.add(division)
        db.flush()

        academic_class = AcademicClass(
            department_id=dept.department_id,
            academic_year="2026-2027",
            year_level=3,
            division="A",
            division_id=division.id,
        )
        db.add(academic_class)
        db.flush()

        # Create Timetable Entry for faculty_user
        batch = str(uuid.uuid4())
        gen_run = GenerationRun(id=batch, status="OPTIMAL", validation_passed=True)
        room = Room(name="Lab 101", type="lab", capacity=70)
        db.add_all([gen_run, room])
        db.flush()

        tt_entry = TimetableEntry(
            id=str(uuid.uuid4()),
            batch_id=batch,
            division_id=division.id,
            subject_id=subject.id,
            faculty_id=faculty_user.id,
            room_id=room.id,
            day=1,
            slot=1,
        )
        db.add(tt_entry)
        db.flush()

        # Create Student and Enrollment
        student = Student(
            student_id=f"STU-INT-{uuid.uuid4().hex[:4].upper()}",
            name="Rohan Verma",
            department_id=dept.department_id,
            current_year=3,
            division="A",
        )
        db.add(student)
        db.flush()

        enrollment = Enrollment(
            student_id=student.student_id,
            class_id=academic_class.class_id,
            semester_id=semester.semester_id,
            subject_id=subject.id,
        )
        db.add(enrollment)
        db.commit()

        token = create_access_token(subject=faculty_user.id)

        yield {
            "faculty_token": token,
            "faculty_id": faculty_user.id,
            "enrollment_id": enrollment.enrollment_id,
            "student_id": student.student_id,
        }
    finally:
        db.close()


def test_log_faculty_intervention_success(intervention_test_data):
    """Test successful logging of faculty action / intervention with persistence."""
    token = intervention_test_data["faculty_token"]
    enrollment_id = intervention_test_data["enrollment_id"]

    payload = {
        "enrollment_id": enrollment_id,
        "intervention_type": "1-on-1 Tutoring",
        "implementation_date": "2026-09-12",
        "notes": "Conducted 45-min review on query optimization and joins.",
        "status": "COMPLETED",
    }

    resp = client.post(
        "/sli/interventions/log",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    data = resp.json()

    assert data["intervention_id"] > 0
    assert data["enrollment_id"] == enrollment_id
    assert data["intervention_type"] == "1-on-1 Tutoring"
    assert data["status"] == "COMPLETED"
    assert data["implemented"] is True
    assert data["implementation_date"] == "2026-09-12"
    assert "query optimization" in data["notes"]


def test_log_intervention_invalid_enrollment(intervention_test_data):
    """Logging intervention for non-existent enrollment returns 404."""
    token = intervention_test_data["faculty_token"]

    payload = {
        "enrollment_id": 99999999,
        "intervention_type": "Hands-on Lab Demonstration",
        "notes": "Invalid enrollment test",
    }

    resp = client.post(
        "/sli/interventions/log",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()


def test_log_intervention_validation_failure(intervention_test_data):
    """Logging intervention with empty intervention_type fails validation."""
    token = intervention_test_data["faculty_token"]
    enrollment_id = intervention_test_data["enrollment_id"]

    payload = {
        "enrollment_id": enrollment_id,
        "intervention_type": "",
        "notes": "Testing blank type",
    }

    resp = client.post(
        "/sli/interventions/log",
        json=payload,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


def test_get_enrollment_interventions_history(intervention_test_data):
    """Retrieving intervention history returns all logged interventions chronologically."""
    token = intervention_test_data["faculty_token"]
    enrollment_id = intervention_test_data["enrollment_id"]

    # Log a second intervention
    client.post(
        "/sli/interventions/log",
        json={
            "enrollment_id": enrollment_id,
            "intervention_type": "Peer Mentoring",
            "implementation_date": "2026-09-14",
            "notes": "Paired with top student for lab exercise.",
            "status": "COMPLETED",
        },
        headers={"Authorization": f"Bearer {token}"},
    )

    resp = client.get(
        f"/sli/interventions/enrollment/{enrollment_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)
    assert len(data) >= 2

    types = [item["intervention_type"] for item in data]
    assert "1-on-1 Tutoring" in types
    assert "Peer Mentoring" in types


def test_student_analytics_includes_interventions(intervention_test_data):
    """Student 360 analytics profile includes logged intervention history."""
    token = intervention_test_data["faculty_token"]
    enrollment_id = intervention_test_data["enrollment_id"]

    resp = client.get(
        f"/sli/faculty/analytics/student/{enrollment_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    assert "interventions" in data
    assert isinstance(data["interventions"], list)
    assert len(data["interventions"]) >= 2
    assert any(i["intervention_type"] == "1-on-1 Tutoring" for i in data["interventions"])
