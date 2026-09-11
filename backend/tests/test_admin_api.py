import io
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.db.base import SessionLocal
from app.models.user import User, UserRole

client = TestClient(app)


def _auth_headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_admin_dashboard_stats(admin_token):
    res = client.get("/admin/dashboard-stats", headers=_auth_headers(admin_token))
    assert res.status_code == 200
    data = res.json()
    assert "total_faculty" in data
    assert "active_faculty" in data
    assert "allocated_courses_count" in data
    assert "attainment_completed_percent" in data
    assert "pending_governance_count" in data
    assert "department_counts" in data
    assert isinstance(data["department_counts"], dict)


def test_faculty_manual_crud(admin_token):
    # 1. Create
    payload = {
        "full_name": "Prof. Ada Lovelace",
        "email": "ada.lovelace.test@enosis.edu.in",
        "employee_id": "EMP-ADA-001",
        "department": "Computer Engineering",
        "designation": "Associate Professor",
        "phone": "+91 9876543210"
    }
    create_res = client.post("/admin/faculty", json=payload, headers=_auth_headers(admin_token))
    assert create_res.status_code == 201
    created_data = create_res.json()
    faculty_id = created_data["id"]
    assert created_data["full_name"] == payload["full_name"]
    assert created_data["email"] == payload["email"]
    assert created_data["employee_id"] == payload["employee_id"]
    assert created_data["department"] == payload["department"]

    # 2. List
    list_res = client.get("/admin/faculty", headers=_auth_headers(admin_token))
    assert list_res.status_code == 200
    faculty_list = list_res.json()
    assert any(f["id"] == faculty_id for f in faculty_list)

    # 3. Update
    update_payload = {
        "designation": "Professor & Head",
        "can_manage_timetable": True
    }
    update_res = client.put(f"/admin/faculty/{faculty_id}", json=update_payload, headers=_auth_headers(admin_token))
    assert update_res.status_code == 200
    updated_data = update_res.json()
    assert updated_data["designation"] == "Professor & Head"
    assert updated_data["can_manage_timetable"] is True

    # 4. Delete / Deactivate
    del_res = client.delete(f"/admin/faculty/{faculty_id}", headers=_auth_headers(admin_token))
    assert del_res.status_code == 200


def test_spreadsheet_validation_and_bulk_import(admin_token):
    # Prepare CSV content with valid, missing, and duplicate rows
    csv_data = (
        "Name,Email,Employee ID,Department,Designation,Phone\n"
        "Grace Hopper,grace.hopper.test@enosis.edu.in,EMP-GH-001,Information Technology,Professor,+91 9988776655\n"
        "Alan Turing,alan.turing.test@enosis.edu.in,EMP-AT-001,Computer Engineering,Professor,+91 9988776654\n"
        "Invalid User,,EMP-BAD-001,Computer Engineering,Lecturer,\n"  # Missing email
        "Duplicate Grace,grace.hopper.test@enosis.edu.in,EMP-GH-002,Information Technology,Assistant Professor,\n"  # Duplicate email in file
    )

    files = {"file": ("faculty_test.csv", io.BytesIO(csv_data.encode("utf-8")), "text/csv")}
    val_res = client.post("/admin/faculty/validate-upload", files=files, headers=_auth_headers(admin_token))
    assert val_res.status_code == 200
    val_data = val_res.json()

    assert val_data["total_rows"] == 4
    assert val_data["valid_count"] == 2
    assert len(val_data["valid_rows"]) == 2
    assert len(val_data["missing_fields_rows"]) >= 1
    assert len(val_data["duplicate_rows"]) >= 1

    # Bulk Import
    import_payload = {
        "rows": val_data["valid_rows"]
    }
    imp_res = client.post("/admin/faculty/import", json=import_payload, headers=_auth_headers(admin_token))
    assert imp_res.status_code == 200
    imp_data = imp_res.json()
    assert imp_data["imported_count"] == 2


def test_subject_allocations_and_reassignment(admin_token):
    # Ensure we have a faculty member first
    fac_payload = {
        "full_name": "Prof. Linus Torvalds",
        "email": "linus.test@enosis.edu.in",
        "employee_id": "EMP-LT-001",
        "department": "Computer Engineering",
    }
    fac_res = client.post("/admin/faculty", json=fac_payload, headers=_auth_headers(admin_token))
    fac_id = fac_res.json()["id"]

    # 1. Create Allocation
    alloc_payload = {
        "course_code": "CS-TEST-501",
        "course_name": "Advanced Operating Systems",
        "department": "Computer Engineering",
        "year": "TE",
        "semester": "Semester V",
        "credits": 4,
        "faculty_id": fac_id,
        "co_faculty_name": "Prof. Dennis Ritchie"
    }
    create_alloc_res = client.post("/admin/allocations", json=alloc_payload, headers=_auth_headers(admin_token))
    assert create_alloc_res.status_code == 201
    alloc_data = create_alloc_res.json()
    alloc_id = alloc_data["id"]
    assert alloc_data["course_code"] == "CS-TEST-501"
    assert alloc_data["faculty_id"] == fac_id

    # 2. List Allocations
    list_res = client.get("/admin/allocations", headers=_auth_headers(admin_token))
    assert list_res.status_code == 200
    assert any(a["id"] == alloc_id for a in list_res.json())

    # Create another faculty for reassign
    fac2_payload = {
        "full_name": "Prof. Ken Thompson",
        "email": "ken.test@enosis.edu.in",
        "employee_id": "EMP-KT-001",
        "department": "Computer Engineering",
    }
    fac2_res = client.post("/admin/faculty", json=fac2_payload, headers=_auth_headers(admin_token))
    fac2_id = fac2_res.json()["id"]

    # 3. Reassign
    reassign_payload = {
        "faculty_id": fac2_id,
        "co_faculty_name": "None"
    }
    reassign_res = client.post(f"/admin/allocations/{alloc_id}/reassign", json=reassign_payload, headers=_auth_headers(admin_token))
    assert reassign_res.status_code == 200
    assert reassign_res.json()["faculty_id"] == fac2_id


def test_governance_requests_and_action(admin_token, faculty_user):
    fac_id, fac_token = faculty_user

    # Submit an achievement from faculty
    ach_payload = {
        "title": "Published Research Paper on Distributed Consensus",
        "category": "publication",
        "description": "IEEE Transactions on Computers publication.",
    }
    ach_res = client.post("/achievements", json=ach_payload, headers=_auth_headers(fac_token))
    assert ach_res.status_code == 201
    ach_id = ach_res.json()["id"]

    # Admin lists governance requests
    gov_res = client.get("/admin/governance-requests", headers=_auth_headers(admin_token))
    assert gov_res.status_code == 200
    requests = gov_res.json()
    matching = [r for r in requests if r["id"] == ach_id]
    assert len(matching) > 0

    # Admin approves request
    action_payload = {
        "action": "APPROVE",
        "remarks": "Verified IEEE publication."
    }
    action_res = client.post(f"/admin/governance-requests/{ach_id}/action", json=action_payload, headers=_auth_headers(admin_token))
    assert action_res.status_code == 200
    assert action_res.json()["status"] == "APPROVED"
