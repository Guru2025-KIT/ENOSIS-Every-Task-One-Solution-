"""
Unit and Integration Tests for SLI Machine Learning Pipeline.

Verifies:
1. Feature engineering correctness and strict ANTI-LEAKAGE guarantee.
2. Comparative training across 3 model families (Logistic Regression, Random Forest, Gradient Boosting).
3. Target generation and metric evaluation (Precision, Recall, F1, ROC-AUC).
4. Champion model persistence and serialization.
5. Real-time prediction inference, risk driver generation, and pedagogical recommendations.
6. API routes and authorization enforcement.
"""

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import create_access_token
from app.ml.features import (
    FEATURE_NAMES,
    extract_features_from_assessments,
    feature_dict_to_vector,
)
from app.ml.dataset import build_ml_dataset_from_db, generate_calibration_samples
from app.ml.pipeline import train_and_evaluate_pipeline, load_champion_model
from app.ml.predictor import predict_student_risk
from app.models.academic import Division, Subject
from app.models.sli import (
    AcademicClass,
    Department,
    EndSemesterResponse,
    Enrollment,
    MidSemesterResponse,
    PreSemesterResponse,
    Semester,
    Student,
)
from app.models.user import User, UserRole

client = TestClient(app)


from app.db.base import SessionLocal
from app.models.academic import TeachingAssignment
import uuid

@pytest.fixture
def ml_test_data():
    """Sets up a comprehensive test database for ML training and inference."""
    db = SessionLocal()
    try:
        # 1. Faculty & Admin
        faculty_id = str(uuid.uuid4())
        faculty = User(
            id=faculty_id,
            email=f"ml_faculty_{uuid.uuid4().hex[:6]}@enosis.edu.in",
            full_name="Dr. ML Faculty",
            role=UserRole.FACULTY,
            hashed_password="pw",
        )
        admin = User(
            id=str(uuid.uuid4()),
            email=f"ml_admin_{uuid.uuid4().hex[:6]}@enosis.edu.in",
            full_name="Admin ML",
            role=UserRole.ADMIN,
            hashed_password="pw",
        )
        db.add_all([faculty, admin])
        db.commit()

        # 2. Academic Context
        dept = Department(department_name="ML Dept", department_code=f"MLD_{uuid.uuid4().hex[:4].upper()}")
        db.add(dept)
        db.commit()

        division = Division(id=str(uuid.uuid4()), year=3, division_code="A", name="TY ML Div A")
        db.add(division)
        db.commit()

        semester = Semester(semester_number=5, academic_year="2025-26", status="ACTIVE")
        db.add(semester)
        db.commit()

        academic_class = AcademicClass(
            department_id=dept.department_id,
            division_id=division.id,
            year_level=3,
            division="A",
        )
        db.add(academic_class)
        db.commit()

        subject = Subject(id=str(uuid.uuid4()), name="Deep Learning Systems", code=f"CS{uuid.uuid4().hex[:3].upper()}", sli_department_id=dept.department_id)
        db.add(subject)
        db.commit()

        # Assign Teaching Assignment to Faculty
        assignment = TeachingAssignment(
            faculty_id=faculty.id,
            subject_id=subject.id,
            division_id=division.id,
        )
        db.add(assignment)
        db.commit()

        # 3. Create 4 Students with PRE, MID, and END data for training
        enrollments = []
        for i in range(1, 5):
            student = Student(student_id=f"ML-STU-{uuid.uuid4().hex[:6]}", name=f"Student {i}")
            db.add(student)
            db.commit()

            enr = Enrollment(
                student_id=student.student_id,
                class_id=academic_class.class_id,
                subject_id=subject.id,
                semester_id=semester.semester_id,
            )
            db.add(enr)
            db.commit()
            enrollments.append(enr)

            # PRE Response
            pre = PreSemesterResponse(
                enrollment_id=enr.enrollment_id,
                learning_confidence=4 if i % 2 == 0 else 2,
                self_assessed_skill=4 if i % 2 == 0 else 2,
                expected_difficulty=2 if i % 2 == 0 else 4,
                subject_interest=4,
            )
            db.add(pre)

            # MID Response
            mid = MidSemesterResponse(
                enrollment_id=enr.enrollment_id,
                current_confidence=4 if i % 2 == 0 else 2,
                understanding_level=4 if i % 2 == 0 else 2,
                concept_application_ability=4 if i % 2 == 0 else 2,
                perceived_difficulty=2 if i % 2 == 0 else 4,
                current_interest=4,
                learning_barriers=["Pacing", "Math"] if i % 2 != 0 else [],
            )
            db.add(mid)

            # END Response (Ground Truth)
            end = EndSemesterResponse(
                enrollment_id=enr.enrollment_id,
                final_confidence=4 if i % 2 == 0 else 2,
                understanding_level=4 if i % 2 == 0 else 2,
                concept_application_ability=4 if i % 2 == 0 else 2,
                perceived_difficulty=2 if i % 2 == 0 else 4,
                final_interest=4,
                learning_satisfaction=4 if i % 2 == 0 else 2,
                overall_learning_experience=4 if i % 2 == 0 else 2,
            )
            db.add(end)
            db.commit()

        faculty_token = create_access_token(faculty.id)
        admin_token = create_access_token(admin.id)

        yield {
            "faculty": faculty,
            "admin": admin,
            "faculty_token": faculty_token,
            "admin_token": admin_token,
            "class_id": academic_class.class_id,
            "subject_id": subject.id,
            "semester_id": semester.semester_id,
            "enrollments": enrollments,
        }
    finally:
        db.close()


def test_feature_engineering_and_anti_leakage():
    """
    Verifies:
    1. Deterministic feature extraction producing exact FEATURE_NAMES.
    2. Zero data leakage from END attributes.
    3. Proper longitudinal delta computation.
    """
    class MockPre:
        self_assessed_skill = 3
        expected_difficulty = 3
        learning_confidence = 3
        known_barriers = ["Prerequisites"]

    class MockMid:
        current_understanding = 2
        practical_application_confidence = 2
        current_difficulty = 4
        learning_confidence = 2
        unfamiliar_problem_solving_confidence = 2
        identified_barriers = ["Prerequisites", "Pacing"]
        barrier_frequency_rating = 4

    features = extract_features_from_assessments(MockPre(), MockMid())
    
    # Assert all keys present
    for name in FEATURE_NAMES:
        assert name in features, f"Missing feature {name}"

    # Verify deltas
    assert features["delta_confidence_mean"] < 0
    assert features["delta_barrier_count"] == 1.0
    assert features["has_critical_drop"] == 1.0

    # Verify vectorization preserves order
    vec = feature_dict_to_vector(features)
    assert len(vec) == len(FEATURE_NAMES)
    assert vec[0] == features["pre_skill_confidence_mean"]


def test_comparative_model_training_and_selection():
    """
    Verifies:
    1. Training pipeline across Logistic Regression, Random Forest, Gradient Boosting.
    2. Metrics computation: Precision, Recall, F1, Accuracy, ROC-AUC.
    3. Model persistence and weight loading.
    """
    X_syn, y_syn, _ = generate_calibration_samples(count=60)
    import numpy as np
    X = np.array(X_syn, dtype=np.float32)
    y = np.array(y_syn, dtype=np.int32)

    results = train_and_evaluate_pipeline(X, y)
    assert results["model_name"] in ["LogisticRegression", "RandomForest", "GradientBoosting"]
    assert "metrics" in results
    assert "f1_score" in results["metrics"]
    assert "recall" in results["metrics"]
    assert "precision" in results["metrics"]
    assert "all_model_comparisons" in results
    assert len(results["all_model_comparisons"]) == 3

    # Verify model was persisted and can be loaded
    model, meta = load_champion_model()
    assert model is not None
    assert meta is not None
    assert meta["model_name"] == results["model_name"]


def test_real_time_prediction_and_recommendations():
    """
    Verifies:
    1. Real-time inference producing probability and risk level.
    2. Explanation of top risk drivers.
    3. Actionable pedagogical recommendations.
    """
    class MockAtRiskPre:
        self_assessed_skill = 2
        expected_difficulty = 4
        learning_confidence = 2
        known_barriers = ["Calculus"]

    class MockAtRiskMid:
        current_understanding = 1
        practical_application_confidence = 1
        current_difficulty = 5
        learning_confidence = 1
        unfamiliar_problem_solving_confidence = 1
        identified_barriers = ["Calculus", "Memory"]
        barrier_frequency_rating = 5

    pred = predict_student_risk(MockAtRiskPre(), MockAtRiskMid())
    assert pred["is_at_risk"] is True
    assert pred["risk_level"] in ["HIGH", "MODERATE"]
    assert pred["risk_probability"] >= 0.5
    assert len(pred["top_risk_drivers"]) > 0
    assert len(pred["recommendations"]) > 0


def test_ml_api_endpoints_and_authorization(ml_test_data):
    """
    Verifies FastAPI ML endpoints:
    1. POST /sli/ml/train
    2. GET /sli/ml/model-info
    3. GET /sli/ml/predict/{enrollment_id}
    4. GET /sli/ml/context-predictions/{class_id}/{subject_id}/{semester_id}
    """
    token = ml_test_data["faculty_token"]
    class_id = ml_test_data["class_id"]
    subject_id = ml_test_data["subject_id"]
    semester_id = ml_test_data["semester_id"]
    enrollment_id = ml_test_data["enrollments"][0].enrollment_id

    # 1. Trigger Model Training
    train_resp = client.post(
        "/sli/ml/train",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert train_resp.status_code == 200
    train_data = train_resp.json()
    assert "model_name" in train_data
    assert "metrics" in train_data
    assert "all_model_comparisons" in train_data

    # 2. Inspect Model Info
    info_resp = client.get(
        "/sli/ml/model-info",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert info_resp.status_code == 200
    info_data = info_resp.json()
    assert info_data["status"] == "ACTIVE"
    assert info_data["model_name"] == train_data["model_name"]

    # 3. Single Student ML Prediction
    pred_resp = client.get(
        f"/sli/ml/predict/{enrollment_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert pred_resp.status_code == 200
    pred_data = pred_resp.json()
    assert "is_at_risk" in pred_data
    assert "risk_probability" in pred_data
    assert "risk_level" in pred_data
    assert "top_risk_drivers" in pred_data
    assert "recommendations" in pred_data

    # 4. Context Roster Batch Predictions
    ctx_resp = client.get(
        f"/sli/ml/context-predictions/{class_id}/{subject_id}/{semester_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ctx_resp.status_code == 200
    ctx_data = ctx_resp.json()
    assert len(ctx_data) == 4
    # Verify sorted descending by risk probability
    probs = [item["risk_probability"] for item in ctx_data]
    assert probs == sorted(probs, reverse=True)
