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
    
    with engine.begin() as conn:
        # 0. users
        if "users" in inspector.get_table_names():
            user_cols = {col["name"] for col in inspector.get_columns("users")}
            if "designation" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN designation VARCHAR(100) NULL;"))
            if "phone" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN phone VARCHAR(30) NULL;"))
            if "role" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN role VARCHAR(20) NOT NULL DEFAULT 'faculty';"))
            if "can_manage_timetable" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN can_manage_timetable BOOLEAN NOT NULL DEFAULT 0;"))
            if "is_active" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT 1;"))
            if "employee_id" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN employee_id VARCHAR(50) NULL;"))
            if "department" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN department VARCHAR(100) NULL;"))
            if "office_address" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN office_address VARCHAR(255) NULL;"))
            if "joining_date" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN joining_date VARCHAR(50) NULL;"))
            if "experience" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN experience VARCHAR(50) NULL;"))
            if "created_at" not in user_cols:
                conn.execute(text("ALTER TABLE users ADD COLUMN created_at DATETIME NULL;"))


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

        # 13. schedule_config
        if "schedule_config" in inspector.get_table_names():
            sc_cols = {col["name"] for col in inspector.get_columns("schedule_config")}
            if "lecture_duration_minutes" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN lecture_duration_minutes INT NOT NULL DEFAULT 60;"))
            if "lab_duration_minutes" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN lab_duration_minutes INT NOT NULL DEFAULT 120;"))
            if "tutorial_duration_minutes" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN tutorial_duration_minutes INT NOT NULL DEFAULT 60;"))
            if "hod_name" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN hod_name VARCHAR(255) NULL;"))
            if "end_time" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN end_time VARCHAR(10) NULL DEFAULT '17:00';"))
            if "break1_enabled" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN break1_enabled BOOLEAN NOT NULL DEFAULT 1;"))
            if "break1_after_lectures" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN break1_after_lectures INT NOT NULL DEFAULT 2;"))
            if "break1_duration_minutes" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN break1_duration_minutes INT NOT NULL DEFAULT 15;"))
            if "break2_enabled" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN break2_enabled BOOLEAN NOT NULL DEFAULT 1;"))
            if "break2_after_lectures" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN break2_after_lectures INT NOT NULL DEFAULT 5;"))
            if "break2_duration_minutes" not in sc_cols:
                conn.execute(text("ALTER TABLE schedule_config ADD COLUMN break2_duration_minutes INT NOT NULL DEFAULT 30;"))

        # 14. rooms
        if "rooms" in inspector.get_table_names():
            room_cols = {col["name"] for col in inspector.get_columns("rooms")}
            if "building" not in room_cols:
                conn.execute(text("ALTER TABLE rooms ADD COLUMN building VARCHAR(100) NULL;"))
            if "equipment" not in room_cols:
                conn.execute(text("ALTER TABLE rooms ADD COLUMN equipment TEXT NULL;"))
            if "is_active" not in room_cols:
                conn.execute(text("ALTER TABLE rooms ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT 1;"))
            if "department" not in room_cols:
                conn.execute(text("ALTER TABLE rooms ADD COLUMN department VARCHAR(100) NULL;"))

        # 15. timetable_entries
        if "timetable_entries" in inspector.get_table_names():
            tt_cols = {col["name"] for col in inspector.get_columns("timetable_entries")}
            if "batch_name" not in tt_cols:
                conn.execute(text("ALTER TABLE timetable_entries ADD COLUMN batch_name VARCHAR(50) NULL;"))
            if "session_type" not in tt_cols:
                conn.execute(text("ALTER TABLE timetable_entries ADD COLUMN session_type VARCHAR(30) NULL DEFAULT 'Theory';"))

        # 16. achievements
        if "achievements" in inspector.get_table_names():
            ach_cols = {col["name"] for col in inspector.get_columns("achievements")}
            if "updated_at" not in ach_cols:
                conn.execute(text("ALTER TABLE achievements ADD COLUMN updated_at DATETIME NULL;"))

        # 17. teaching_assignments
        if "teaching_assignments" in inspector.get_table_names():
            ta_cols = {col["name"] for col in inspector.get_columns("teaching_assignments")}
            if "session_type" not in ta_cols:
                conn.execute(text("ALTER TABLE teaching_assignments ADD COLUMN session_type VARCHAR(50) NOT NULL DEFAULT 'theory';"))
            if "weekly_count" not in ta_cols:
                conn.execute(text("ALTER TABLE teaching_assignments ADD COLUMN weekly_count INT NOT NULL DEFAULT 1;"))
            if "duration_slots" not in ta_cols:
                conn.execute(text("ALTER TABLE teaching_assignments ADD COLUMN duration_slots INT NOT NULL DEFAULT 1;"))
            if "batch_name" not in ta_cols:
                conn.execute(text("ALTER TABLE teaching_assignments ADD COLUMN batch_name VARCHAR(50) NULL;"))
            if "is_shared" not in ta_cols:
                conn.execute(text("ALTER TABLE teaching_assignments ADD COLUMN is_shared BOOLEAN NOT NULL DEFAULT 0;"))
            if "joint_group_id" not in ta_cols:
                conn.execute(text("ALTER TABLE teaching_assignments ADD COLUMN joint_group_id VARCHAR(100) NULL;"))
            if "requires_room_type" not in ta_cols:
                conn.execute(text("ALTER TABLE teaching_assignments ADD COLUMN requires_room_type VARCHAR(50) NULL;"))

        # 18. timetable_constraints
        if "timetable_constraints" in inspector.get_table_names():
            tc_cols = {col["name"] for col in inspector.get_columns("timetable_constraints")}
            if "weight" not in tc_cols:
                conn.execute(text("ALTER TABLE timetable_constraints ADD COLUMN weight INT NOT NULL DEFAULT 100;"))

        print("=== DATABASE SCHEMA SYNC COMPLETE ===")



def seed_admin_user():
    """
    Ensures a system administrator account exists.
    If an admin already exists (with customized email or password), their credentials are preserved.
    Only if no admin account exists at all do we create the default admin account.
    """
    from app.models.user import User, UserRole
    from app.core.security import hash_password

    DEFAULT_ADMIN_EMAIL = os.environ.get("ADMIN_EMAIL", "admin@enosis.edu.in").strip().lower()
    DEFAULT_ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "admin123")
    DEFAULT_ADMIN_NAME = os.environ.get("ADMIN_NAME", "ENOSIS Administrator")

    db = SessionLocal()
    try:
        admin_user = db.query(User).filter(User.role == UserRole.ADMIN).first()
        if not admin_user:
            admin_user = db.query(User).filter(User.email == DEFAULT_ADMIN_EMAIL).first()
            if admin_user:
                admin_user.role = UserRole.ADMIN
                admin_user.is_active = True
                admin_user.can_manage_timetable = True
                db.commit()
                print(f"  [OK] Promoted existing {admin_user.email} to ADMIN role.")
            else:
                new_admin = User(
                    email=DEFAULT_ADMIN_EMAIL,
                    hashed_password=hash_password(DEFAULT_ADMIN_PASSWORD),
                    full_name=DEFAULT_ADMIN_NAME,
                    role=UserRole.ADMIN,
                    department="Administration",
                    employee_id="ADMIN-001",
                    is_active=True,
                    can_manage_timetable=True,
                )
                db.add(new_admin)
                db.commit()
                print(f"  [OK] Created default admin user: {DEFAULT_ADMIN_EMAIL} (password: {DEFAULT_ADMIN_PASSWORD})")
        else:
            admin_user.is_active = True
            admin_user.can_manage_timetable = True
            db.commit()
            print(f"  [OK] Admin account active & verified: {admin_user.email}")
    except Exception as e:
        db.rollback()
        print(f"  [WARN] Admin check notice: {e}")
    finally:
        db.close()



def purge_legacy_assessments():
    """
    Purges all old/legacy assessments, student responses, and manual teaching assignments.
    """
    db = SessionLocal()
    try:
        from app.models.sli import Assessment, PreSemesterResponse, MidSemesterResponse, EndSemesterResponse, StudentTopicFeedback
        from app.models.academic import TeachingAssignment
        db.query(StudentTopicFeedback).delete(synchronize_session=False)
        db.query(PreSemesterResponse).delete(synchronize_session=False)
        db.query(MidSemesterResponse).delete(synchronize_session=False)
        db.query(EndSemesterResponse).delete(synchronize_session=False)
        try:
            from app.models.sli import Intervention
            db.query(Intervention).delete(synchronize_session=False)
        except Exception:
            pass
        db.query(Assessment).delete(synchronize_session=False)
        db.query(TeachingAssignment).delete(synchronize_session=False)
        db.commit()
        print("  ✓ Purged all legacy assessments, responses, and unassigned teaching contexts.")
    except Exception as e:
        db.rollback()
        print(f"  ⚠ Assessment purge notice: {e}")
    finally:
        db.close()


def seed_all_faculty_profiles():
    """
    Ensures complete, rich academic datasets (teaching contexts, timetable, tasks, achievements, SLI alerts)
    for all registered faculty members and administrators.
    """
    from app.models.user import User
    from app.services.dashboard_service import ensure_faculty_complete_academic_data

    db = SessionLocal()
    try:
        all_users = db.query(User).all()
        for u in all_users:
            ensure_faculty_complete_academic_data(db, u)
        print("  [OK] Ensured full academic profiles, timetable schedules, and SLI contexts for all users.")
    except Exception as e:
        db.rollback()
        print(f"  [WARN] Faculty profile seed notice: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    sync_database_schema()
    seed_admin_user()
    seed_all_faculty_profiles()


