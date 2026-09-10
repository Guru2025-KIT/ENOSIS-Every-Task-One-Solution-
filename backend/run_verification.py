"""
Connects TimetableCpSatSolver output directly to verify_timetable.py checks.
"""

import sys
import os

backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.services.timetable_cpsat_solver import solve_from_dicts
from verify_timetable import (
    run_all_checks,
    SAMPLE_ASSIGNMENTS,
    SAMPLE_CONSTRAINTS,
    SAMPLE_COMBINED_GROUPS,
)


def test_user_sample_dataset():
    print("=" * 70)
    print("TESTING CP-SAT SOLVER ON USER'S SAMPLE DATASET")
    print("=" * 70)

    result = solve_from_dicts(
        assignments_raw=SAMPLE_ASSIGNMENTS,
        constraints_raw=SAMPLE_CONSTRAINTS,
        combined_groups=SAMPLE_COMBINED_GROUPS,
        working_days=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        time_limit_seconds=10,
    )

    print(f"Solver Status: {result.status} (solve time: {result.solve_time_seconds}s)")
    if result.status not in ("OPTIMAL", "FEASIBLE"):
        print(f"Solver failed: {result.conflicts}")
        sys.exit(1)

    print("Running verify_timetable.py constraint checker on SOLVER'S REAL OUTPUT:\n")
    passed = run_all_checks(
        assignments=SAMPLE_ASSIGNMENTS,
        constraints=SAMPLE_CONSTRAINTS,
        combined_groups=SAMPLE_COMBINED_GROUPS,
        timetable=result.timetable,
    )

    if not passed:
        print("\nSome checks failed!")
        sys.exit(1)

    print("\nALL CHECKS PASSED ON SOLVER OUTPUT!")


def test_full_college_dataset():
    print("\n" + "=" * 70)
    print("TESTING CP-SAT SOLVER ON FULL MULTI-CLASS COLLEGE DATASET")
    print("(FY-AIML, SY-AIML-A/B/C, TY-AIML-A/B, TY-DS, BTECH-AIML)")
    print("=" * 70)

    assignments = [
        # FY-AIML
        {"facultyName": "Dr. Sharma", "subjectName": "Engineering Maths", "className": "FY-AIML", "type": "Theory", "batch": "-", "weeklyHours": 3},
        {"facultyName": "Prof. Patil", "subjectName": "Programming in C", "className": "FY-AIML", "type": "Theory", "batch": "-", "weeklyHours": 3},
        {"facultyName": "Prof. Patil", "subjectName": "C Programming Lab", "className": "FY-AIML", "type": "Lab", "batch": "Batch 1", "weeklyHours": 2},

        # SY-AIML (Common Lecture across SY-AIML-A/B/C)
        {"facultyName": "Dr. Pradeep S. Khot", "subjectName": "Applied Statistics", "className": "SY-AIML", "type": "Theory", "batch": "-", "weeklyHours": 3},
        {"facultyName": "Prof. Shekhar Jalane", "subjectName": "Data Structures", "className": "SY-AIML-A", "type": "Theory", "batch": "-", "weeklyHours": 3},
        {"facultyName": "Prof. Vinay Prabhvalkar", "subjectName": "DBMS", "className": "SY-AIML-B", "type": "Theory", "batch": "-", "weeklyHours": 3},

        # TY-AIML & TY-DS & BTECH-AIML (Joint Open Elective)
        {"facultyName": "ss", "subjectName": "OE", "className": "TY-AIML-A", "type": "Theory", "batch": "-", "weeklyHours": 3, "joint_group_id": "JOINT_OE"},
        {"facultyName": "ss", "subjectName": "OE", "className": "TY-AIML-B", "type": "Theory", "batch": "-", "weeklyHours": 3, "joint_group_id": "JOINT_OE"},
        {"facultyName": "ss", "subjectName": "OE", "className": "TY-DS", "type": "Theory", "batch": "-", "weeklyHours": 3, "joint_group_id": "JOINT_OE"},
        {"facultyName": "ss", "subjectName": "OE", "className": "BTECH-AIML", "type": "Theory", "batch": "-", "weeklyHours": 3, "joint_group_id": "JOINT_OE"},

        # Core
        {"facultyName": "Dr. Mrs. Uma P Gurav", "subjectName": "Deep Learning", "className": "TY-AIML-A", "type": "Theory", "batch": "-", "weeklyHours": 3},
        {"facultyName": "Dr. Mrs. Uma P Gurav", "subjectName": "Deep Learning Lab", "className": "TY-AIML-A", "type": "Lab", "batch": "Batch 1", "weeklyHours": 2},
        {"facultyName": "Prof. Karishma Tamboli", "subjectName": "Big Data Analytics", "className": "TY-DS", "type": "Theory", "batch": "-", "weeklyHours": 3},
    ]

    constraints = [
        {"category": "Holiday / College Closed", "facultyNames": [], "subjectNames": [], "classNames": [], "days": ["Monday"], "slotNumbers": []},
        {"category": "Faculty Unavailable", "facultyNames": ["Dr. Mrs. Uma P Gurav"], "subjectNames": [], "classNames": [], "days": ["Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], "slotNumbers": [6, 7, 8]},
        {"category": "Fixed Subject Slot", "facultyNames": ["ss"], "subjectNames": ["OE"], "classNames": ["TY-AIML-A", "TY-AIML-B", "TY-DS", "BTECH-AIML"], "days": ["Tuesday", "Wednesday", "Friday"], "slotNumbers": [4]},
        {"category": "No Theory After Lunch", "facultyNames": [], "subjectNames": [], "classNames": [], "days": [], "slotNumbers": [5, 6, 7, 8]},
    ]

    combined_groups = [
        ["SY-AIML-A", "SY-AIML-B", "SY-AIML-C"],
        ["TY-AIML-A", "TY-AIML-B", "TY-DS", "BTECH-AIML"],
    ]

    result = solve_from_dicts(
        assignments_raw=assignments,
        constraints_raw=constraints,
        combined_groups=combined_groups,
        working_days=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        time_limit_seconds=15,
    )

    print(f"Solver Status: {result.status} (solve time: {result.solve_time_seconds}s)")
    if result.status not in ("OPTIMAL", "FEASIBLE"):
        print(f"Solver failed: {result.conflicts}")
        sys.exit(1)

    print("Running verify_timetable.py constraint checker on MULTI-CLASS SOLVER OUTPUT:\n")
    passed = run_all_checks(
        assignments=assignments,
        constraints=constraints,
        combined_groups=combined_groups,
        timetable=result.timetable,
    )

    if not passed:
        print("\nSome checks failed!")
        sys.exit(1)

    print("\nALL COLLEGE DATASET CHECKS PASSED ON SOLVER OUTPUT!")


if __name__ == "__main__":
    test_user_sample_dataset()
    test_full_college_dataset()
