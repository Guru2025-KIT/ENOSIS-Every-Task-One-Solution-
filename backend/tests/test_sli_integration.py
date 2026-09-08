import uuid
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.db.base import SessionLocal
from app.main import app
from app.models.academic import Division, Room, Subject
from app.models.generation_history import GenerationRun
from app.models.sli import (
    AcademicClass, Department, EndSemesterResponse, Enrollment,
    Semester, Student,
)
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole
from app.schemas.sli_integration import CopoMappingStatus
from app.services.sli_integration_service import CopoIntegrationAdapter

client = TestClient(app)


@pytest.fixture
def integration_test_data():
    db = SessionLocal()
    try:
        dept = Department(department_name=f"Dept_Integ_{uuid.uuid4().hex[:6]}", department_code=f"I_{uuid.uuid4().hex[:4].upper()}")
        db.add(dept)
        db.flush()

        fac1 = User(
            id=str(uuid.uuid4()),
            email=f"fac1_integ_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Pass@123"),
            full_name="Prof. Integration Lead",
            role=UserRole.FACULTY,
            department=dept.department_name,
        )
        fac2 = User(
            id=str(uuid.uuid4()),
            email=f"fac2_integ_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Pass@123"),
            full_name="Prof. External Faculty",
            role=UserRole.FACULTY,
            department=dept.department_name,
        )
        admin = User(
            id=str(uuid.uuid4()),
            email=f"admin_integ_{uuid.uuid4().hex[:6]}@college.edu",
            hashed_password=hash_password("Admin@123"),
            full_name="Admin Coordinator",
            role=UserRole.ADMIN,
            department=dept.department_name,
        )
        db.add_all([fac1, fac2, admin])
        db.flush()

        sem = Semester(academic_year="2026-27", semester_number=5, status="ACTIVE")
        sub = Subject(id=str(uuid.uuid4()), name="Software Engineering", code=f"SE{uuid.uuid4().hex[:4].upper()}", credits=3)
        div = Division(id=str(uuid.uuid4()), name="TE Comp Div A", year=3, division_code="A")
        db.add_all([sem, sub, div])
        db.flush()

        ac = AcademicClass(department_id=dept.department_id, academic_year="2026-27", year_level=3, division="A", division_id=div.id)
        db.add(ac)
        db.flush()

        batch = str(uuid.uuid4())
        gen = GenerationRun(id=batch, status="OPTIMAL", validation_passed=True)
        room = Room(name="Lab 101", type="lab", capacity=50)
        db.add_all([gen, room])
        db.flush()

        tt = TimetableEntry(id=str(uuid.uuid4()), batch_id=batch, division_id=div.id, subject_id=sub.id, faculty_id=fac1.id, room_id=room.id, day=1, slot=1)
        db.add(tt)
        db.flush()

        # 2 Students with END responses
        s1 = Student(student_id=f"STU-INT-1-{uuid.uuid4().hex[:4].upper()}", name="Student 1", department_id=dept.department_id, current_year=3, division="A")
        s2 = Student(student_id=f"STU-INT-2-{uuid.uuid4().hex[:4].upper()}", name="Student 2", department_id=dept.department_id, current_year=3, division="A")
        db.add_all([s1, s2])
        db.flush()

        e1 = Enrollment(student_id=s1.student_id, class_id=ac.class_id, semester_id=sem.semester_id, subject_id=sub.id)
        e2 = Enrollment(student_id=s2.student_id, class_id=ac.class_id, semester_id=sem.semester_id, subject_id=sub.id)
        db.add_all([e1, e2])
        db.flush()

        end1 = EndSemesterResponse(
            enrollment_id=e1.enrollment_id,
            understanding_level=5,
            concept_application_ability=4,
            core_concepts_mastery=5,
            problem_solving_ability=4,
            practical_lab_competence=5,
            independent_learning_ability=4,
            real_world_application=4,
            learning_satisfaction=5,
            overall_learning_experience=5,
        )
        end2 = EndSemesterResponse(
            enrollment_id=e2.enrollment_id,
            understanding_level=3,
            concept_application_ability=4,
            core_concepts_mastery=3,
            problem_solving_ability=2,
            practical_lab_competence=4,
            independent_learning_ability=3,
            real_world_application=3,
            learning_satisfaction=4,
            overall_learning_experience=3,
        )
        db.add_all([end1, end2])
        db.commit()

        token1 = create_access_token(subject=fac1.id)
        token2 = create_access_token(subject=fac2.id)
        admin_token = create_access_token(subject=admin.id)

        yield {
            "token1": token1,
            "token2": token2,
            "admin_token": admin_token,
            "class_id": ac.class_id,
            "subject_id": sub.id,
            "semester_id": sem.semester_id,
        }
    finally:
        db.close()


def test_copo_adapter_unconfigured_fallback():
    """Adapter returns graceful unconfigured DTO when external CO-PO service is not deployed."""
    res = CopoIntegrationAdapter.get_context_copo_summary(
        class_id=10,
        subject_id="sub-test-id",
        semester_id=1,
    )
    assert res.is_available is False
    assert res.status == CopoMappingStatus.NOT_CONFIGURED
    assert res.overall_attainment_pct is None
    assert res.co_attainments == []


def test_export_sli_end_competency_summary_pipeline(integration_test_data):
    """SLI outgoing pipeline exports correct averages of frozen END competencies for external use."""
    token = integration_test_data["token1"]
    class_id = integration_test_data["class_id"]
    sub_id = integration_test_data["subject_id"]
    sem_id = integration_test_data["semester_id"]

    resp = client.get(
        f"/sli/integration/export/end-competency-summary/{class_id}/{sub_id}/{sem_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["total_enrolled"] == 2
    assert data["total_end_assessed"] == 2
    assert data["assessment_coverage_pct"] == 100.0

    # Avg understanding = (5 + 3)/2 = 4.0
    assert data["avg_understanding_level"] == 4.0
    # Avg core concepts = (5 + 3)/2 = 4.0
    assert data["avg_core_concepts_mastery"] == 4.0
    # Avg problem solving = (4 + 2)/2 = 3.0
    assert data["avg_problem_solving_ability"] == 3.0
    # Avg practical lab = (5 + 4)/2 = 4.5
    assert data["avg_practical_lab_competence"] == 4.5
    # Avg satisfaction = (5 + 4)/2 = 4.5
    assert data["avg_learning_satisfaction"] == 4.5
    assert data["avg_overall_experience"] == 4.0


def test_export_sli_end_competency_summary_authorization(integration_test_data):
    """Unauthorized faculty receives 403 Forbidden; Admin receives 200 OK."""
    token2 = integration_test_data["token2"]
    admin_token = integration_test_data["admin_token"]
    class_id = integration_test_data["class_id"]
    sub_id = integration_test_data["subject_id"]
    sem_id = integration_test_data["semester_id"]

    # Unauthorized faculty -> 403
    r_unauth = client.get(
        f"/sli/integration/export/end-competency-summary/{class_id}/{sub_id}/{sem_id}",
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert r_unauth.status_code == 403

    # Admin -> 200
    r_admin = client.get(
        f"/sli/integration/export/end-competency-summary/{class_id}/{sub_id}/{sem_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert r_admin.status_code == 200
