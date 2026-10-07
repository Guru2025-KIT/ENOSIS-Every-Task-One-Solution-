import sys, os

backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.services.timetable_cpsat_solver import (
    TimetableCpSatSolver,
    Assignment,
    TimeSlot,
    Constraint,
)

def run_test():
    time_slots = [
        TimeSlot(slot_number=1, start_time="09:00", end_time="10:00"),
        TimeSlot(slot_number=2, start_time="10:00", end_time="11:00"),
        TimeSlot(slot_number=3, start_time="11:00", end_time="11:15", is_break=True),
        TimeSlot(slot_number=4, start_time="11:15", end_time="12:15"),
        TimeSlot(slot_number=5, start_time="12:15", end_time="01:15", is_break=True, is_lunch=True),
        TimeSlot(slot_number=6, start_time="01:15", end_time="02:15"),
        TimeSlot(slot_number=7, start_time="02:15", end_time="03:15"),
        TimeSlot(slot_number=8, start_time="03:15", end_time="04:15"),
    ]

    assignments = [
        # Both TY-AIML-A and TY-AIML-B are taught Deep Learning by the SAME faculty Dr. Mrs. Uma Gurav
        Assignment(faculty="Dr. Mrs. Uma Gurav", subject="Deep Learning", class_name="TY-AIML-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. Mrs. Uma Gurav", subject="Deep Learning", class_name="TY-AIML-B", type="Theory", weekly_hours=3),

        # Other subjects for TY-AIML-A and TY-AIML-B
        Assignment(faculty="Prof. Patil", subject="Machine Learning", class_name="TY-AIML-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Patil", subject="Machine Learning", class_name="TY-AIML-B", type="Theory", weekly_hours=3),

        # Labs for TY-AIML-A: Batch 1 with Dr. Uma Gurav, Batch 2 with Prof. Kulkarni
        Assignment(faculty="Dr. Mrs. Uma Gurav", subject="DL Lab", class_name="TY-AIML-A", type="Lab", batch="Batch 1", weekly_hours=2),
        Assignment(faculty="Prof. Kulkarni", subject="ML Lab", class_name="TY-AIML-A", type="Lab", batch="Batch 2", weekly_hours=2),

        # Labs for TY-AIML-B: Batch 1 with Prof. Deshmukh, Batch 2 with Prof. Joshi
        Assignment(faculty="Prof. Deshmukh", subject="DL Lab", class_name="TY-AIML-B", type="Lab", batch="Batch 1", weekly_hours=2),
        Assignment(faculty="Prof. Joshi", subject="ML Lab", class_name="TY-AIML-B", type="Lab", batch="Batch 2", weekly_hours=2),

        # SY Divisions
        Assignment(faculty="Dr. Khot", subject="Applied Stats", class_name="SY-AIML-A", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. Khot", subject="Applied Stats", class_name="SY-AIML-B", type="Theory", weekly_hours=3),
        Assignment(faculty="Dr. Khot", subject="Applied Stats", class_name="SY-AIML-C", type="Theory", weekly_hours=3),

        # TY-DS and BTECH
        Assignment(faculty="Prof. Tamboli", subject="Big Data", class_name="TY-DS", type="Theory", weekly_hours=3),
        Assignment(faculty="Prof. Jalane", subject="Cloud Computing", class_name="BTECH-AIML", type="Theory", weekly_hours=3),
    ]

    constraints = [
        # Hard constraint: Monday Holiday
        Constraint(id="h1", category="hard|Holiday", intent="holiday", days=["Monday"]),

        # Hard constraint: Dr. Mrs. Uma Gurav unavailable on Tuesday slots 1 and 2
        Constraint(
            id="c_uma",
            category="hard|Faculty Unavailable (Block Slot)",
            intent="avoid",
            faculty_names=["Dr. Mrs. Uma Gurav"],
            days=["Tuesday"],
            slot_numbers=[1, 2],
        ),

        # Soft constraint: No theory after lunch
        Constraint(id="s1", category="soft|No Theory After Lunch", intent="no_theory_after_lunch"),
    ]

    solver = TimetableCpSatSolver(
        assignments=assignments,
        time_slots=time_slots,
        constraints=constraints,
        working_days=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        time_limit_seconds=15,
    )

    res = solver.solve()
    print("STATUS:", res.status)
    print("MESSAGE:", res.message)
    print("CONFLICTS:", res.conflicts)
    assert res.status in ("OPTIMAL", "FEASIBLE")

    tt = res.detailed_timetable

    # Check 1: Deep Learning by Dr. Mrs. Uma Gurav in TY-AIML-A and TY-AIML-B
    uma_slots_a = []
    uma_slots_b = []
    for k, v in tt["TY-AIML-A"].items():
        if "Uma Gurav" in v.get("faculty", "") and v.get("type") == "Theory":
            uma_slots_a.append(k)
    for k, v in tt["TY-AIML-B"].items():
        if "Uma Gurav" in v.get("faculty", "") and v.get("type") == "Theory":
            uma_slots_b.append(k)

    print(f"TY-AIML-A Deep Learning slots: {uma_slots_a}")
    print(f"TY-AIML-B Deep Learning slots: {uma_slots_b}")

    assert len(uma_slots_a) == 3, f"Expected 3 theory hours for TY-AIML-A, got {len(uma_slots_a)}"
    assert len(uma_slots_b) == 3, f"Expected 3 theory hours for TY-AIML-B, got {len(uma_slots_b)}"

    # CRITICAL: Dr. Uma Gurav CANNOT be scheduled at the same slot in both divisions!
    overlap = set(uma_slots_a).intersection(set(uma_slots_b))
    assert len(overlap) == 0, f"CONFLICT: Dr. Uma Gurav scheduled at the SAME slot in both Div A and Div B! Overlap: {overlap}"
    print("[PASSED] Zero conflict: Dr. Uma Gurav teaches TY-AIML-A and TY-AIML-B at completely different slots!")

    # Check 2: TY-AIML-A and TY-AIML-B timetables must NOT be identical!
    diff_count = 0
    for k in tt["TY-AIML-A"]:
        if tt["TY-AIML-A"][k].get("subject") != tt["TY-AIML-B"][k].get("subject"):
            diff_count += 1
    print(f"Different slots between TY-AIML-A and TY-AIML-B: {diff_count}")
    assert diff_count > 0, "ERROR: Timetables of TY-AIML-A and TY-AIML-B are 100% identical!"
    print("[PASSED] Timetables of TY-AIML-A and TY-AIML-B are distinct and independent!")

    # Check 3: Dr. Uma Gurav Tuesday slots 1 and 2 hard constraint
    assert "Tuesday_1" not in uma_slots_a and "Tuesday_1" not in uma_slots_b
    assert "Tuesday_2" not in uma_slots_a and "Tuesday_2" not in uma_slots_b
    print("[PASSED] Hard constraint: Dr. Uma Gurav unavailability on Tuesday slots 1, 2 100% respected!")

    # Check 4: Monday Holiday
    for cls in ["TY-AIML-A", "TY-AIML-B", "SY-AIML-A", "SY-AIML-B", "SY-AIML-C"]:
        for s in range(1, 9):
            assert tt[cls][f"Monday_{s}"]["subject"] == "Holiday"
    print("[PASSED] Hard constraint: Monday holiday 100% respected across all divisions!")

    # Check 5: Parallel Lab Batches in TY-AIML-A (Batch 1 and Batch 2)
    b1_slots = [k for k, v in tt["TY-AIML-A"].items() if "Batch 1" in v.get("batch", "") and v.get("type") == "Lab"]
    b2_slots = [k for k, v in tt["TY-AIML-A"].items() if "Batch 2" in v.get("batch", "") and v.get("type") == "Lab"]
    print(f"TY-AIML-A Lab Batch 1 slots: {b1_slots}")
    print(f"TY-AIML-A Lab Batch 2 slots: {b2_slots}")
    assert len(b1_slots) == 2, f"Expected 2 lab slots for Batch 1, got {len(b1_slots)}"
    assert len(b2_slots) == 2, f"Expected 2 lab slots for Batch 2, got {len(b2_slots)}"
    # Verify parallel execution in the exact same slot!
    assert b1_slots == b2_slots, f"Expected parallel slots for Batch 1 and 2, got {b1_slots} vs {b2_slots}"
    print(f"[PASSED] Parallel lab synchronization: Batch 1 and Batch 2 run simultaneously at {b1_slots}!")

    print("\nALL VERIFICATIONS PASSED!")

if __name__ == "__main__":
    run_test()
