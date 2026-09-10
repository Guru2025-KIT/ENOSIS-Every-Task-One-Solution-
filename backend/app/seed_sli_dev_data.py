"""
Seed script — minimal DEVELOPMENT/TEST data for the SLI module.

Run from the backend directory:
    python -m app.seed_sli_dev_data

This creates:
    - 1 department      (CSE)
    - 1 development faculty (faculty@enosis.edu.in / Dr. Rachana Patil)
    - 1 division        (TY CSE Div A, Year 3, Division A)
    - 1 room            (Room 301, lecture, capacity 70)
    - 1 class           (TY CSE A, linked to division)
    - 1 semester        (active: 2025-26 Sem-5)
    - 3 subjects        (DBMS, AI/ML, Engineering Mathematics)
    - 2 topics          (for CS301 DBMS)
    - 1 generation run  (OPTIMAL status)
    - 1 timetable entry (assigning faculty@enosis.edu.in to teach CS301 in Div A)
    - 3 students        (TEST-2025-001, 002, 003)
    - 6 enrollments     (3 students × 2 subjects)

NO fake ML predictions, COPO data, or intervention data is created.

This script is IDEMPOTENT — it checks for existing rows before inserting
and will not create duplicates on re-run.
"""
import sys
import uuid
from datetime import datetime

from sqlalchemy import inspect

from app.core.security import hash_password
from app.db.base import Base, engine, SessionLocal
from app.models.academic import Division, Room, Subject
from app.models.generation_history import GenerationRun
from app.models.sli import (
    AcademicClass, Department, Enrollment, QuestionBank, Semester, Student, Topic,
)
from app.models.timetable import TimetableEntry
from app.models.user import User, UserRole
from app.services.sli_assessment_service import derive_skill_id

# Ensure all tables exist
from app.models import (  # noqa: F401
    user, academic, timetable, todo, document,
    notification, achievement, schedule_config,
    constraints, generation_history, sli, attendance,
)


def seed():
    """Insert minimal development data. Safe to re-run."""
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        # ── 1. Department ─────────────────────────────────────────
        dept = db.query(Department).filter_by(department_code="CSE").first()
        if not dept:
            dept = Department(
                department_name="Computer Science and Engineering",
                department_code="CSE",
            )
            db.add(dept)
            db.flush()
            print(f"  + Department created: CSE (id={dept.department_id})")
        else:
            print(f"  - Department CSE already exists (id={dept.department_id})")

        # ── 2. Development Faculty User ───────────────────────────
        dev_email = "faculty@enosis.edu.in"
        dev_faculty = db.query(User).filter_by(email=dev_email).first()
        if not dev_faculty:
            dev_faculty = User(
                id=str(uuid.uuid4()),
                email=dev_email,
                hashed_password=hash_password("faculty123"),
                full_name="Dr. Rachana Patil",
                employee_id="CS2015407",
                department="Computer Science and Engineering",
                role=UserRole.FACULTY,
                can_manage_timetable=False,
            )
            db.add(dev_faculty)
            db.flush()
            print(f"  + Dev Faculty created: {dev_faculty.email} (id={dev_faculty.id})")
        else:
            print(f"  - Dev Faculty already exists: {dev_faculty.email} (id={dev_faculty.id})")

        # ── 3. Division ───────────────────────────────────────────
        div = db.query(Division).filter_by(year=3, division_code="A").first()
        if not div:
            div = Division(
                id=str(uuid.uuid4()),
                name="TY CSE Div A",
                year=3,
                division_code="A",
                strength=60,
            )
            db.add(div)
            db.flush()
            print(f"  + Division created: TY CSE Div A (id={div.id})")
        else:
            print(f"  - Division already exists: {div.name} (id={div.id})")

        # ── 4. Room ───────────────────────────────────────────────
        room = db.query(Room).filter_by(name="Room 301").first()
        if not room:
            room = Room(
                id=str(uuid.uuid4()),
                name="Room 301",
                type="lecture",
                capacity=70,
            )
            db.add(room)
            db.flush()
            print(f"  + Room created: Room 301 (id={room.id})")
        else:
            print(f"  - Room already exists: Room 301 (id={room.id})")

        # ── 5. Semesters (1 through 8) ────────────────────────────
        for s_num in range(1, 9):
            s_obj = db.query(Semester).filter_by(
                academic_year="2025-26", semester_number=s_num
            ).first()
            if not s_obj:
                s_obj = Semester(
                    academic_year="2025-26",
                    semester_number=s_num,
                    status="ACTIVE" if s_num % 2 == 1 else "UPCOMING",
                )
                db.add(s_obj)
                db.flush()
                print(f"  + Semester created: 2025-26 Sem-{s_num} (id={s_obj.semester_id})")
            if s_num == 5:
                sem = s_obj

        # ── 6. Class ──────────────────────────────────────────────
        cls = db.query(AcademicClass).filter_by(
            department_id=dept.department_id,
            academic_year="2025-26",
            year_level=3,
            division="A",
        ).first()
        if not cls:
            cls = AcademicClass(
                department_id=dept.department_id,
                division_id=div.id,
                academic_year="2025-26",
                year_level=3,
                division="A",
            )
            db.add(cls)
            db.flush()
            print(f"  + Class created: TY CSE A (id={cls.class_id})")
        else:
            if not cls.division_id:
                cls.division_id = div.id
                db.flush()
            print(f"  - Class TY CSE A already exists (id={cls.class_id})")

        # ── 7. Subjects ───────────────────────────────────────────
        subject_defs = [
            {"code": "CS301", "name": "Database Management Systems",
             "subject_type": "THEORY", "credits": 4.0, "placement_relevance": 8.5},
            {"code": "CS302", "name": "Artificial Intelligence & Machine Learning",
             "subject_type": "THEORY", "credits": 4.0, "placement_relevance": 9.0},
            {"code": "MA301", "name": "Engineering Mathematics III",
             "subject_type": "THEORY", "credits": 3.0, "placement_relevance": 5.0},
        ]

        subjects = []
        for sd in subject_defs:
            subj = db.query(Subject).filter_by(code=sd["code"]).first()
            if not subj:
                subj = Subject(
                    id=str(uuid.uuid4()),
                    name=sd["name"],
                    code=sd["code"],
                    sli_department_id=dept.department_id,
                    credits=sd["credits"],
                    subject_type=sd["subject_type"],
                    placement_relevance=sd["placement_relevance"],
                )
                db.add(subj)
                db.flush()
                print(f"  + Subject created: {sd['code']} — {sd['name']}")
            else:
                if subj.sli_department_id is None:
                    subj.sli_department_id = dept.department_id
                if subj.credits is None:
                    subj.credits = sd["credits"]
                if subj.subject_type is None:
                    subj.subject_type = sd["subject_type"]
                if subj.placement_relevance is None:
                    subj.placement_relevance = sd["placement_relevance"]
                print(f"  - Subject {sd['code']} already exists (id={subj.id})")
            subjects.append(subj)

        # ── 8. Topics for CS301 ───────────────────────────────────
        dbms_subj = subjects[0]
        topic_defs = [
            "Relational Algebra & Normalization",
            "Transactions & ACID Properties",
        ]
        for t_name in topic_defs:
            t_row = db.query(Topic).filter_by(subject_id=dbms_subj.id, topic_name=t_name).first()
            if not t_row:
                t_row = Topic(
                    subject_id=dbms_subj.id,
                    topic_name=t_name,
                )
                db.add(t_row)
                db.flush()
                print(f"  + Topic created: {t_name}")
            else:
                print(f"  - Topic already exists: {t_name}")

        # ── 9. Active GenerationRun ────────────────────────────────
        gen_run = db.query(GenerationRun).filter_by(status="OPTIMAL", validation_passed=True).order_by(GenerationRun.generated_at.desc()).first()
        if not gen_run:
            gen_run = GenerationRun(
                id=str(uuid.uuid4()),
                status="OPTIMAL",
                validation_passed=True,
                solve_time_seconds=0.1,
                objective_score=98.5,
                total_entries=1,
            )
            db.add(gen_run)
            db.flush()
            print(f"  + GenerationRun created: {gen_run.id}")
        else:
            print(f"  - Active GenerationRun exists: {gen_run.id}")

        # ── 10. TimetableEntry for Development Faculty ────────────
        entry = db.query(TimetableEntry).filter_by(
            batch_id=gen_run.id,
            faculty_id=dev_faculty.id,
            subject_id=dbms_subj.id,
            division_id=div.id,
        ).first()
        if not entry:
            entry = TimetableEntry(
                id=str(uuid.uuid4()),
                batch_id=gen_run.id,
                faculty_id=dev_faculty.id,
                subject_id=dbms_subj.id,
                division_id=div.id,
                room_id=room.id,
                day=0,  # Monday
                slot=1, # Slot 1
                is_lab_block=False,
            )
            db.add(entry)
            db.flush()
            print(f"  + TimetableEntry created for {dev_faculty.full_name}: Monday Slot 1 (id={entry.id})")
        else:
            print(f"  - TimetableEntry already exists for {dev_faculty.full_name} (id={entry.id})")

        # ── 11. Students ──────────────────────────────────────────
        student_defs = [
            {"student_id": "TEST-2025-001", "name": "[TEST] Aarav Sharma"},
            {"student_id": "TEST-2025-002", "name": "[TEST] Priya Patel"},
            {"student_id": "TEST-2025-003", "name": "[TEST] Rohan Deshmukh"},
        ]

        students = []
        for sd in student_defs:
            stu = db.query(Student).filter_by(student_id=sd["student_id"]).first()
            if not stu:
                stu = Student(
                    student_id=sd["student_id"],
                    name=sd["name"],
                    department_id=dept.department_id,
                    program="B.Tech Computer Science",
                    admission_year=2023,
                    current_year=3,
                    current_semester=5,
                    division="A",
                )
                db.add(stu)
                db.flush()
                print(f"  + Student created: {sd['student_id']}")
            else:
                print(f"  - Student {sd['student_id']} already exists")
            students.append(stu)

        # ── 12. Enrollments ───────────────────────────────────────
        enrollment_count = 0
        for stu in students:
            for subj in subjects[:2]:  # Enroll each student in DBMS + AI/ML
                existing = db.query(Enrollment).filter_by(
                    student_id=stu.student_id,
                    class_id=cls.class_id,
                    semester_id=sem.semester_id,
                    subject_id=subj.id,
                ).first()
                if not existing:
                    enr = Enrollment(
                        student_id=stu.student_id,
                        class_id=cls.class_id,
                        semester_id=sem.semester_id,
                        subject_id=subj.id,
                    )
                    db.add(enr)
                    enrollment_count += 1

        db.flush()
        if enrollment_count:
            print(f"  + Enrollments created: {enrollment_count}")
        else:
            print("  - All enrollments already exist")

        # ── 13. Question Bank Items ───────────────────────────────
        qb_count = 0
        for subj in subjects:
            subj_topics = db.query(Topic).filter_by(subject_id=subj.id).all()
            for t in subj_topics:
                # Provide questions across different difficulty levels (1-5) and stages (PRE, MID, END)
                q_specs = [
                    {
                        "stage": "PRE",
                        "diff": 2,
                        "title": f"Prerequisite Baseline: {t.topic_name}",
                        "text": f"Rate your foundational understanding of prerequisite principles before learning {t.topic_name}.",
                        "dim": "PREREQUISITES",
                    },
                    {
                        "stage": "MID",
                        "diff": 3,
                        "title": f"Practical Application: {t.topic_name}",
                        "text": f"How confidently can you implement and debug practical problem scenarios in {t.topic_name}?",
                        "dim": "APPLICATION_PRACTICAL",
                    },
                    {
                        "stage": "END",
                        "diff": 4,
                        "title": f"Outcome Attainment: {t.topic_name}",
                        "text": f"Evaluate your comprehensive mastery and problem-solving agility in {t.topic_name}.",
                        "dim": "MASTERY_OUTCOMES",
                    },
                ]
                for q_spec in q_specs:
                    existing_q = db.query(QuestionBank).filter_by(
                        subject_id=subj.id,
                        topic_id=t.topic_id,
                        assessment_type=q_spec["stage"],
                        question_title=q_spec["title"],
                    ).first()
                    if not existing_q:
                        new_q = QuestionBank(
                            subject_id=subj.id,
                            topic_id=t.topic_id,
                            assessment_type=q_spec["stage"],
                            question_title=q_spec["title"],
                            question_text=q_spec["text"],
                            question_type="LIKERT_1_5",
                            section=f"Question Bank: {t.topic_name}",
                            dimension=q_spec["dim"],
                            competency="Analytical Problem Solving",
                            skill_id=derive_skill_id(t.topic_name),
                            difficulty=q_spec["diff"],
                            marks=1,
                            is_active=True,
                            created_by=dev_faculty.id,
                            created_at=datetime.utcnow(),
                            updated_at=datetime.utcnow(),
                        )
                        db.add(new_q)
                        qb_count += 1

        db.flush()
        if qb_count:
            print(f"  + Question Bank items created: {qb_count}")
        else:
            print("  - Question Bank items already seeded")

        db.commit()
        print("\n[OK] SLI development seed complete.")

    except Exception as e:
        db.rollback()
        print(f"\n[FAIL] Seed failed: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    print("=" * 50)
    print("  ENOSIS - SLI Development Seed Data")
    print("=" * 50)
    seed()
