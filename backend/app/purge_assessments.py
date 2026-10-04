import sqlite3
import os

db_paths = [
    os.path.abspath("enosis_dev.db"),
    os.path.abspath("backend/enosis_dev.db"),
    os.path.abspath("../enosis_dev.db"),
    os.path.abspath("../backend/enosis_dev.db"),
    os.path.abspath("test_enosis.db"),
    os.path.abspath("backend/test_enosis.db"),
]

tables_to_clear = [
    "student_topic_feedbacks",
    "pre_semester_responses",
    "mid_semester_responses",
    "end_semester_responses",
    "assessment_submissions",
    "assessments",
    "interventions",
    "intervention_logs",
    "teaching_assignments",
]

for p in set(db_paths):
    if os.path.exists(p):
        print(f"Purging assessments in database: {p}")
        conn = sqlite3.connect(p)
        cursor = conn.cursor()
        for tbl in tables_to_clear:
            try:
                cursor.execute(f"DELETE FROM {tbl}")
                print(f"  - Cleared {tbl}")
            except Exception as e:
                # Table might not exist in sqlite schema
                pass
        conn.commit()
        conn.close()

print("Purge completed successfully!")
