"""
Tests POST /timetable/generate endpoint with Stage 1 sample data.
"""

import sys
import os
import json

backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from fastapi.testclient import TestClient
from app.main import app
from verify_timetable import (
    SAMPLE_ASSIGNMENTS,
    SAMPLE_CONSTRAINTS,
    SAMPLE_COMBINED_GROUPS,
    run_all_checks,
)

client = TestClient(app)


def test_api_feasible():
    print("=" * 70)
    print("STAGE 2 API TEST 1: POST /timetable/generate (FEASIBLE)")
    print("=" * 70)

    request_payload = {
        "assignments": SAMPLE_ASSIGNMENTS,
        "constraints": SAMPLE_CONSTRAINTS,
        "combined_groups": SAMPLE_COMBINED_GROUPS,
        "working_days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        "time_limit_seconds": 10,
    }

    print("HTTP REQUEST:")
    print("  Endpoint: POST /timetable/generate")
    print(f"  Headers:  Content-Type: application/json")
    print(f"  Body (truncated summary): {len(SAMPLE_ASSIGNMENTS)} assignments, {len(SAMPLE_CONSTRAINTS)} constraints")
    print(f"  Payload JSON snippet:\n{json.dumps({k: v if k != 'assignments' else v[:2] for k, v in request_payload.items()}, indent=2)}")

    response = client.post("/timetable/generate", json=request_payload)

    print("\nHTTP RESPONSE:")
    print(f"  Status Code: {response.status_code}")
    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}: {response.text}"

    resp_json = response.json()
    print(f"  Response Status field: {resp_json.get('status')}")
    print(f"  Response Message:      {resp_json.get('message')}")
    print(f"  Solve Time:            {resp_json.get('solve_time_seconds')}s")
    print(f"  Conflicting Constraints: {resp_json.get('conflictingConstraints')}")
    print(f"  Timetable Classes:     {list(resp_json.get('timetable', {}).keys())}")

    # Verify that verify_timetable.py checks PASS on the API's timetable output
    print("\nRunning verify_timetable.py checks on the API response timetable:")
    passed = run_all_checks(
        assignments=SAMPLE_ASSIGNMENTS,
        constraints=SAMPLE_CONSTRAINTS,
        combined_groups=SAMPLE_COMBINED_GROUPS,
        timetable=resp_json["timetable"]
    )
    assert passed, "Expected all verify_timetable checks to PASS on API response!"
    print("\n[SUCCESS] API endpoint returned a 100% valid, constraint-satisfying timetable!")


def test_api_infeasible():
    print("\n" + "=" * 70)
    print("STAGE 2 API TEST 2: POST /timetable/generate (CONTRADICTORY INFEASIBLE)")
    print("=" * 70)

    # Force an impossible contradiction:
    # Schedule Data Structures on Saturday, but Saturday is a Holiday!
    bad_constraints = SAMPLE_CONSTRAINTS + [
        {
            "category": "Fixed Subject Slot",
            "facultyNames": ["Vajreshwari"],
            "subjectNames": ["Data Structures"],
            "classNames": ["TY-AIML-A"],
            "days": ["Saturday"],   # Contradiction: Saturday is Holiday!
            "slotNumbers": [1]
        }
    ]

    request_payload = {
        "assignments": SAMPLE_ASSIGNMENTS,
        "constraints": bad_constraints,
        "combined_groups": SAMPLE_COMBINED_GROUPS,
        "working_days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
        "time_limit_seconds": 5,
    }

    print("HTTP REQUEST:")
    print("  Endpoint: POST /timetable/generate")
    print(f"  Payload: Contains contradictory constraint (Fixed Slot on Saturday Holiday)")

    response = client.post("/timetable/generate", json=request_payload)

    print("\nHTTP RESPONSE:")
    print(f"  Status Code: {response.status_code}")
    resp_json = response.json()
    print(f"  Response Status field: {resp_json.get('status')}")
    print(f"  Conflicting Constraints: {resp_json.get('conflictingConstraints')}")
    print(f"  Message: {resp_json.get('message')}")

    assert response.status_code == 200
    assert resp_json.get("status") == "INFEASIBLE"
    assert len(resp_json.get("conflictingConstraints", [])) > 0
    print("\n[SUCCESS] API endpoint cleanly returned INFEASIBLE with conflict explanation and no crash!")


if __name__ == "__main__":
    test_api_feasible()
    test_api_infeasible()
    print("\n" + "=" * 70)
    print("ALL STAGE 2 API ENDPOINT TESTS PASSED!")
    print("=" * 70)
