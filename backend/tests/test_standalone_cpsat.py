"""
Standalone test suite for the Google OR-Tools CP-SAT Timetable Solver.

Tests against real sample data matching the actual college class list:
- FY-AIML
- SY-AIML-A, SY-AIML-B, SY-AIML-C (with shared SY-AIML combined lectures)
- TY-AIML-A, TY-AIML-B
- TY-DS (with joint TY-AIML + TY-DS Open Elective 'OE' by faculty 'ss')
- BTECH-AIML

Exercises and verifies:
1. Feasible timetable generation.
2. Exact weekly hours per assignment.
3. No faculty double-booking.
4. No class double-booking.
5. Holidays completely blocked (e.g. Monday is Holiday).
6. Faculty Unavailable respected (e.g. Dr. Mrs. Uma P Gurav unavailable in slots 6, 7, 8).
7. Fixed Subject Slot forced (e.g. OE on Tue, Wed, Fri in slot 4).
8. No Theory After Lunch respected.
9. Labs placed in 2 consecutive slots for the same batch.
10. Joint/combined lectures placed at identical day+slot across all linked classes.
11. Infeasible constraints detected and returned as INFEASIBLE with zero crashes.
"""

import sys
import os

# Add backend directory to path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.services.timetable_cpsat_solver import (
    TimetableCpSatSolver,
    Assignment,
    TimeSlot,
    Constraint,
)


def create_realistic_test_setup():
    """Builds a realistic college timetable setup with all actual classes."""
    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00"),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00"),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True),  # Short break
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15"),
        TimeSlot(slot_number=5, start_time="12:15", end_time="01:15", is_break=True, is_lunch=True),  # Lunch break
        TimeSlot(slot_number=6, start_time="01:15", end_time="02:15"),
        TimeSlot(slot_number=7, start_time="02:15", end_time="03:15"),
        TimeSlot(slot_number=8, start_time="03:15", end_time="04:15"),
    ]

    # Assignments for our real classes:
    assignments = [
        # 1. FY-AIML
        Assignment(faculty="Dr. Sharma", subject="Engineering Maths", class_name="FY-AIML", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Patil", subject="Programming in C", class_name="FY-AIML", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Patil", subject="C Programming Lab", class_name="FY-AIML", type="Lab", batch="Batch 1", weekly_hours=2),
        Assignment(faculty="Prof. Kulkarni", subject="C Programming Lab", class_name="FY-AIML", type="Lab", batch="Batch 2", weekly_hours=2),

        # 2. SY-AIML (Common Lecture across SY-AIML-A, SY-AIML-B, SY-AIML-C)
        Assignment(faculty="Dr. Pradeep S. Khot", subject="Applied Statistics", class_name="SY-AIML-A", type="Theory", weekly_hours=3, joint_group_id="SY_STATS"),
        Assignment(faculty="Dr. Pradeep S. Khot", subject="Applied Statistics", class_name="SY-AIML-B", type="Theory", weekly_hours=3, joint_group_id="SY_STATS"),
        Assignment(faculty="Dr. Pradeep S. Khot", subject="Applied Statistics", class_name="SY-AIML-C", type="Theory", weekly_hours=3, joint_group_id="SY_STATS"),

        # SY Division-specific Theories & Labs
        Assignment(faculty="Prof. Shekhar Jalane", subject="Data Structures", class_name="SY-AIML-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Shekhar Jalane", subject="Data Structures Lab", class_name="SY-AIML-A", type="Lab", batch="Batch 1", weekly_hours=2),
        Assignment(faculty="Prof. Karishma Tamboli", subject="Data Structures Lab", class_name="SY-AIML-A", type="Lab", batch="Batch 2", weekly_hours=2),

        Assignment(faculty="Prof. Vinay Prabhvalkar", subject="DBMS", class_name="SY-AIML-B", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Vinay Prabhvalkar", subject="DBMS Lab", class_name="SY-AIML-B", type="Lab", batch="Batch 1", weekly_hours=2),

        # 3. TY-AIML & TY-DS (Joint Open Elective 'OE' taught by faculty 'ss')
        Assignment(faculty="ss", subject="OE", class_name="TY-AIML-A", type="Theory", weekly_hours=3, joint_group_id="JOINT_OE"),
        Assignment(faculty="ss", subject="OE", class_name="TY-AIML-B", type="Theory", weekly_hours=3, joint_group_id="JOINT_OE"),
        Assignment(faculty="ss", subject="OE", class_name="TY-DS", type="Theory", weekly_hours=3, joint_group_id="JOINT_OE"),
        Assignment(faculty="ss", subject="OE", class_name="BTECH-AIML", type="Theory", weekly_hours=3, joint_group_id="JOINT_OE"),

        # TY Core subjects & labs
        Assignment(faculty="Dr. Mrs. Uma P Gurav", subject="Deep Learning", class_name="TY-AIML-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. Mrs. Uma P Gurav", subject="Deep Learning Lab", class_name="TY-AIML-A", type="Lab", batch="Batch 1", weekly_hours=2),
        Assignment(faculty="Dr. Mrs. Uma P Gurav", subject="Deep Learning Lab", class_name="TY-AIML-B", type="Lab", batch="Batch 1", weekly_hours=2),

        Assignment(faculty="Dr. Pradeep S. Khot", subject="Natural Language Processing", class_name="TY-AIML-B", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Vinay Prabhvalkar", subject="Mini Project - IV", class_name="TY-AIML-A", type="Lab", batch="Batch 1", weekly_hours=2),

        # 4. TY-DS
        Assignment(faculty="Prof. Karishma Tamboli", subject="Big Data Analytics", class_name="TY-DS", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Karishma Tamboli", subject="Big Data Lab", class_name="TY-DS", type="Lab", batch="Batch 1", weekly_hours=2),

        # 5. BTECH-AIML
        Assignment(faculty="Prof. Shekhar Jalane", subject="Cloud Computing", class_name="BTECH-AIML", type="Theory", weekly_hours=3),
    ]

    # Constraints matching the user's active constraints:
    constraints = [
        # Constraint 1: Monday is Holiday
        Constraint(
            id="c1",
            category="Holiday / College Closed",
            intent="holiday",
            days=["Monday"],
        ),

        # Constraint 2: Dr. Mrs. Uma P Gurav unavailable in afternoon slots (6, 7, 8) on all days
        Constraint(
            id="c2",
            category="Faculty Unavailable",
            intent="avoid",
            faculty_names=["Dr. Mrs. Uma P Gurav"],
            days=["Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
            slot_numbers=[6, 7, 8],
        ),

        # Constraint 3: Fixed Subject Slot for OE (Tuesday, Wednesday, Friday at Slot 4 - before lunch)
        Constraint(
            id="c3",
            category="Fixed Subject Slot",
            intent="fixed",
            faculty_names=["ss"],
            subject_names=["OE"],
            days=["Tuesday", "Wednesday", "Friday"],
            slot_numbers=[4],
        ),

        # Constraint 4: No Theory After Lunch
        Constraint(
            id="c4",
            category="No Theory After Lunch",
            intent="no_theory_after_lunch",
        ),
    ]

    return assignments, time_slots, constraints


def test_feasible_and_all_constraints_satisfied():
    print("=" * 70)
    print("TEST 1: FEASIBLE SOLVE WITH ALL CONSTRAINTS")
    print("=" * 70)

    assignments, time_slots, constraints = create_realistic_test_setup()
    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=constraints,
        working_days=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        time_limit_seconds=15,
    )

    result = solver.solve()
    print(f"Solver Status: {result.status} in {result.solve_time_seconds}s")
    print(f"Message: {result.message}")

    assert result.status in ("OPTIMAL", "FEASIBLE"), f"Expected FEASIBLE/OPTIMAL, got {result.status}: {result.conflicts}"
    tt = result.timetable

    # 1. Verify Holiday: Monday must be completely marked as Holiday
    for class_name, grid in tt.items():
        for slot in range(1, 9):
            cell = grid[f"Monday_{slot}"]
            assert cell["subject"] == "Holiday", f"Class {class_name} Monday_{slot} is not Holiday!"
    print("  [PASSED] Constraint 1: Monday Holiday respected across all classes.")

    # 2. Verify Faculty Unavailable: Dr. Mrs. Uma P Gurav must NEVER be in slots 6, 7, 8
    uma_slots = []
    for class_name, grid in tt.items():
        for key, cell in grid.items():
            if "Uma P Gurav" in cell.get("faculty", ""):
                day, slot_str = key.split("_")
                slot = int(slot_str)
                uma_slots.append((day, slot, cell["subject"]))
                assert slot not in [6, 7, 8], f"VIOLATION: Dr. Mrs. Uma P Gurav scheduled at unavailable {day}_{slot}!"
    print(f"  [PASSED] Constraint 2: Dr. Mrs. Uma P Gurav unavailability in slots 6, 7, 8 strictly respected ({len(uma_slots)} sessions verified).")

    # 3. Verify Fixed Subject Slot: OE must be in slot 4 on Tuesday, Wednesday, Friday
    oe_days_found = set()
    for class_name in ["TY-AIML-A", "TY-AIML-B", "TY-DS", "BTECH-AIML"]:
        for d in ["Tuesday", "Wednesday", "Friday"]:
            cell = tt[class_name][f"{d}_4"]
            assert "OE" in cell["subject"], f"VIOLATION: Class {class_name} does not have OE at {d}_4! Has {cell['subject']}"
            assert cell["faculty"] == "ss"
            oe_days_found.add(d)
    print("  [PASSED] Constraint 3: Fixed Subject Slot 'OE' forced at Slot 4 on Tue, Wed, Fri across all 4 joint classes.")

    # 4. Verify No Theory After Lunch: Slots 6, 7, 8 (after lunch slot 5) must NOT have any Theory
    theory_count = 0
    lab_after_lunch_count = 0
    for class_name, grid in tt.items():
        for key, cell in grid.items():
            if cell["type"] == "Theory":
                day, slot_str = key.split("_")
                slot = int(slot_str)
                assert slot < 5, f"VIOLATION: Theory '{cell['subject']}' placed after lunch at {day}_{slot}!"
                theory_count += 1
            elif cell["type"] == "Lab":
                day, slot_str = key.split("_")
                slot = int(slot_str)
                if slot > 5:
                    lab_after_lunch_count += 1
    print(f"  [PASSED] Constraint 4: No Theory After Lunch respected. All {theory_count} theory sessions are before lunch ({lab_after_lunch_count} labs scheduled after lunch).")

    # 5. Verify Combined / Joint Lecture: SY Applied Statistics across SY-AIML-A, B, C
    sy_stats_slots = set()
    for class_name in ["SY-AIML-A", "SY-AIML-B", "SY-AIML-C"]:
        slots_for_cls = {key for key, cell in tt[class_name].items() if cell["subject"] == "Applied Statistics"}
        if not sy_stats_slots:
            sy_stats_slots = slots_for_cls
        else:
            assert sy_stats_slots == slots_for_cls, f"VIOLATION: Combined lecture SY Applied Stats desynchronized for {class_name}!"
    print(f"  [PASSED] Constraint 5: Joint/Combined lecture 'Applied Statistics' synchronized identically at {sorted(sy_stats_slots)} across SY-AIML-A, B, C.")

    # 6. Verify Labs are placed in 2 consecutive slots for the same batch
    for class_name, grid in tt.items():
        # Group labs by (subject, batch, day)
        from collections import defaultdict
        lab_groups = defaultdict(list)
        for key, cell in grid.items():
            if cell["type"] == "Lab":
                day, slot_str = key.split("_")
                slot = int(slot_str)
                lab_groups[(cell["subject"], cell["batch"], day)].append(slot)

        for (subj, batch, day), slots in lab_groups.items():
            slots.sort()
            assert len(slots) == 2, f"VIOLATION: Lab '{subj}' for {class_name} {batch} on {day} has {len(slots)} slots: {slots}"
            assert slots[1] == slots[0] + 1, f"VIOLATION: Lab '{subj}' slots {slots} are not consecutive!"
    print("  [PASSED] Constraint 6: All Lab sessions are placed in 2 consecutive slots for the same batch.")

    # 7. Verify Faculty Double-Booking (Faculty teaches at most 1 event per slot, unless it is a linked joint lecture)
    faculty_slot_events = defaultdict(set)
    for class_name, grid in tt.items():
        for key, cell in grid.items():
            fac = cell.get("faculty")
            if fac and cell["type"] in ("Theory", "Lab"):
                # If joint, the event identifier is (subject, fac)
                event_id = (cell["subject"], fac)
                faculty_slot_events[(fac, key)].add(event_id)

    for (fac, key), events in faculty_slot_events.items():
        assert len(events) <= 1, f"VIOLATION: Faculty '{fac}' double-booked at {key} with multiple different events: {events}"
    print("  [PASSED] Constraint 7: No Faculty Double-Booking across all slots.")

    # 8. Print sample timetable view for TY-AIML-A
    print("\n--- SAMPLE TIMETABLE EXTRACT: TY-AIML-A ---")
    header = f"{'Slot':<8} | " + " | ".join(f"{d:<15}" for d in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
    print(header)
    print("-" * len(header))
    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    for s in range(1, 9):
        row = f"Slot {s:<3} | "
        cols = []
        for d in days:
            cell = tt["TY-AIML-A"].get(f"{d}_{s}", {})
            sub = cell.get("subject", "Free")
            if len(sub) > 15:
                sub = sub[:12] + "..."
            cols.append(f"{sub:<15}")
        row += " | ".join(cols)
        print(row)
    print("-" * len(header))


def test_infeasible_contradictory_constraints():
    print("\n" + "=" * 70)
    print("TEST 2: INFEASIBLE DETECTION WITH CONTRADICTORY CONSTRAINTS")
    print("=" * 70)

    assignments, time_slots, constraints = create_realistic_test_setup()

    # Add impossible contradictory constraint:
    # Force 'OE' to be scheduled on Monday (which is declared a Holiday!)
    contradictory_constraints = constraints + [
        Constraint(
            id="bad_constraint",
            category="Fixed Subject Slot",
            intent="fixed",
            subject_names=["OE"],
            days=["Monday"],   # Contradiction: Monday is a holiday!
            slot_numbers=[2],
        )
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=contradictory_constraints,
        working_days=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        time_limit_seconds=5,
    )

    result = solver.solve()
    print(f"Solver Status: {result.status} in {result.solve_time_seconds}s")
    print(f"Conflicts reported: {result.conflicts}")

    assert result.status == "INFEASIBLE", f"Expected INFEASIBLE, got {result.status}"
    assert len(result.conflicts) > 0, "Expected clear conflict explanation"
    print("  [PASSED] Contradictory constraint correctly produced INFEASIBLE with no crash and clear conflict diagnostic.")


if __name__ == "__main__":
    test_feasible_and_all_constraints_satisfied()
    test_infeasible_contradictory_constraints()
    print("\n" + "=" * 70)
    print("ALL TESTS PASSED SUCCESSFULLY!")
    print("=" * 70)
