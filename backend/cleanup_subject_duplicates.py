"""
Clean up duplicate and composite subjects in ENOSIS database.
Merges duplicates by code or normalized name and re-links all
TeachingAssignment and TimetableEntry records to the canonical Subject.
"""

from collections import defaultdict
from app.db.base import SessionLocal
from app.models.academic import Subject, TeachingAssignment
from app.models.timetable import TimetableEntry

def cleanup_subjects(dry_run=False):
    db = SessionLocal()
    try:
        all_subjects = db.query(Subject).all()
        print(f"Total subjects currently in DB: {len(all_subjects)}")

        # Step 1: Identify composite subjects containing ' | ' or ' / '
        composites = [s for s in all_subjects if " | " in s.name or " / " in s.name]
        print(f"Found {len(composites)} composite subjects with ' | ' or ' / '")

        # Map canonical subjects by code and normalized name
        canonical_by_code = {}
        canonical_by_name = {}

        pure_subjects = [s for s in all_subjects if " | " not in s.name and " / " not in s.name]
        for s in pure_subjects:
            code = (s.code or "").strip().upper()
            name_norm = (s.name or "").strip().lower()
            if code and code not in canonical_by_code:
                canonical_by_code[code] = s
            if name_norm and name_norm not in canonical_by_name:
                canonical_by_name[name_norm] = s

        # Step 2: Handle composites by re-pointing references to the best matching pure subject
        for comp in composites:
            parts = [p.strip() for p in comp.name.replace(" / ", " | ").split(" | ")]
            target = None
            for p in parts:
                p_norm = p.lower()
                if p_norm in canonical_by_name:
                    target = canonical_by_name[p_norm]
                    break
                # Try code match
                p_code = (comp.code or "").strip().upper()
                if p_code in canonical_by_code:
                    target = canonical_by_code[p_code]
                    break

            if not target and pure_subjects:
                # Fallback to the first pure subject or create clean subject for first part
                first_part = parts[0]
                target = canonical_by_name.get(first_part.lower())
                if not target:
                    target = pure_subjects[0]

            if target and target.id != comp.id:
                # Re-point TimetableEntry
                te_count = db.query(TimetableEntry).filter(TimetableEntry.subject_id == comp.id).count()
                if te_count > 0:
                    print(f"  Re-linking {te_count} TimetableEntry rows from composite '{comp.name[:30]}' to '{target.name[:30]}'")
                    if not dry_run:
                        db.query(TimetableEntry).filter(TimetableEntry.subject_id == comp.id).update(
                            {TimetableEntry.subject_id: target.id}, synchronize_session=False
                        )

                # Re-point TeachingAssignment
                ta_count = db.query(TeachingAssignment).filter(TeachingAssignment.subject_id == comp.id).count()
                if ta_count > 0:
                    print(f"  Re-linking {ta_count} TeachingAssignment rows from composite '{comp.name[:30]}' to '{target.name[:30]}'")
                    if not dry_run:
                        # Check if TA already exists for target to prevent unique key violation
                        for ta in db.query(TeachingAssignment).filter(TeachingAssignment.subject_id == comp.id).all():
                            existing_ta = db.query(TeachingAssignment).filter(
                                TeachingAssignment.faculty_id == ta.faculty_id,
                                TeachingAssignment.subject_id == target.id,
                                TeachingAssignment.division_id == ta.division_id,
                            ).first()
                            if existing_ta:
                                db.delete(ta)
                            else:
                                ta.subject_id = target.id

                print(f"  Deleting composite subject: {comp.name[:40]}")
                if not dry_run:
                    db.delete(comp)

        if not dry_run:
            db.commit()

        # Step 3: Deduplicate pure subjects with the same code or normalized name
        import re
        remaining_subjects = db.query(Subject).all()
        by_key = defaultdict(list)
        
        # Regex to detect course code like UAMPC0401, UAMVS0433, UDSC0631, etc.
        code_pattern = re.compile(r'([A-Z]{3,6}\d{4,5}[A-Z]?)', re.IGNORECASE)

        for s in remaining_subjects:
            s_code = (s.code or "").strip().upper()
            s_name = (s.name or "").strip()
            
            # Extract standard course code if embedded
            found_codes = code_pattern.findall(s_code) or code_pattern.findall(s_name)
            if found_codes:
                key = found_codes[0].upper()
            else:
                # Clean name: remove special chars
                clean_name = re.sub(r'[^a-zA-Z0-9]', '', s_name.lower())
                key = clean_name
            by_key[key].append(s)

        for key, group in by_key.items():
            if len(group) > 1:
                # Pick the canonical subject:
                # 1. Has genuine code matching the key
                # 2. Cleanest name (not having code duplicated in name)
                # 3. Has credits / SLI department
                def score(subj):
                    sc = 0
                    if (subj.code or "").strip().upper() == key:
                        sc += 100
                    if subj.credits:
                        sc += 20
                    if subj.sli_department_id:
                        sc += 10
                    # Penalize names that have the code repeated inside
                    if key in subj.name.upper() and len(subj.name) > len(key) + 5:
                        sc -= 5
                    return sc

                group.sort(key=score, reverse=True)
                canonical = group[0]
                duplicates = group[1:]
                
                # Make sure canonical has the proper code and clean name
                if not canonical.code or canonical.code != key:
                    canonical.code = key
                if canonical.name.startswith(f"{key} "):
                    canonical.name = canonical.name[len(key):].strip()

                print(f"Deduplicating subject key '{key}': Keeping '{canonical.name}' [{canonical.code}] ({canonical.id}), removing {len(duplicates)} duplicates.")

                for dup in duplicates:
                    if not dry_run:
                        db.query(TimetableEntry).filter(TimetableEntry.subject_id == dup.id).update(
                            {TimetableEntry.subject_id: canonical.id}, synchronize_session=False
                        )
                        for ta in db.query(TeachingAssignment).filter(TeachingAssignment.subject_id == dup.id).all():
                            existing_ta = db.query(TeachingAssignment).filter(
                                TeachingAssignment.faculty_id == ta.faculty_id,
                                TeachingAssignment.subject_id == canonical.id,
                                TeachingAssignment.division_id == ta.division_id,
                            ).first()
                            if existing_ta:
                                db.delete(ta)
                            else:
                                ta.subject_id = canonical.id
                        db.delete(dup)

        if not dry_run:
            db.commit()

        final_subjects = db.query(Subject).all()
        print(f"\nCompleted! Subjects before: {len(all_subjects)}, Subjects after: {len(final_subjects)}")
        for s in sorted(final_subjects, key=lambda x: x.name):
            print(f"  [{s.code or 'N/A'}] {s.name} (ID: {s.id})")

    except Exception as e:
        db.rollback()
        print(f"Error during subject cleanup: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    cleanup_subjects(dry_run=False)
