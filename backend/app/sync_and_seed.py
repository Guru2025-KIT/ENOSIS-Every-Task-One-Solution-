import sys
import os

from sqlalchemy import text, inspect
from app.db.base import engine, SessionLocal, Base
import app.models.academic
import app.models.timetable
import app.models.generation_history
import app.models.sli
import app.models.attendance
import app.models.todo

def sync_database_schema():
    print("=== 1. ENSURING ALL TABLES EXIST ===")
    Base.metadata.create_all(bind=engine)
    
    print("=== 2. ADDING MISSING COLUMNS TO EXISTING TABLES IF NEEDED ===")
    inspector = inspect(engine)
    
    with engine.connect() as conn:
        # 1. subjects
        subject_cols = {col["name"] for col in inspector.get_columns("subjects")}
        if "sli_department_id" not in subject_cols:
            conn.execute(text("ALTER TABLE subjects ADD COLUMN sli_department_id INT NULL;"))
        if "credits" not in subject_cols:
            conn.execute(text("ALTER TABLE subjects ADD COLUMN credits DECIMAL(3,1) NULL;"))
        if "subject_type" not in subject_cols:
            conn.execute(text("ALTER TABLE subjects ADD COLUMN subject_type VARCHAR(30) NULL;"))
        if "placement_relevance" not in subject_cols:
            conn.execute(text("ALTER TABLE subjects ADD COLUMN placement_relevance DECIMAL(4,2) NULL;"))

        # 2. pre_semester_responses
        pre_cols = {col["name"] for col in inspector.get_columns("pre_semester_responses")}
        for col_name, col_type in [
            ("subject_interest", "SMALLINT NULL"),
            ("self_assessed_skill", "SMALLINT NULL"),
            ("learning_confidence", "SMALLINT NULL"),
            ("expected_difficulty", "SMALLINT NULL"),
            ("skills_to_improve", "JSON NULL"),
            ("preferred_learning_style", "VARCHAR(50) NULL"),
            ("goals_expectations", "TEXT NULL"),
            ("submitted_at", "DATETIME NULL"),
            ("updated_at", "DATETIME NULL"),
        ]:
            if col_name not in pre_cols:
                conn.execute(text(f"ALTER TABLE pre_semester_responses ADD COLUMN {col_name} {col_type};"))

        # 3. mid_semester_responses
        mid_cols = {col["name"] for col in inspector.get_columns("mid_semester_responses")}
        for col_name, col_type in [
            ("current_confidence", "SMALLINT NULL"),
            ("current_interest", "SMALLINT NULL"),
            ("perceived_difficulty", "SMALLINT NULL"),
            ("understanding_level", "SMALLINT NULL"),
            ("concept_application_ability", "SMALLINT NULL"),
            ("learning_satisfaction", "SMALLINT NULL"),
            ("useful_learning_format", "VARCHAR(50) NULL"),
            ("resource_effectiveness", "SMALLINT NULL"),
            ("practical_lab_experience", "SMALLINT NULL"),
            ("teaching_pace", "VARCHAR(30) NULL"),
            ("learning_barriers", "JSON NULL"),
            ("skills_progress", "JSON NULL"),
            ("submitted_at", "DATETIME NULL"),
            ("updated_at", "DATETIME NULL"),
        ]:
            if col_name not in mid_cols:
                conn.execute(text(f"ALTER TABLE mid_semester_responses ADD COLUMN {col_name} {col_type};"))

        # 4. end_semester_responses
        end_cols = {col["name"] for col in inspector.get_columns("end_semester_responses")}
        for col_name, col_type in [
            ("final_confidence", "SMALLINT NULL"),
            ("final_interest", "SMALLINT NULL"),
            ("final_difficulty", "SMALLINT NULL"),
            ("exit_competency_theory", "SMALLINT NULL"),
            ("exit_competency_practical", "SMALLINT NULL"),
            ("exit_competency_problem_solving", "SMALLINT NULL"),
            ("exit_competency_independent_learning", "SMALLINT NULL"),
            ("exit_competency_industry_readiness", "SMALLINT NULL"),
            ("effective_learning_format", "VARCHAR(50) NULL"),
            ("resource_effectiveness", "SMALLINT NULL"),
            ("practical_lab_experience", "SMALLINT NULL"),
            ("teaching_pace", "VARCHAR(30) NULL"),
            ("overall_learning_experience", "SMALLINT NULL"),
            ("skills_progress", "JSON NULL"),
            ("submitted_at", "DATETIME NULL"),
            ("updated_at", "DATETIME NULL"),
        ]:
            if col_name not in end_cols:
                conn.execute(text(f"ALTER TABLE end_semester_responses ADD COLUMN {col_name} {col_type};"))

        # 5. classes
        class_cols = {col["name"] for col in inspector.get_columns("classes")}
        if "division_id" not in class_cols:
            conn.execute(text("ALTER TABLE classes ADD COLUMN division_id VARCHAR(36) NULL;"))

        # 6. student_topic_feedback
        topic_fb_cols = {col["name"] for col in inspector.get_columns("student_topic_feedback")}
        if "progress_status" not in topic_fb_cols:
            conn.execute(text("ALTER TABLE student_topic_feedback ADD COLUMN progress_status VARCHAR(20) NULL;"))

        # 7. assessments
        if "assessments" in inspector.get_table_names():
            assessment_cols = {col["name"] for col in inspector.get_columns("assessments")}
            for col_name, col_type in [
                ("class_id", "INT NULL"),
                ("faculty_id", "VARCHAR(36) NULL"),
                ("status", "VARCHAR(20) NOT NULL DEFAULT 'DRAFT'"),
                ("access_token", "VARCHAR(64) NULL"),
                ("questions", "JSON NULL"),
                ("created_at", "DATETIME NULL"),
                ("updated_at", "DATETIME NULL"),
            ]:
                if col_name not in assessment_cols:
                    conn.execute(text(f"ALTER TABLE assessments ADD COLUMN {col_name} {col_type};"))

        if "assessment_id" not in pre_cols:
            conn.execute(text("ALTER TABLE pre_semester_responses ADD COLUMN assessment_id INT NULL;"))
        if "assessment_id" not in mid_cols:
            conn.execute(text("ALTER TABLE mid_semester_responses ADD COLUMN assessment_id INT NULL;"))
        if "assessment_id" not in end_cols:
            conn.execute(text("ALTER TABLE end_semester_responses ADD COLUMN assessment_id INT NULL;"))

        # 8. question_bank
        if "question_bank" in inspector.get_table_names():
            qb_cols = {col["name"] for col in inspector.get_columns("question_bank")}
            for col_name, col_type in [
                ("skill_id", "VARCHAR(100) NULL"),
                ("difficulty", "SMALLINT NULL DEFAULT 3"),
                ("marks", "INT NULL DEFAULT 1"),
                ("options", "JSON NULL"),
                ("question_title", "VARCHAR(255) NULL"),
                ("section", "VARCHAR(100) NULL"),
                ("dimension", "VARCHAR(100) NULL"),
                ("competency", "VARCHAR(100) NULL"),
            ]:
                if col_name not in qb_cols:
                    conn.execute(text(f"ALTER TABLE question_bank ADD COLUMN {col_name} {col_type};"))

        # 9. MySQL Check Constraints Migration (ensure 'END' is allowed in student_topic_feedback)
        if engine.dialect.name == "mysql":
            try:
                res = conn.execute(text("""
                    SELECT CONSTRAINT_NAME 
                    FROM information_schema.TABLE_CONSTRAINTS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'student_topic_feedback' 
                    AND CONSTRAINT_TYPE = 'CHECK';
                """)).fetchall()
                for r in res:
                    cname = r[0]
                    try:
                        conn.execute(text(f"ALTER TABLE student_topic_feedback DROP CHECK `{cname}`;"))
                    except Exception:
                        pass
                conn.execute(text("ALTER TABLE student_topic_feedback ADD CONSTRAINT ck_topic_feedback_stage CHECK (stage IN ('PRE', 'MID', 'END'));"))
            except Exception as e:
                print("MySQL check constraint sync notice:", e)

        # 10. interventions / sli_interventions
        for tbl in ["interventions", "sli_interventions"]:
            if tbl in inspector.get_table_names():
                interv_cols = {col["name"] for col in inspector.get_columns(tbl)}
                for col_name, col_type in [
                    ("enrollment_id", "INT NULL"),
                    ("faculty_id", "VARCHAR(50) NULL"),
                    ("status", "VARCHAR(50) NOT NULL DEFAULT 'COMPLETED'"),
                    ("created_at", "DATETIME NULL"),
                    ("updated_at", "DATETIME NULL"),
                ]:
                    if col_name not in interv_cols:
                        conn.execute(text(f"ALTER TABLE {tbl} ADD COLUMN {col_name} {col_type};"))

        if engine.dialect.name == "sqlite" and "interventions" in inspector.get_table_names():
            for col in inspector.get_columns("interventions"):
                if col["name"] == "recommendation_id" and not col.get("nullable", True):
                    try:
                        conn.execute(text("DROP INDEX IF EXISTS ix_interventions_recommendation_id;"))
                        conn.execute(text("DROP INDEX IF EXISTS ix_interventions_enrollment_id;"))
                        conn.execute(text("DROP INDEX IF EXISTS ix_interventions_faculty_id;"))
                        conn.execute(text("ALTER TABLE interventions RENAME TO interventions_old;"))
                        app.models.sli.Intervention.__table__.create(bind=conn)
                        old_cols = {c["name"] for c in inspector.get_columns("interventions_old")}
                        common_cols = [c for c in ["intervention_id", "enrollment_id", "recommendation_id", "faculty_id", "intervention_type", "status", "implemented", "implementation_date", "notes", "created_at", "updated_at"] if c in old_cols]
                        cols_str = ", ".join(common_cols)
                        conn.execute(text(f"INSERT INTO interventions ({cols_str}) SELECT {cols_str} FROM interventions_old;"))
                        conn.execute(text("DROP TABLE interventions_old;"))
                    except Exception as e:
                        print("SQLite interventions table migration notice:", e)

        # 11. tasks
        if "tasks" in inspector.get_table_names():
            task_cols = {col["name"] for col in inspector.get_columns("tasks")}
            for col_name, col_type in [
                ("status", "VARCHAR(20) NOT NULL DEFAULT 'TODO'"),
                ("category", "VARCHAR(100) NULL"),
                ("tags", "JSON NULL"),
                ("estimated_duration_minutes", "INT NULL"),
                ("recurrence_rule", "JSON NULL"),
                ("reminders_config", "JSON NULL"),
                ("subtasks", "JSON NULL"),
                ("completed_at", "DATETIME NULL"),
                ("updated_at", "DATETIME NULL"),
            ]:
                if col_name not in task_cols:
                    conn.execute(text(f"ALTER TABLE tasks ADD COLUMN {col_name} {col_type};"))

        # 12. task_reminders (created automatically by Base.metadata.create_all if not existing)
        if "task_reminders" not in inspector.get_table_names():
            app.models.todo.TaskReminder.__table__.create(bind=conn)

        conn.commit()
        print("=== DATABASE SCHEMA SYNC COMPLETE ===")

if __name__ == "__main__":
    sync_database_schema()

    from app.seed_sli_dev_data import seed
    print("\n=== 3. RUNNING DEV SEED ===")
    seed()
