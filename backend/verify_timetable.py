"""
verify_timetable.py — automated constraint checker for Stage 1 CP-SAT output.

WHAT THIS DOES
--------------
Given: (1) the assignments list, (2) the constraints list, (3) the combined/linked
class groupings, and (4) the solver's output timetable — this checks every rule
we care about and prints PASS/FAIL per check, instead of you eyeballing a grid.

HOW TO USE WITH YOUR REAL SOLVER OUTPUT
----------------------------------------
Replace the SAMPLE_* variables below with your actual data (either paste them in
directly, or load from JSON files your Stage 1 script writes out). The shapes match
exactly what we discussed in the API contract:

  assignments: [{facultyName, subjectName, className, type, batch, weeklyHours}, ...]
  constraints: [{category, facultyNames, subjectNames, classNames, days, slotNumbers}, ...]
  combined_groups: [[classA, classB, ...], ...]   # sets of classes that share a slot
  timetable: { className: { "Day_SlotNumber": [subject, faculty, batchInfo] } }

Run: python3 verify_timetable.py
"""

import json
import sys
from collections import defaultdict

ALL_DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
BLANK_LABELS = {'Free', 'Break', 'Holiday'}


# ── SAMPLE DATA — replace this whole block with your real Stage 1 output ──────

SAMPLE_ASSIGNMENTS = [
    {"facultyName": "Vajreshwari", "subjectName": "Data Structures", "className": "TY-AIML-A", "type": "Theory", "batch": "-", "weeklyHours": 3},
    {"facultyName": "Vajreshwari", "subjectName": "Data Structures", "className": "TY-AIML-B", "type": "Theory", "batch": "-", "weeklyHours": 3},
    {"facultyName": "Rao", "subjectName": "AI Ethics", "className": "SY-AIML", "type": "Theory", "batch": "-", "weeklyHours": 2},
    {"facultyName": "Patil", "subjectName": "DBMS Lab", "className": "TY-AIML-A", "type": "Lab", "batch": "Batch 1", "weeklyHours": 2},
]

SAMPLE_CONSTRAINTS = [
    {"category": "Fixed Subject Slot", "facultyNames": ["Vajreshwari"], "subjectNames": [], "classNames": ["TY-AIML-A"], "days": ["Monday"], "slotNumbers": [1]},
    {"category": "Faculty Unavailable", "facultyNames": ["Rao"], "subjectNames": [], "classNames": [], "days": ["Tuesday"], "slotNumbers": [3, 4, 5]},
    {"category": "Holiday / College Closed", "facultyNames": [], "subjectNames": [], "classNames": [], "days": ["Saturday"], "slotNumbers": []},
    {"category": "No Theory After Lunch", "facultyNames": [], "subjectNames": [], "classNames": [], "days": [], "slotNumbers": [5, 6, 7, 8]},
]

# Classes that must be scheduled identically together (combined/joint lectures).
# Fill this in from your own "combined tag" logic — e.g. SY-AIML broadcasts to
# all of SY-AIML-A/B/C, so a subject tagged className="SY-AIML" should appear
# at the exact same day+slot in the generated timetables for A, B, and C.
SAMPLE_COMBINED_GROUPS = [
    ["SY-AIML-A", "SY-AIML-B", "SY-AIML-C"],
]

# This is a CORRECT sample output — every check below should PASS on it.
SAMPLE_TIMETABLE = {
    "TY-AIML-A": {
        "Monday_1": ["Data Structures", "Vajreshwari", "All"],
        "Monday_2": ["Data Structures", "Vajreshwari", "All"],
        "Wednesday_2": ["Data Structures", "Vajreshwari", "All"],
        "Tuesday_1": ["DBMS Lab", "Patil", "Batch 1"],
        "Tuesday_2": ["DBMS Lab", "Patil", "Batch 1"],
        "Saturday_1": ["Holiday", "", ""],
    },
    "TY-AIML-B": {
        "Monday_3": ["Data Structures", "Vajreshwari", "All"],
        "Tuesday_4": ["Data Structures", "Vajreshwari", "All"],
        "Wednesday_1": ["Data Structures", "Vajreshwari", "All"],
        "Saturday_1": ["Holiday", "", ""],
    },
    "SY-AIML-A": {
        "Thursday_2": ["AI Ethics", "Rao", "All"],
        "Friday_2": ["AI Ethics", "Rao", "All"],
        "Saturday_1": ["Holiday", "", ""],
    },
    "SY-AIML-B": {
        "Thursday_2": ["AI Ethics", "Rao", "All"],
        "Friday_2": ["AI Ethics", "Rao", "All"],
        "Saturday_1": ["Holiday", "", ""],
    },
    "SY-AIML-C": {
        "Thursday_2": ["AI Ethics", "Rao", "All"],
        "Friday_2": ["AI Ethics", "Rao", "All"],
        "Saturday_1": ["Holiday", "", ""],
    },
}

# ── END SAMPLE DATA ─────────────────────────────────────────────────────────


def cell_slot_num(cell_key: str) -> int:
    return int(cell_key.rsplit('_', 1)[1])


def cell_day(cell_key: str) -> str:
    return cell_key.rsplit('_', 1)[0]


def check_no_faculty_double_booking(timetable, combined_groups):
    """A faculty should never be in two DIFFERENT (non-linked) classes at the
    same day+slot. Linked classes (combined groups) are allowed to share the
    same faculty at the same slot on purpose."""
    failures = []
    occupancy = defaultdict(lambda: defaultdict(set))

    for class_name, cells in timetable.items():
        for cell_key, data in cells.items():
            subject, faculty = data[0], data[1] if len(data) > 1 else ''
            if subject in BLANK_LABELS or not faculty:
                continue
            occupancy[cell_key][faculty].add(class_name)

    group_lookup = {}
    for group in combined_groups:
        key = frozenset(group)
        for c in group:
            group_lookup[c] = key

    for cell_key, fac_map in occupancy.items():
        for faculty, classes in fac_map.items():
            if len(classes) <= 1:
                continue
            groups_involved = {group_lookup.get(c) for c in classes}
            if len(groups_involved) == 1 and None not in groups_involved:
                continue
            failures.append(f"{faculty} appears at {cell_key} across unlinked classes: {sorted(classes)}")

    return failures


def check_fixed_subject_slot(assignments, constraints, timetable):
    failures = []
    for c in constraints:
        if c['category'] != 'Fixed Subject Slot':
            continue
        for assign in assignments:
            fac_ok = not c['facultyNames'] or assign['facultyName'] in c['facultyNames']
            subj_ok = not c['subjectNames'] or assign['subjectName'] in c['subjectNames']
            class_ok = not c['classNames'] or assign['className'] in c['classNames']
            if not (fac_ok and subj_ok and class_ok):
                continue
            for day in c['days']:
                for slot in c['slotNumbers']:
                    key = f"{day}_{slot}"
                    cell = timetable.get(assign['className'], {}).get(key)
                    if not cell or cell[0] != assign['subjectName'] or cell[1] != assign['facultyName']:
                        failures.append(
                            f"Expected '{assign['subjectName']}' ({assign['facultyName']}) "
                            f"in {assign['className']} at {key}, found {cell}"
                        )
    return failures


def check_faculty_unavailable(timetable, constraints):
    failures = []
    for c in constraints:
        if c['category'] != 'Faculty Unavailable':
            continue
        for faculty in c['facultyNames']:
            for class_name, cells in timetable.items():
                for cell_key, data in cells.items():
                    day, slot = cell_day(cell_key), cell_slot_num(cell_key)
                    day_ok = not c['days'] or day in c['days']
                    slot_ok = not c['slotNumbers'] or slot in c['slotNumbers']
                    if day_ok and slot_ok and len(data) > 1 and data[1] == faculty:
                        failures.append(f"{faculty} found at {cell_key} in {class_name} despite being unavailable")
    return failures


def check_holidays(timetable, constraints):
    failures = []
    holiday_days = set()
    for c in constraints:
        if c['category'] == 'Holiday / College Closed':
            holiday_days.update(c['days'])

    for day in holiday_days:
        for class_name, cells in timetable.items():
            day_cells = {k: v for k, v in cells.items() if cell_day(k) == day}
            if not day_cells:
                continue
            non_holiday = [k for k, v in day_cells.items() if v[0] != 'Holiday']
            if non_holiday:
                failures.append(f"{class_name} has non-Holiday cells on holiday '{day}': {non_holiday}")
    return failures


def check_no_theory_after_lunch(timetable, constraints):
    failures = []
    for c in constraints:
        if c['category'] != 'No Theory After Lunch':
            continue
        for class_name, cells in timetable.items():
            for cell_key, data in cells.items():
                day, slot = cell_day(cell_key), cell_slot_num(cell_key)
                day_ok = not c['days'] or day in c['days']
                slot_ok = not c['slotNumbers'] or slot in c['slotNumbers']
                if day_ok and slot_ok and data[0] not in BLANK_LABELS:
                    is_theory_like = len(data) > 2 and data[2] == 'All'
                    if is_theory_like:
                        failures.append(f"Theory-like entry '{data[0]}' found at {cell_key} in {class_name} (No Theory After Lunch)")
    return failures


def check_weekly_hours(assignments, timetable, combined_groups):
    """A combined-tag assignment (e.g. className='SY-AIML') never appears as a
    literal key in the timetable — it only shows up under its divisions
    (SY-AIML-A/B/C). So for those, check hours under any one division member
    (they're required to be identical anyway, per the sync check above)."""
    group_lookup = {}
    for group in combined_groups:
        for c in group:
            group_lookup.setdefault(c, group)
            group_lookup.setdefault(c.rsplit('-', 1)[0], group)  # e.g. "SY-AIML" -> its group

    failures = []
    for assign in assignments:
        class_name = assign['className']
        if class_name in timetable:
            cells = timetable[class_name]
        else:
            group = group_lookup.get(class_name)
            if not group:
                failures.append(f"Could not find class '{class_name}' in timetable output at all")
                continue
            # Use whichever member of the group actually appears in the output
            cells = next((timetable[m] for m in group if m in timetable), {})

        expected = assign['weeklyHours']
        actual = sum(
            1 for data in cells.values()
            if data[0] == assign['subjectName'] and len(data) > 1 and data[1] == assign['facultyName']
        )
        if actual != expected:
            failures.append(
                f"{assign['facultyName']} / {assign['subjectName']} / {assign['className']}: "
                f"expected {expected}h, found {actual}h scheduled"
            )
    return failures


def check_combined_groups_synced(timetable, combined_groups):
    """Classes in the same combined group should show identical subject+faculty
    at identical day+slot wherever any one of them has a non-blank entry."""
    failures = []
    for group in combined_groups:
        all_keys = set()
        for c in group:
            all_keys.update(timetable.get(c, {}).keys())

        for key in all_keys:
            values_seen = set()
            for c in group:
                cell = timetable.get(c, {}).get(key)
                if cell is None:
                    continue
                if cell[0] in BLANK_LABELS:
                    continue
                values_seen.add((cell[0], cell[1] if len(cell) > 1 else ''))
            if len(values_seen) > 1:
                failures.append(f"Combined group {group} disagrees at {key}: {values_seen}")
    return failures


def run_all_checks(assignments, constraints, combined_groups, timetable):
    checks = [
        ("No faculty double-booking (excluding linked combined classes)",
         check_no_faculty_double_booking(timetable, combined_groups)),
        ("Fixed Subject Slot constraints honored",
         check_fixed_subject_slot(assignments, constraints, timetable)),
        ("Faculty Unavailable constraints honored",
         check_faculty_unavailable(timetable, constraints)),
        ("Holidays fully blocked",
         check_holidays(timetable, constraints)),
        ("No Theory After Lunch honored",
         check_no_theory_after_lunch(timetable, constraints)),
        ("Weekly hours match input exactly",
         check_weekly_hours(assignments, timetable, combined_groups)),
        ("Combined/joint classes synced to the same slot",
         check_combined_groups_synced(timetable, combined_groups)),
    ]

    all_passed = True
    print("=" * 70)
    for name, failures in checks:
        status = "PASS" if not failures else "FAIL"
        if failures:
            all_passed = False
        print(f"[{status}] {name}")
        for f in failures:
            print(f"        - {f}")
    print("=" * 70)
    print("OVERALL:", "ALL CHECKS PASSED" if all_passed else "SOME CHECKS FAILED")
    return all_passed


if __name__ == "__main__":
    from app.services.timetable_cpsat_solver import solve_from_dicts

    print("Generating Timetable with Google OR-Tools CP-SAT Solver...\n")
    solver_result = solve_from_dicts(
        assignments_raw=SAMPLE_ASSIGNMENTS,
        constraints_raw=SAMPLE_CONSTRAINTS,
        combined_groups=SAMPLE_COMBINED_GROUPS,
        working_days=ALL_DAYS,
        time_limit_seconds=10,
    )

    print(f"Solver Status: {solver_result.status} (solve time: {solver_result.solve_time_seconds}s)")
    if solver_result.status not in ("OPTIMAL", "FEASIBLE"):
        print(f"Solver failed: {solver_result.conflicts}")
        sys.exit(1)

    print("\nTesting the SOLVER-GENERATED dataset with verify_timetable.py checks (everything should PASS):\n")
    result = run_all_checks(SAMPLE_ASSIGNMENTS, SAMPLE_CONSTRAINTS, SAMPLE_COMBINED_GROUPS, solver_result.timetable)

    print("\n\nTesting a DELIBERATELY BROKEN dataset (to prove the checker catches real problems):\n")
    broken_timetable = json.loads(json.dumps(solver_result.timetable))  # deep copy
    broken_timetable["TY-AIML-A"]["Monday_1"] = ["Free", "", ""]
    broken_timetable["SY-AIML-A"]["Tuesday_4"] = ["AI Ethics", "Rao", "All"]
    broken_timetable["SY-AIML-B"]["Thursday_2"] = ["Different Subject", "SomeoneElse", "All"]

    result2 = run_all_checks(SAMPLE_ASSIGNMENTS, SAMPLE_CONSTRAINTS, SAMPLE_COMBINED_GROUPS, broken_timetable)

    sys.exit(0 if (result and not result2) else 1)
