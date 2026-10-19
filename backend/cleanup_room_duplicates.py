"""
Clean up duplicate and composite rooms in ENOSIS database.
Merges duplicates by name and re-links all TimetableEntry records to the canonical Room.
Ensures RoomType.LAB vs RoomType.LECTURE is strictly accurate.
"""

from collections import defaultdict
from app.db.base import SessionLocal
from app.models.academic import Room, RoomType
from app.models.timetable import TimetableEntry

def cleanup_rooms():
    db = SessionLocal()
    try:
        all_rooms = db.query(Room).all()
        print(f"Total rooms currently in DB: {len(all_rooms)}")

        # Step 1: Identify composite rooms containing ' | ' or ' / '
        composites = [r for r in all_rooms if " | " in r.name or " / " in r.name]
        print(f"Found {len(composites)} composite rooms with ' | ' or ' / '")

        pure_rooms = [r for r in all_rooms if " | " not in r.name and " / " not in r.name]
        canonical_by_name = {}
        for r in pure_rooms:
            norm = r.name.strip().lower()
            if norm not in canonical_by_name:
                canonical_by_name[norm] = r

        # Step 2: Handle composites by re-pointing references to the pure first part
        for comp in composites:
            parts = [p.strip() for p in comp.name.replace(" / ", " | ").split(" | ")]
            first_part = parts[0]
            target = canonical_by_name.get(first_part.lower())
            if not target:
                # Create the pure target room if it didn't exist
                is_lab = "lab" in first_part.lower()
                target = Room(
                    name=first_part,
                    type=RoomType.LAB if is_lab else RoomType.LECTURE,
                    capacity=60 if not is_lab else 30
                )
                db.add(target)
                db.flush()
                canonical_by_name[first_part.lower()] = target

            # Re-point TimetableEntry
            te_count = db.query(TimetableEntry).filter(TimetableEntry.room_id == comp.id).count()
            if te_count > 0:
                print(f"  Re-linking {te_count} TimetableEntry rows from composite '{comp.name}' to '{target.name}'")
                db.query(TimetableEntry).filter(TimetableEntry.room_id == comp.id).update(
                    {TimetableEntry.room_id: target.id}, synchronize_session=False
                )

            print(f"  Deleting composite room: {comp.name}")
            db.delete(comp)

        db.commit()

        # Step 3: Deduplicate pure rooms with the identical normalized name
        remaining_rooms = db.query(Room).all()
        by_name = defaultdict(list)
        for r in remaining_rooms:
            norm = r.name.strip().lower()
            by_name[norm].append(r)

        print(f"\nDeduplicating {len(by_name)} distinct room names...")
        for norm_name, group in by_name.items():
            if len(group) > 1:
                # Keep the first one as canonical
                canonical = group[0]
                duplicates = group[1:]
                
                # Ensure correct room type
                is_lab = "lab" in canonical.name.lower()
                canonical.type = RoomType.LAB if is_lab else RoomType.LECTURE

                for dup in duplicates:
                    te_count = db.query(TimetableEntry).filter(TimetableEntry.room_id == dup.id).count()
                    if te_count > 0:
                        db.query(TimetableEntry).filter(TimetableEntry.room_id == dup.id).update(
                            {TimetableEntry.room_id: canonical.id}, synchronize_session=False
                        )
                    db.delete(dup)

        db.commit()

        # Final audit
        final_rooms = db.query(Room).all()
        print(f"\nCompleted! Rooms before: {len(all_rooms)}, Rooms after: {len(final_rooms)}")
        for r in sorted(final_rooms, key=lambda x: (str(x.type), x.name)):
            te_c = db.query(TimetableEntry).filter(TimetableEntry.room_id == r.id).count()
            print(f"  [{r.type.value if hasattr(r.type, 'value') else r.type}] {r.name} (ID: {r.id}, Linked Entries: {te_c})")

    except Exception as e:
        db.rollback()
        print(f"Error during room cleanup: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    cleanup_rooms()
