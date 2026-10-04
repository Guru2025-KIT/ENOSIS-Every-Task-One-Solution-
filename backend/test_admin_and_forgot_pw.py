import os
import sys
import urllib.request
import urllib.parse
import json

BASE_URL = "http://localhost:8000"

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app.db.base import SessionLocal
from app.models.user import User, UserRole
from app.core.security import hash_password

def run_test():
    # 0. Clean baseline setup
    db = SessionLocal()
    admin = db.query(User).filter(User.role == UserRole.ADMIN).first()
    if admin:
        admin.email = "admin@enosis.edu.in"
        admin.hashed_password = hash_password("admin123")
        admin.full_name = "ENOSIS Administrator"
        admin.is_active = True
        db.commit()
    db.close()

    print("=== TEST 1: Login with admin credentials ===")
    data = urllib.parse.urlencode({
        "username": "admin@enosis.edu.in",
        "password": "admin123"
    }).encode("utf-8")
    
    req = urllib.request.Request(
        f"{BASE_URL}/auth/login",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    with urllib.request.urlopen(req) as resp:
        body = json.loads(resp.read().decode("utf-8"))
        token = body.get("access_token")
        print(f"  [OK] Admin Login with admin@enosis.edu.in (pw: admin123) SUCCESS! Token: {token[:20]}...")



    print("\n=== TEST 2: Update Admin Username, Email, and Password ===")
    new_admin_email = "admin_master@enosis.edu.in"
    new_admin_pw = "master12345"
    
    profile_payload = {
        "full_name": "ENOSIS Master Administrator",
        "email": new_admin_email,
        "current_password": "admin123",
        "new_password": new_admin_pw
    }
    req = urllib.request.Request(
        f"{BASE_URL}/admin/profile",
        data=json.dumps(profile_payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}"
        },
        method="PUT"
    )
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print(f"  [OK] Profile updated: {res.get('full_name')} ({res.get('email')})")

    print("\n=== TEST 3: Login with NEW Admin Email and NEW Password ===")
    data = urllib.parse.urlencode({
        "username": new_admin_email,
        "password": new_admin_pw
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/auth/login",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    with urllib.request.urlopen(req) as resp:
        body = json.loads(resp.read().decode("utf-8"))
        new_token = body.get("access_token")
        print(f"  [OK] New Admin Login SUCCESS! Token: {new_token[:20]}...")

    print("\n=== TEST 4: Test Admin Forgot Password ===")
    forgot_payload = {"email": new_admin_email}
    req = urllib.request.Request(
        f"{BASE_URL}/auth/forgot-password",
        data=json.dumps(forgot_payload).encode("utf-8"),
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print(f"  [OK] Admin Forgot Password Response: {res.get('message')}")

    print("\n=== TEST 5: Create a Test Faculty and Delete It ===")
    # First get faculty list
    req = urllib.request.Request(
        f"{BASE_URL}/admin/faculty",
        headers={"Authorization": f"Bearer {new_token}"}
    )
    with urllib.request.urlopen(req) as resp:
        faculty_list = json.loads(resp.read().decode("utf-8"))
        print(f"  Total existing faculty: {len(faculty_list)}")

    # Create a dummy faculty to delete
    create_payload = {
        "full_name": "Dr. Test To Delete",
        "email": "test_delete@enosis.edu",
        "employee_id": "DEL-999",
        "department": "Computer Science",
        "designation": "Assistant Professor"
    }
    req = urllib.request.Request(
        f"{BASE_URL}/admin/faculty?send_email=false",
        data=json.dumps(create_payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {new_token}"
        }
    )
    with urllib.request.urlopen(req) as resp:
        created = json.loads(resp.read().decode("utf-8"))
        fac_id = created["faculty"]["id"]
        print(f"  [OK] Created temporary faculty: ID={fac_id}")

    # Delete the faculty
    req = urllib.request.Request(
        f"{BASE_URL}/admin/faculty/{fac_id}",
        headers={"Authorization": f"Bearer {new_token}"},
        method="DELETE"
    )
    with urllib.request.urlopen(req) as resp:
        del_res = json.loads(resp.read().decode("utf-8"))
        print(f"  [OK] Deleted faculty response: {del_res}")

    print("\n=== TEST 6: Fetch Admin Dashboard Stats after Deletion ===")
    req = urllib.request.Request(
        f"{BASE_URL}/admin/dashboard-stats",
        headers={"Authorization": f"Bearer {new_token}"}
    )
    with urllib.request.urlopen(req) as resp:
        stats = json.loads(resp.read().decode("utf-8"))
        print(f"  [OK] Dashboard Stats: Total Faculty={stats.get('total_faculty')}, Active={stats.get('active_faculty')}")

    # Finally restore admin credentials back to admin@enosis.edu.in / admin123 for convenience
    print("\n=== Resetting Admin back to admin@enosis.edu.in / admin123 ===")
    profile_payload = {
        "full_name": "ENOSIS Administrator",
        "email": "admin@enosis.edu.in",
        "current_password": new_admin_pw,
        "new_password": "admin123"
    }
    req = urllib.request.Request(
        f"{BASE_URL}/admin/profile",
        data=json.dumps(profile_payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {new_token}"
        },
        method="PUT"
    )
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print(f"  [OK] Admin reset to: {res.get('full_name')} ({res.get('email')})")

if __name__ == "__main__":
    run_test()
