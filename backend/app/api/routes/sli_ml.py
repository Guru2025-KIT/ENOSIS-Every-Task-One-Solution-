"""
SLI Machine Learning & Early Risk Intervention API Routes.
"""

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.user import User, UserRole
from app.schemas.sli import (
    MlModelInfoOut,
    MlPredictionOut,
    MlTrainingResultOut,
)
from app.services import sli_ml_service

router = APIRouter(prefix="/sli/ml", tags=["sli-ml"])


@router.post(
    "/train",
    response_model=MlTrainingResultOut,
    status_code=status.HTTP_200_OK,
)
def train_model(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Triggers ML training across candidate models (Logistic Regression, Random Forest, Gradient Boosting).
    Evaluates on held-out data, selects champion model based on F1 and Recall, and updates active weights.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_ml_service.trigger_model_training(
        db=db,
        faculty_id=current_user.id,
        is_admin=is_admin,
    )


@router.get(
    "/model-info",
    response_model=MlModelInfoOut,
)
def get_model_info(
    _: User = Depends(get_current_user),
):
    """
    Returns the metadata, active model name, training timestamp, and evaluation metrics.
    """
    return sli_ml_service.get_model_metadata()


@router.get(
    "/predict/{enrollment_id}",
    response_model=MlPredictionOut,
)
def predict_student_risk(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Generates real-time MID-stage ML risk prediction for a student enrollment.
    Includes risk probability, risk level, top risk drivers, and pedagogical interventions.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_ml_service.get_student_ml_prediction(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.get(
    "/context-predictions/{class_id}/{subject_id}/{semester_id}",
    response_model=list[MlPredictionOut],
)
def get_context_predictions(
    class_id: int,
    subject_id: str,
    semester_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns batch ML risk predictions for all students enrolled in a teaching context.
    Sorted by highest risk probability for prioritized faculty attention.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_ml_service.get_context_ml_predictions(
        db=db,
        faculty_id=current_user.id,
        class_id=class_id,
        subject_id=subject_id,
        semester_id=semester_id,
        is_admin=is_admin,
    )
