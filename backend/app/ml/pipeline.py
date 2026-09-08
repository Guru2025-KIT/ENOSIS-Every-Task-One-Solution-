"""
SLI ML Training & Evaluation Pipeline.

Implements:
1. Logistic Regression Baseline
2. Random Forest Classifier
3. Gradient Boosting Classifier

Evaluates across Precision, Recall, F1, Accuracy, and ROC-AUC.
Prioritizes Recall for the At-Risk class to minimize false negatives in student support.
Persists best model and training metadata to disk using standard library pickle.
"""

import json
import os
import pickle
from datetime import datetime, timezone
from typing import Any

from app.ml.features import FEATURE_NAMES

MODEL_DIR = os.path.join(os.path.dirname(__file__), "models")
MODEL_PATH = os.path.join(MODEL_DIR, "at_risk_mid_model.pkl")
META_PATH = os.path.join(MODEL_DIR, "at_risk_model_meta.json")


def train_and_evaluate_pipeline(
    X: Any,
    y: Any,
    is_synthetic_notice: bool = False,
) -> dict[str, Any]:
    """
    Executes training and comparative evaluation across the 3 ML model families.
    Selects the champion model, evaluates on a held-out test split, and persists weights.
    """
    import numpy as np
    from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import (
        accuracy_score,
        f1_score,
        precision_score,
        recall_score,
        roc_auc_score,
    )
    from sklearn.model_selection import train_test_split

    os.makedirs(MODEL_DIR, exist_ok=True)

    y_arr = np.array(y)
    X_arr = np.array(X)

    if len(y_arr) < 6 or len(np.unique(y_arr)) < 2:
        raise ValueError(
            f"Insufficient data or class diversity to train ML pipeline (samples: {len(y_arr)}, unique classes: {np.unique(y_arr)})."
        )

    # Stratified Train/Test Split (75% train, 25% validation)
    X_train, X_val, y_train, y_val = train_test_split(
        X_arr, y_arr, test_size=0.25, random_state=42, stratify=y_arr
    )

    candidate_models: dict[str, Any] = {
        "LogisticRegression": LogisticRegression(
            class_weight="balanced",
            max_iter=1000,
            C=1.0,
            random_state=42,
        ),
        "RandomForest": RandomForestClassifier(
            n_estimators=100,
            max_depth=5,
            class_weight="balanced",
            random_state=42,
        ),
        "GradientBoosting": GradientBoostingClassifier(
            n_estimators=100,
            learning_rate=0.08,
            max_depth=3,
            random_state=42,
        ),
    }

    comparison_results: dict[str, dict[str, float]] = {}
    best_model_name: str | None = None
    champion_model: Any | None = None
    best_selection_score = -1.0

    for name, model in candidate_models.items():
        model.fit(X_train, y_train)
        y_pred = model.predict(X_val)

        acc = float(accuracy_score(y_val, y_pred))
        prec = float(precision_score(y_val, y_pred, zero_division=0))
        rec = float(recall_score(y_val, y_pred, zero_division=0))
        f1 = float(f1_score(y_val, y_pred, zero_division=0))

        roc = 0.5
        if hasattr(model, "predict_proba"):
            try:
                y_prob = model.predict_proba(X_val)[:, 1]
                roc = float(roc_auc_score(y_val, y_prob))
            except Exception:
                roc = 0.5

        metrics = {
            "accuracy": round(acc, 4),
            "precision": round(prec, 4),
            "recall": round(rec, 4),
            "f1_score": round(f1, 4),
            "roc_auc": round(roc, 4),
        }
        comparison_results[name] = metrics

        # Optimization priority: 60% Recall (protect at-risk students) + 40% F1-Score
        composite_score = (0.60 * rec) + (0.40 * f1)
        if composite_score > best_selection_score:
            best_selection_score = composite_score
            best_model_name = name
            champion_model = model

    assert champion_model is not None and best_model_name is not None
    champion_metrics = comparison_results[best_model_name]

    # Calculate Feature Importances
    feature_importances: dict[str, float] = {}
    if hasattr(champion_model, "feature_importances_"):
        for fname, imp in zip(FEATURE_NAMES, champion_model.feature_importances_):
            feature_importances[fname] = round(float(imp), 4)
    elif hasattr(champion_model, "coef_"):
        for fname, coef in zip(FEATURE_NAMES, champion_model.coef_[0]):
            feature_importances[fname] = round(float(abs(coef)), 4)

    # Sort feature importances descending
    sorted_importances = dict(
        sorted(feature_importances.items(), key=lambda item: item[1], reverse=True)
    )

    # Persist champion model using standard pickle
    with open(MODEL_PATH, "wb") as f:
        pickle.dump(champion_model, f)

    training_metadata = {
        "model_name": best_model_name,
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "total_samples": int(len(y_arr)),
        "train_samples": int(len(y_train)),
        "validation_samples": int(len(y_val)),
        "class_distribution": {
            "at_risk": int(sum(y_arr)),
            "on_track": int(len(y_arr) - sum(y_arr)),
        },
        "metrics": champion_metrics,
        "all_model_comparisons": comparison_results,
        "feature_names": FEATURE_NAMES,
        "top_feature_importances": dict(list(sorted_importances.items())[:8]),
        "is_calibration_dataset": is_synthetic_notice,
    }

    with open(META_PATH, "w", encoding="utf-8") as f:
        json.dump(training_metadata, f, indent=2)

    return training_metadata


def load_champion_model() -> tuple[Any | None, dict[str, Any] | None]:
    """Loads the persisted model weights and metadata from disk."""
    if not os.path.exists(MODEL_PATH) or not os.path.exists(META_PATH):
        return None, None

    try:
        with open(MODEL_PATH, "rb") as f:
            model = pickle.load(f)
        with open(META_PATH, "r", encoding="utf-8") as f:
            meta = json.load(f)
        return model, meta
    except Exception:
        return None, None
