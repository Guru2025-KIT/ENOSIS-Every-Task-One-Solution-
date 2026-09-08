import sys
import os

from sqlalchemy import text, inspect
from app.db.base import engine, SessionLocal, Base
import app.models.academic
import app.models.timetable
import app.models.generation_history
import app.models.sli
import app.models.attendance

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

        conn.commit()
    print("Schema sync complete.")

if __name__ == "__main__":
    sync_database_schema()
    from app.seed_sli_dev_data import seed
    print("\n=== 3. RUNNING DEV SEED ===")
    seed()
