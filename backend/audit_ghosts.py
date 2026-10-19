import re
from app.db.base import SessionLocal
from app.models.user import User, UserRole
from app.models.academic import TeachingAssignment
from app.models.timetable import TimetableEntry

db = SessionLocal()
all_users = db.query(User).all()

# Find real users mapped by normalized name
real_users_by_name = {}
ghost_users = []
whitespace_dups = []

def norm(name):
    s = re.sub(r'\s+', ' ', (name or '')).strip().lower()
    for prefix in ["dr. ", "prof. ", "mr. ", "mrs. ", "ms. ", "er. "]:
        if s.startswith(prefix):
            s = s[len(prefix):].strip()
    return s

for u in all_users:
    name = (u.full_name or '').strip()
    email = (u.email or '').strip().lower()
    if ' | ' in name or ' / ' in name or ('..' in email and email.endswith('@enosis.edu')):
        ghost_users.append(u)
    else:
        n = norm(name)
        if n in real_users_by_name:
            whitespace_dups.append((u, real_users_by_name[n]))
        else:
            real_users_by_name[n] = u

print(f"Real users count: {len(real_users_by_name)}")
print(f"Ghost users count: {len(ghost_users)}")
print(f"Whitespace duplicates: {len(whitespace_dups)}")
for dup, orig in whitespace_dups:
    print(f"  Duplicate: '{dup.full_name}' ({dup.id[:8]}) vs Original: '{orig.full_name}' ({orig.id[:8]})")
