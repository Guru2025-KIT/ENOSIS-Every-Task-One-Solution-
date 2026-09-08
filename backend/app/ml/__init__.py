"""
SLI Machine Learning Package for Longitudinal Student Risk Analysis.
"""

from app.ml.features import (
    FEATURE_NAMES,
    extract_features_from_assessments,
    feature_dict_to_vector,
)
from app.ml.dataset import build_ml_dataset_from_db
from app.ml.pipeline import train_and_evaluate_pipeline, load_champion_model
from app.ml.predictor import predict_student_risk

__all__ = [
    "FEATURE_NAMES",
    "extract_features_from_assessments",
    "feature_dict_to_vector",
    "build_ml_dataset_from_db",
    "train_and_evaluate_pipeline",
    "load_champion_model",
    "predict_student_risk",
]
