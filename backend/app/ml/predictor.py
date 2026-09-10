"""
SLI ML Real-Time Inference & Recommendation Engine.

Executes inference on student enrollment feature vectors.
Explains predictions using feature weights/importances.
Generates tailored educational pedagogical interventions.
"""

from typing import Any
import numpy as np

from app.ml.features import (
    FEATURE_NAMES,
    extract_features_from_assessments,
    feature_dict_to_vector,
)
from app.ml.pipeline import load_champion_model


def predict_student_risk(
    pre_response: Any | None,
    mid_response: Any | None,
    pre_submission_data: dict[str, Any] | None = None,
    mid_submission_data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """
    Performs real-time ML risk prediction for an individual student at the MID stage.
    """
    # 1. Cold Start Check: If MID has not yet been submitted, return graceful insufficient data state
    if mid_response is None and mid_submission_data is None:
        return {
            "prediction_status": "INSUFFICIENT_DATA",
            "status_reason": "MID assessment has not yet been submitted.",
            "risk_category": "LOW_RISK",
            "risk_level": "LOW",
            "is_at_risk": False,
            "risk_probability": 0.0,
            "confidence_score": 0.0,
            "prediction_point": "MID",
            "model_used": "None",
            "top_risk_drivers": [],
            "top_risk_factors": [],
            "recommendations": ["Awaiting student MID-semester progress assessment."],
            "model_version": "1.0.0",
            "features": {},
        }

    features = extract_features_from_assessments(
        pre_response=pre_response,
        mid_response=mid_response,
        pre_submission_data=pre_submission_data,
        mid_submission_data=mid_submission_data,
    )
    vec = np.array([feature_dict_to_vector(features)], dtype=np.float32)

    model, meta = load_champion_model()

    if model is not None:
        if hasattr(model, "predict_proba"):
            prob_at_risk = float(model.predict_proba(vec)[0][1])
        else:
            prob_at_risk = float(model.predict(vec)[0])
        model_name = meta.get("model_name", "Trained ML Model") if meta else "Trained ML Model"
    else:
        # Graceful fallback heuristic when model hasn't been explicitly trained
        model_name = "Rule-Calibrated ML Baseline"
        min_score = features["min_mid_skill_score"]
        delta_conf = features["delta_confidence_mean"]
        barriers = features["mid_barrier_count"]
        
        # Risk score synthesis
        base_risk = 0.2
        if min_score < 2.5:
            base_risk += 0.35
        if delta_conf < -0.8:
            base_risk += 0.25
        if barriers >= 2:
            base_risk += 0.20
        prob_at_risk = float(min(0.95, max(0.05, base_risk)))

    is_at_risk = bool(prob_at_risk >= 0.50)

    # Risk level categorical binning
    if prob_at_risk >= 0.70:
        risk_level = "HIGH"
    elif prob_at_risk >= 0.40:
        risk_level = "MODERATE"
    else:
        risk_level = "LOW"

    # Identify top risk drivers from student features
    drivers: list[str] = []
    if features["mid_skill_application_mean"] < 2.5:
        drivers.append(f"Low Practical Skill Application ({features['mid_skill_application_mean']}/5.0)")
    if features["delta_confidence_mean"] <= -0.8:
        drivers.append(f"Sharp Confidence Decline ({features['delta_confidence_mean']:+.1f} from PRE to MID)")
    if features["mid_barrier_frequency"] >= 3.5:
        drivers.append(f"Frequent Learning Disruptions (Rating: {features['mid_barrier_frequency']}/5.0)")
    if features["mid_barrier_count"] >= 2:
        drivers.append(f"{int(features['mid_barrier_count'])} Active Unresolved Learning Barriers")
    if features["mid_skill_difficulty_mean"] >= 4.0:
        drivers.append(f"High Perceived Complexity ({features['mid_skill_difficulty_mean']}/5.0)")
    if features["pre_skill_confidence_mean"] < 2.5 and features["mid_skill_confidence_mean"] < 2.5:
        drivers.append("Persistent Fundamental Conceptual Gap")

    if not drivers:
        drivers.append("Student demonstrates stable conceptual progression and manageable difficulty.")

    # Generate targeted pedagogical interventions / recommendations
    recommendations: list[str] = []
    if is_at_risk or risk_level in ["HIGH", "MODERATE"]:
        if features["mid_skill_application_mean"] < 2.8:
            recommendations.append("Schedule 1-on-1 hands-on lab demonstration and practical code walkthrough.")
        if features["mid_barrier_count"] > 0:
            recommendations.append("Review identified topic barriers and share prerequisite refreshers.")
        if features["delta_confidence_mean"] < 0:
            recommendations.append("Conduct a mid-semester check-in to realign learning goals and pace.")
        if features["mid_skill_difficulty_mean"] >= 3.8:
            recommendations.append("Provide annotated visual concept maps and step-by-step worked examples.")
    else:
        recommendations.append("Encourage advanced project exploration and peer mentoring opportunities.")
        recommendations.append("Maintain current study pace and practical assignment submissions.")

    return {
        "prediction_status": "PREDICTED",
        "status_reason": "Prediction derived from PRE and MID longitudinal assessments.",
        "risk_category": f"{risk_level}_RISK",
        "risk_level": risk_level,
        "is_at_risk": is_at_risk,
        "risk_probability": round(prob_at_risk, 3),
        "confidence_score": round(max(prob_at_risk, 1.0 - prob_at_risk), 3),
        "prediction_point": "MID",
        "model_used": model_name,
        "top_risk_drivers": drivers[:4],
        "top_risk_factors": drivers[:4],
        "recommendations": recommendations[:3],
        "model_version": "1.0.0",
        "features": features,
    }
