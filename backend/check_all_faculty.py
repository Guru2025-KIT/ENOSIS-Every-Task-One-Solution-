from app.db.base import SessionLocal
from app.models.user import User, UserRole

db = SessionLocal()
users = db.query(User).filter(User.role == UserRole.FACULTY).all()
print("All 48 faculty in DB:")
for u in users:
    print(f"ID: {u.id[:8]} | Name: '{u.full_name}' | Email: '{u.email}' | EmpID: '{u.employee_id}'")
