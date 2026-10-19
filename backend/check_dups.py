from app.db.base import SessionLocal
from app.models.user import User, UserRole
from app.services.admin_service import list_faculty

db = SessionLocal()
all_fac = list_faculty(db)
print(f"list_faculty count: {len(all_fac)}")

by_name = {}
by_email = {}
by_emp = {}

for f in all_fac:
    n = f.full_name.strip().lower()
    e = f.email.strip().lower()
    emp = (f.employee_id or '').strip().lower()
    by_name.setdefault(n, []).append(f)
    by_email.setdefault(e, []).append(f)
    if emp:
        by_emp.setdefault(emp, []).append(f)

dup_names = {k: v for k, v in by_name.items() if len(v) > 1}
dup_emails = {k: v for k, v in by_email.items() if len(v) > 1}
dup_emps = {k: v for k, v in by_emp.items() if len(v) > 1}

print("Duplicate Names:", len(dup_names))
for k, v in dup_names.items():
    print(f"  Name '{k}': {[x.id for x in v]}, emails: {[x.email for x in v]}")

print("Duplicate Emails:", len(dup_emails))
for k, v in dup_emails.items():
    print(f"  Email '{k}': {[x.id for x in v]}")

print("Duplicate EmpIDs:", len(dup_emps))
for k, v in dup_emps.items():
    print(f"  EmpID '{k}': {[x.id for x in v]}")
