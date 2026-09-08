"""
SLI ML Dataset Builder & Ground Truth Target Generator.

Constructs (X, y) matrices from database enrollments with completed PRE, MID,
and labeled END outcomes.
Strictly ensures zero feature leakage from END data into feature matrix X.
"""

from typing import Any
import numpy as np
from sqlalchemy.orm import Session

from app.ml.features import (
    FEATURE_NAMES,
    extract_features_from_assessments,
    feature_dict_to_vector,
)
from app.models.sli import (
    EndSemesterResponse,
    MidSemesterResponse,
    PreSemesterResponse,
    Enrollment,
)


def extract_ground_truth_target(end_response: EndSemesterResponse | None) -> int:
    """
    Extracts the binary AT_RISK_FLAG ground truth label (1 = At Risk, 0 = On Track).
    Derived EXCLUSIVELY from post-semester END outcomes.
    """
    if not end_response:
        return 0

    # Risk condition 1: Low overall mastery or low final understanding (< 3 on 1-5 scale)
    final_und = getattr(end_response, "understanding_level", None) or getattr(end_response, "final_understanding", None)
    if final_und is not None and final_und < 3:
        return 1

    final_app = getattr(end_response, "concept_application_ability", None) or getattr(end_response, "practical_application_mastery", None)
    if final_app is not None and final_app < 3:
        return 1

    final_exp = getattr(end_response, "overall_learning_experience", None) or getattr(end_response, "learning_satisfaction", None)
    if final_exp is not None and final_exp < 3:
        return 1

    # Risk condition 2: Low topic-level mastery scores (< 2.5)
    if hasattr(end_response, "topic_feedbacks") and end_response.topic_feedbacks:
        topic_scores = [
            float(tf.final_mastery_rating)
            for tf in end_response.topic_feedbacks
            if tf.final_mastery_rating is not None
        ]
        if topic_scores and (sum(topic_scores) / len(topic_scores)) < 2.5:
            return 1

    # Risk condition 3: Unresolved severe learning barriers at END stage
    if hasattr(end_response, "persistent_barriers") and end_response.persistent_barriers:
        if len(end_response.persistent_barriers) >= 2:
            return 1

    return 0


def build_ml_dataset_from_db(
    db: Session,
    min_samples_required: int = 10,
) -> tuple[np.ndarray, np.ndarray, list[dict[str, Any]], bool]:
    """
    Scans student enrollments and builds feature matrix X and target vector y.
    Returns:
        X: np.ndarray of shape (N, num_features)
        y: np.ndarray of shape (N,)
        metadata: list of enrollment metadata dicts
        is_synthetic: bool indicating whether baseline calibration samples were appended
    """
    enrollments = db.query(Enrollment).all()

    feature_rows: list[list[float]] = []
    target_rows: list[int] = []
    meta_rows: list[dict[str, Any]] = []

    for enr in enrollments:
        pre_resp = db.query(PreSemesterResponse).filter(PreSemesterResponse.enrollment_id == enr.enrollment_id).first()
        mid_resp = db.query(MidSemesterResponse).filter(MidSemesterResponse.enrollment_id == enr.enrollment_id).first()
        end_resp = db.query(EndSemesterResponse).filter(EndSemesterResponse.enrollment_id == enr.enrollment_id).first()

        # We can train if student has at least PRE or MID plus ground truth END
        if (pre_resp or mid_resp) and end_resp:
            feat_dict = extract_features_from_assessments(pre_resp, mid_resp)
            feat_vec = feature_dict_to_vector(feat_dict)
            target = extract_ground_truth_target(end_resp)

            feature_rows.append(feat_vec)
            target_rows.append(target)
            meta_rows.append({
                "enrollment_id": enr.enrollment_id,
                "student_id": enr.student_id,
                "subject_id": enr.subject_id,
                "source": "real_db",
            })

    is_synthetic = False

    # If insufficient real labeled data exists in dev/demo DB, generate standard calibration dataset
    # to allow pipeline validation, model comparison, training, serialization, and prediction
    if len(feature_rows) < min_samples_required:
        is_synthetic = True
        syn_X, syn_y, syn_meta = generate_calibration_samples(count=100)
        feature_rows.extend(syn_X)
        target_rows.extend(syn_y)
        meta_rows.extend(syn_meta)

    return (
        np.array(feature_rows, dtype=np.float32),
        np.array(target_rows, dtype=np.int32),
        meta_rows,
        is_synthetic,
    )


def generate_calibration_samples(count: int = 100) -> tuple[list[list[float]], list[int], list[dict[str, Any]]]:
    """
    Generates realistic, mathematically grounded baseline calibration samples based on
    educational psychometrics when real historical labeled records are below threshold.
    """
    np.random.seed(42)
    X: list[list[float]] = []
    y: list[int] = []
    meta: list[dict[str, Any]] = []

    for i in range(count):
        # 30% simulated at-risk distribution
        at_risk = 1 if (i % 3 == 0) else 0

        if at_risk:
            # At risk profile: low/declining confidence, high difficulty, multiple barriers
            pre_conf = float(np.random.uniform(2.0, 3.2))
            pre_app = float(np.random.uniform(1.8, 3.0))
            pre_diff = float(np.random.uniform(3.5, 4.8))
            pre_overall = float(np.random.uniform(2.0, 3.0))
            pre_prob = float(np.random.uniform(1.5, 2.8))
            pre_indep = float(np.random.uniform(1.8, 3.0))
            pre_pace = float(np.random.uniform(1.5, 2.5))
            pre_barriers = float(np.random.choice([1, 2, 3]))
            pre_freq = float(np.random.uniform(3.0, 5.0))

            mid_conf = max(1.0, pre_conf - float(np.random.uniform(0.3, 1.2)))
            mid_app = max(1.0, pre_app - float(np.random.uniform(0.2, 1.0)))
            mid_diff = min(5.0, pre_diff + float(np.random.uniform(0.1, 0.6)))
            mid_overall = max(1.0, pre_overall - float(np.random.uniform(0.3, 1.0)))
            mid_prob = max(1.0, pre_prob - float(np.random.uniform(0.2, 0.8)))
            mid_barriers = min(4.0, pre_barriers + float(np.random.choice([0, 1])))
            mid_freq = min(5.0, pre_freq + float(np.random.uniform(0.0, 0.5)))
        else:
            # On track profile: high/improving confidence, manageable difficulty, low barriers
            pre_conf = float(np.random.uniform(3.2, 4.5))
            pre_app = float(np.random.uniform(3.0, 4.5))
            pre_diff = float(np.random.uniform(2.0, 3.5))
            pre_overall = float(np.random.uniform(3.5, 4.8))
            pre_prob = float(np.random.uniform(3.2, 4.5))
            pre_indep = float(np.random.uniform(3.5, 4.8))
            pre_pace = float(np.random.uniform(3.0, 4.0))
            pre_barriers = float(np.random.choice([0, 1]))
            pre_freq = float(np.random.uniform(1.0, 2.5))

            mid_conf = min(5.0, pre_conf + float(np.random.uniform(-0.2, 0.8)))
            mid_app = min(5.0, pre_app + float(np.random.uniform(0.0, 0.9)))
            mid_diff = max(1.5, pre_diff - float(np.random.uniform(-0.2, 0.5)))
            mid_overall = min(5.0, pre_overall + float(np.random.uniform(0.0, 0.6)))
            mid_prob = min(5.0, pre_prob + float(np.random.uniform(0.1, 0.7)))
            mid_barriers = max(0.0, pre_barriers - float(np.random.choice([0, 1])))
            mid_freq = max(1.0, pre_freq - float(np.random.uniform(0.0, 0.8)))

        delta_conf = mid_conf - pre_conf
        delta_app = mid_app - pre_app
        delta_diff = mid_diff - pre_diff
        delta_overall = mid_overall - pre_overall
        delta_barriers = mid_barriers - pre_barriers
        delta_freq = mid_freq - pre_freq
        min_mid = min(mid_conf, mid_app, mid_overall, mid_prob)
        has_critical = 1.0 if (delta_conf <= -1.0 or delta_app <= -1.0 or min_mid <= 1.5) else 0.0

        row = [
            pre_conf, pre_app, pre_diff, pre_overall, pre_prob, pre_indep, pre_pace, pre_barriers, pre_freq,
            mid_conf, mid_app, mid_diff, mid_overall, mid_prob, mid_barriers, mid_freq,
            delta_conf, delta_app, delta_diff, delta_overall, delta_barriers, delta_freq,
            min_mid, has_critical,
        ]
        X.append([round(v, 3) for v in row])
        y.append(at_risk)
        meta.append({"enrollment_id": 9000 + i, "source": "calibration_profile"})

    return X, y, meta
