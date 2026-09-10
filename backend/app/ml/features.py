"""
SLI Machine Learning Feature Engineering & Schema Definitions.

Strict Principle:
Prediction point is MID-Semester.
Features are derived EXCLUSIVELY from PRE assessment, MID assessment,
and pre-mid student engagement/attendance context.
Under no circumstances are END assessment outcomes or final grades
included in the feature vectors (Strict Anti-Leakage Guarantee).
"""

from typing import Any


# Standardized Feature Names in Fixed Order
FEATURE_NAMES: list[str] = [
    # 1. PRE Assessment Baseline Features (1.0 to 5.0 scales)
    "pre_skill_confidence_mean",
    "pre_skill_application_mean",
    "pre_skill_difficulty_mean",
    "pre_overall_confidence",
    "pre_problem_solving",
    "pre_independent_learning",
    "pre_learning_pace",
    "pre_barrier_count",
    "pre_barrier_frequency",
    
    # 2. MID Assessment Progress Features (1.0 to 5.0 scales)
    "mid_skill_confidence_mean",
    "mid_skill_application_mean",
    "mid_skill_difficulty_mean",
    "mid_overall_confidence",
    "mid_problem_solving",
    "mid_barrier_count",
    "mid_barrier_frequency",
    
    # 3. Longitudinal / Trajectory Features (PRE -> MID Shifts)
    "delta_confidence_mean",       # mid_conf - pre_conf
    "delta_application_mean",      # mid_app - pre_app
    "delta_difficulty_mean",       # mid_diff - pre_diff
    "delta_overall_confidence",    # mid_overall - pre_overall
    "delta_barrier_count",         # mid_barriers - pre_barriers
    "delta_barrier_frequency",     # mid_freq - pre_freq
    "min_mid_skill_score",         # lowest recorded skill rating at MID
    "has_critical_drop",           # 1 if delta_confidence < -1.0 or delta_application < -1.0 else 0
]


def extract_features_from_assessments(
    pre_response: Any | None,
    mid_response: Any | None,
    pre_submission_data: dict[str, Any] | None = None,
    mid_submission_data: dict[str, Any] | None = None,
) -> dict[str, float]:
    """
    Extracts a normalized, deterministic feature dictionary from PRE and MID assessment data.
    Defaults to neutral/baseline imputation if a specific assessment has not yet been submitted.
    """
    # -----------------------------------------------------------------------
    # 1. Parse PRE Features
    # -----------------------------------------------------------------------
    pre_sub = pre_submission_data or {}
    pre_conf_ratings: list[float] = []
    pre_app_ratings: list[float] = []
    pre_diff_ratings: list[float] = []

    # Check database model topic feedbacks if available
    if pre_response and hasattr(pre_response, "topic_feedbacks"):
        for tf in pre_response.topic_feedbacks:
            if tf.perceived_difficulty:
                pre_diff_ratings.append(float(tf.perceived_difficulty))
            if tf.expected_skill_level:
                pre_conf_ratings.append(float(tf.expected_skill_level))

    # Check student intake submission answers if present
    pre_answers = pre_sub.get("answers", [])
    for ans in pre_answers:
        dim = ans.get("dimension") or ""
        val = ans.get("response_value") or ans.get("value")
        if isinstance(val, (int, float)):
            if "confidence" in dim:
                pre_conf_ratings.append(float(val))
            elif "application" in dim:
                pre_app_ratings.append(float(val))
            elif "difficulty" in dim:
                pre_diff_ratings.append(float(val))

    # Aggregate PRE means (default neutral 3.0 if missing)
    pre_skill_conf = sum(pre_conf_ratings) / len(pre_conf_ratings) if pre_conf_ratings else (
        float(pre_response.self_assessed_skill) if pre_response and pre_response.self_assessed_skill else 3.0
    )
    pre_skill_app = sum(pre_app_ratings) / len(pre_app_ratings) if pre_app_ratings else pre_skill_conf
    pre_skill_diff = sum(pre_diff_ratings) / len(pre_diff_ratings) if pre_diff_ratings else (
        float(pre_response.expected_difficulty) if pre_response and pre_response.expected_difficulty else 3.0
    )

    pre_overall = float(pre_response.learning_confidence) if pre_response and pre_response.learning_confidence else 3.0
    pre_prob_solving = 3.0
    pre_indep_learning = 3.0
    pre_pace = 3.0
    pre_barrier_cnt = 0.0
    pre_barrier_freq = 1.0

    if pre_response and hasattr(pre_response, "known_barriers") and pre_response.known_barriers:
        pre_barrier_cnt = float(len(pre_response.known_barriers))
        pre_barrier_freq = 3.0 if pre_barrier_cnt > 0 else 1.0

    # -----------------------------------------------------------------------
    # 2. Parse MID Features
    # -----------------------------------------------------------------------
    mid_sub = mid_submission_data or {}
    mid_conf_ratings: list[float] = []
    mid_app_ratings: list[float] = []
    mid_diff_ratings: list[float] = []

    if mid_response and hasattr(mid_response, "topic_feedbacks"):
        for tf in mid_response.topic_feedbacks:
            if tf.current_difficulty_rating:
                mid_diff_ratings.append(float(tf.current_difficulty_rating))
            if tf.current_understanding_rating:
                mid_conf_ratings.append(float(tf.current_understanding_rating))
                mid_app_ratings.append(float(tf.current_understanding_rating))

    mid_answers = mid_sub.get("answers", [])
    for ans in mid_answers:
        dim = ans.get("dimension") or ""
        val = ans.get("response_value") or ans.get("value")
        if isinstance(val, (int, float)):
            if "confidence" in dim:
                mid_conf_ratings.append(float(val))
            elif "application" in dim:
                mid_app_ratings.append(float(val))
            elif "difficulty" in dim:
                mid_diff_ratings.append(float(val))

    mid_skill_conf_val = getattr(mid_response, "understanding_level", None) or getattr(mid_response, "current_understanding", None) or getattr(mid_response, "current_confidence", None)
    mid_skill_conf = sum(mid_conf_ratings) / len(mid_conf_ratings) if mid_conf_ratings else (
        float(mid_skill_conf_val) if mid_skill_conf_val is not None else pre_skill_conf
    )

    mid_skill_app_val = getattr(mid_response, "concept_application_ability", None) or getattr(mid_response, "practical_application_confidence", None) or getattr(mid_response, "understanding_level", None)
    mid_skill_app = sum(mid_app_ratings) / len(mid_app_ratings) if mid_app_ratings else (
        float(mid_skill_app_val) if mid_skill_app_val is not None else mid_skill_conf
    )

    mid_skill_diff_val = getattr(mid_response, "perceived_difficulty", None) or getattr(mid_response, "current_difficulty", None)
    mid_skill_diff = sum(mid_diff_ratings) / len(mid_diff_ratings) if mid_diff_ratings else (
        float(mid_skill_diff_val) if mid_skill_diff_val is not None else pre_skill_diff
    )

    mid_overall_val = getattr(mid_response, "current_confidence", None) or getattr(mid_response, "learning_confidence", None) or getattr(mid_response, "learning_satisfaction", None)
    mid_overall = float(mid_overall_val) if mid_overall_val is not None else mid_skill_conf

    mid_prob_val = getattr(mid_response, "unfamiliar_problem_solving_confidence", None) or getattr(mid_response, "concept_application_ability", None)
    mid_prob_solving = float(mid_prob_val) if mid_prob_val is not None else mid_skill_app

    mid_barriers_raw = getattr(mid_response, "learning_barriers", None) or getattr(mid_response, "identified_barriers", None) or []
    mid_barrier_cnt = float(len(mid_barriers_raw)) if isinstance(mid_barriers_raw, list) else 0.0

    mid_freq_val = getattr(mid_response, "barrier_frequency_rating", None)
    mid_barrier_freq = float(mid_freq_val) if mid_freq_val is not None else (3.0 if mid_barrier_cnt > 0 else 1.0)

    # -----------------------------------------------------------------------
    # 3. Longitudinal Delta Trajectory Features
    # -----------------------------------------------------------------------
    delta_conf = mid_skill_conf - pre_skill_conf
    delta_app = mid_skill_app - pre_skill_app
    delta_diff = mid_skill_diff - pre_skill_diff
    delta_overall = mid_overall - pre_overall
    delta_barriers = mid_barrier_cnt - pre_barrier_cnt
    delta_freq = mid_barrier_freq - pre_barrier_freq
    min_mid = min(mid_skill_conf, mid_skill_app, mid_overall, mid_prob_solving)
    has_critical = 1.0 if (delta_conf <= -1.0 or delta_app <= -1.0 or min_mid <= 1.5) else 0.0

    return {
        "pre_skill_confidence_mean": round(pre_skill_conf, 3),
        "pre_skill_application_mean": round(pre_skill_app, 3),
        "pre_skill_difficulty_mean": round(pre_skill_diff, 3),
        "pre_overall_confidence": round(pre_overall, 3),
        "pre_problem_solving": round(pre_prob_solving, 3),
        "pre_independent_learning": round(pre_indep_learning, 3),
        "pre_learning_pace": round(pre_pace, 3),
        "pre_barrier_count": round(pre_barrier_cnt, 3),
        "pre_barrier_frequency": round(pre_barrier_freq, 3),
        "mid_skill_confidence_mean": round(mid_skill_conf, 3),
        "mid_skill_application_mean": round(mid_skill_app, 3),
        "mid_skill_difficulty_mean": round(mid_skill_diff, 3),
        "mid_overall_confidence": round(mid_overall, 3),
        "mid_problem_solving": round(mid_prob_solving, 3),
        "mid_barrier_count": round(mid_barrier_cnt, 3),
        "mid_barrier_frequency": round(mid_barrier_freq, 3),
        "delta_confidence_mean": round(delta_conf, 3),
        "delta_application_mean": round(delta_app, 3),
        "delta_difficulty_mean": round(delta_diff, 3),
        "delta_overall_confidence": round(delta_overall, 3),
        "delta_barrier_count": round(delta_barriers, 3),
        "delta_barrier_frequency": round(delta_freq, 3),
        "min_mid_skill_score": round(min_mid, 3),
        "has_critical_drop": has_critical,
    }


def feature_dict_to_vector(features: dict[str, float]) -> list[float]:
    """Converts a feature dict to a strictly ordered float array matching FEATURE_NAMES."""
    return [float(features.get(name, 0.0)) for name in FEATURE_NAMES]
