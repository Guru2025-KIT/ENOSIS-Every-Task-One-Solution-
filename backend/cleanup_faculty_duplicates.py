import re
import uuid
from app.db.base import SessionLocal
from app.models.user import User, UserRole
from app.models.academic import TeachingAssignment
from app.models.timetable import TimetableEntry

db = SessionLocal()

def norm(name):
    s = re.sub(r'\s+', ' ', (name or '')).strip().lower()
    for prefix in ["dr. ", "prof. ", "mr. ", "mrs. ", "ms. ", "er. "]:
        if s.startswith(prefix):
            s = s[len(prefix):].strip()
    return s

all_users = db.query(User).all()
real_users_by_norm = {}

# 1. Identify genuine users
for u in all_users:
    name = (u.full_name or '').strip()
    email = (u.email or '').strip().lower()
    if ' | ' in name or ' / ' in name or ('..' in email and email.endswith('@enosis.edu')):
        continue
    n = norm(name)
    if n not in real_users_by_norm:
        # Clean extra spaces in full_name
        cleaned_name = re.sub(r'\s+', ' ', name)
        if u.full_name != cleaned_name:
            u.full_name = cleaned_name
        real_users_by_norm[n] = u
    else:
        # Merge duplicate whitespace user
        primary = real_users_by_norm[n]
        print(f"Merging duplicate {u.id[:8]} ({u.full_name}) into primary {primary.id[:8]} ({primary.full_name})")
        db.query(TeachingAssignment).filter(TeachingAssignment.faculty_id == u.id).update(
            {"faculty_id": primary.id}, synchronize_session=False
        )
        db.query(TimetableEntry).filter(TimetableEntry.faculty_id == u.id).update(
            {"faculty_id": primary.id}, synchronize_session=False
        )
        db.delete(u)

db.commit()

# Refresh real_users_by_norm
all_real_users = db.query(User).filter(
    ~User.full_name.contains(' | '),
    ~User.full_name.contains(' / '),
    ~User.email.contains('..'),
).all()
real_users_by_norm = {norm(u.full_name): u for u in all_real_users}

# 2. Process ghost compound users
ghost_users = db.query(User).filter(
    (User.full_name.contains(' | ')) |
    (User.full_name.contains(' / ')) |
    (User.email.contains('..'))
).all()

print(f"Resolving {len(ghost_users)} ghost users...")
for gu in ghost_users:
    g_name = gu.full_name or ''
    # Split by | or /
    parts = [p.strip() for p in re.split(r'\s*[|/]\s*', g_name) if p.strip()]
    matched_faculty = []
    for p in parts:
        pn = norm(p)
        if pn in real_users_by_norm:
            matched_faculty.append(real_users_by_norm[pn])

    tas = db.query(TeachingAssignment).filter(TeachingAssignment.faculty_id == gu.id).all()
    tes = db.query(TimetableEntry).filter(TimetableEntry.faculty_id == gu.id).all()

    if matched_faculty:
        primary_fac = matched_faculty[0]
        # Reassign existing TAs to primary_fac
        for ta in tas:
            ta.faculty_id = primary_fac.id
            # Also create duplicate TAs for co-faculty so all faculty get workload hours!
            for co_fac in matched_faculty[1:]:
                exists = db.query(TeachingAssignment).filter(
                    TeachingAssignment.faculty_id == co_fac.id,
                    TeachingAssignment.subject_id == ta.subject_id,
                    TeachingAssignment.division_id == ta.division_id,
                    TeachingAssignment.session_type == ta.session_type,
                    TeachingAssignment.batch_name == ta.batch_name,
                ).first()
                if not exists:
                    new_ta = TeachingAssignment(
                        id=str(uuid.uuid4()),
                        faculty_id=co_fac.id,
                        subject_id=ta.subject_id,
                        division_id=ta.division_id,
                        session_type=ta.session_type,
                        weekly_count=ta.weekly_count,
                        duration_slots=ta.duration_slots,
                        batch_name=ta.batch_name,
                        is_shared=True,
                        joint_group_id=ta.joint_group_id or f"joint_{ta.subject_id}",
                    )
                    db.add(new_ta)

        # Reassign TEs to primary_fac
        for te in tes:
            te.faculty_id = primary_fac.id

    else:
        # No matched faculty - delete or reassign to unassigned
        for ta in tas:
            db.delete(ta)
        for te in tes:
            db.delete(te)

    db.delete(gu)

db.commit()

# 3. Final verification
remaining_users = db.query(User).all()
print(f"Cleanup finished! Remaining users in DB: {len(remaining_users)}")
for u in remaining_users:
    print(f"  [{u.role.value if hasattr(u.role, 'value') else u.role}] {u.full_name} | {u.email} | TT Access: {u.can_manage_timetable}")

db.close()
