from app.db.base import SessionLocal
from app.models.academic import Room, InstitutionalCourse, SharedCourse
from app.models.timetable import TimetableEntry

db = SessionLocal()
rooms = db.query(Room).order_by(Room.id).all()
print(f"Total rooms before deduplication: {len(rooms)}")

primary_by_name = {}
to_delete = []

for r in rooms:
    n = r.name.strip().upper()
    if n not in primary_by_name:
        primary_by_name[n] = r
    else:
        primary = primary_by_name[n]
        # Reassign foreign keys
        db.query(TimetableEntry).filter(TimetableEntry.room_id == r.id).update(
            {"room_id": primary.id}, synchronize_session=False
        )
        db.query(InstitutionalCourse).filter(InstitutionalCourse.room_id == r.id).update(
            {"room_id": primary.id}, synchronize_session=False
        )
        db.query(SharedCourse).filter(SharedCourse.room_id == r.id).update(
            {"room_id": primary.id}, synchronize_session=False
        )
        to_delete.append(r)

for r in to_delete:
    db.delete(r)

db.commit()

remaining = db.query(Room).all()
print(f"Total rooms after deduplication: {len(remaining)}")
for r in remaining:
    print(f"  {r.name} ({r.type.value if hasattr(r.type, 'value') else r.type}) [Cap: {r.capacity}]")

db.close()
